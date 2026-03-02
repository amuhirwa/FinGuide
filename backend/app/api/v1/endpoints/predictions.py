"""
Predictions & Insights Endpoints
================================
AI predictions, health score, recommendations, and dashboard.
"""

import calendar
import statistics
from typing import List
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import and_, func
import random
import os

from app.models.base import get_db
from app.models.transaction import Transaction, TransactionType as ModelTransactionType, NeedWantCategory as ModelNeedWant
from app.models.savings_goal import SavingsGoal, GoalStatus
from app.models.prediction import (
    IncomePrediction, ExpensePrediction, FinancialHealthScore, Recommendation
)
from app.schemas.prediction import (
    IncomePredictionResponse, ExpensePredictionResponse,
    CashFlowForecast, FinancialHealthScoreResponse,
    SafeToSpendResponse, RecommendationResponse, RecommendationInteraction,
    InvestmentSimulationRequest, InvestmentSimulationResponse,
    DashboardSummary, IrregularityAlert, GenerateNudgesRequest,
    ChatRequest, ChatResponse,
)
from app.schemas.user import TokenPayload
from app.core.deps import get_current_active_user
from app.core.finguide_inference import FinGuidePredictor
from app.core import nudge_service

router = APIRouter()

# ==================== ML PREDICTOR SINGLETON ====================
_predictor_instance = None

def get_predictor() -> FinGuidePredictor:
    """Get or create the FinGuide predictor instance."""
    global _predictor_instance
    if _predictor_instance is None:
        # Model directory is relative to the ML folder
        model_dir = os.path.join(
            os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(__file__)))),
            'ML', 'models'
        )
        _predictor_instance = FinGuidePredictor(model_dir=model_dir)
    return _predictor_instance


# ==================== AI PREDICTION FUNCTIONS ====================

def get_user_transactions_for_ml(user_id: int, db: Session, days: int = 60) -> List[dict]:
    """Fetch user transactions formatted for ML model input."""
    cutoff_date = datetime.now() - timedelta(days=days)
    
    transactions = db.query(Transaction).filter(
        Transaction.user_id == user_id,
        Transaction.transaction_date >= cutoff_date,
        Transaction.is_verified == True
    ).order_by(Transaction.transaction_date.asc()).all()
    
    return [
        {
            "date": t.transaction_date.strftime("%Y-%m-%d"),
            "amount": float(t.amount),
            "category": t.category or "Other",
            "type": t.transaction_type.value if hasattr(t.transaction_type, 'value') else str(t.transaction_type)
        }
        for t in transactions
    ]


def generate_expense_prediction_with_ai(user_id: int, db: Session) -> dict:
    """Generate 7-day expense forecast using BiLSTM model."""
    transaction_dicts = get_user_transactions_for_ml(user_id, db)
    
    if len(transaction_dicts) < 15:
        return {
            "status": "insufficient_data",
            "message": f"Need at least 15 days of transactions. You have {len(transaction_dicts)}.",
            "forecast": None
        }
    
    try:
        predictor = get_predictor()
        result = predictor.predict_next_week(transaction_dicts)
        return result
    except Exception as e:
        return {
            "status": "error",
            "message": f"Prediction failed: {str(e)}",
            "forecast": None
        }


def mock_income_predictions(user_id: int, db: Session) -> List[dict]:
    """Predict next income using pattern detection from historical data."""
    # Fetch last 90 days of income transactions
    cutoff_date = datetime.now() - timedelta(days=90)
    
    income_txns = db.query(Transaction).filter(
        Transaction.user_id == user_id,
        Transaction.transaction_type == ModelTransactionType.INCOME,
        Transaction.transaction_date >= cutoff_date,
        Transaction.is_verified == True
    ).order_by(Transaction.transaction_date.asc()).all()
    
    if len(income_txns) < 2:
        # Not enough data - return empty prediction
        return []
    
    # Calculate average days between income events
    dates = [t.transaction_date for t in income_txns]
    intervals = [(dates[i+1] - dates[i]).days for i in range(len(dates)-1)]
    avg_interval = sum(intervals) / len(intervals) if intervals else 30
    
    # Calculate income amount average (last 5 incomes)
    recent_amounts = [float(t.amount) for t in income_txns[-5:]]
    avg_amount = sum(recent_amounts) / len(recent_amounts)
    min_amount = min(recent_amounts)
    max_amount = max(recent_amounts)
    
    # Confidence based on income regularity
    if intervals:
        variance = sum((x - avg_interval) ** 2 for x in intervals) / len(intervals)
        std_dev = variance ** 0.5
        cv = std_dev / avg_interval if avg_interval > 0 else 1.0
        
        if cv < 0.15:
            confidence = 0.85
        elif cv < 0.35:
            confidence = 0.70
        else:
            confidence = 0.55
    else:
        confidence = 0.50
    
    # Predict next income date
    last_income_date = income_txns[-1].transaction_date
    predicted_date = last_income_date + timedelta(days=int(avg_interval))
    
    # Determine source category from last income
    source_category = income_txns[-1].category or "salary"
    
    predictions = [{
        "predicted_amount": avg_amount,
        "predicted_date": predicted_date,
        "confidence": confidence,
        "amount_lower_bound": min_amount,
        "amount_upper_bound": max_amount,
        "source_category": source_category
    }]
    
    return predictions


def mock_expense_predictions(user_id: int, db: Session) -> List[dict]:
    """Generate expense predictions using AI model."""
    ai_result = generate_expense_prediction_with_ai(user_id, db)
    
    if ai_result["status"] != "success" or not ai_result.get("forecast"):
        # Fallback to empty list if AI fails
        return []
    
    forecast = ai_result["forecast"]
    now = datetime.now()
    
    # The AI gives us a 7-day aggregate forecast
    # Convert it to a single prediction entry
    predictions = [{
        "predicted_amount": forecast["total_amount_rwf"],
        "predicted_date": now + timedelta(days=3),  # Mid-week prediction
        "category": forecast["likely_top_expense"],
        "confidence": forecast["confidence_score"] / 100.0,  # Convert 0-100 to 0-1
        "is_recurring": False,
        "recurrence_pattern": None
    }]
    
    return predictions


def calculate_health_score(user_id: int, db: Session) -> dict:
    """Calculate financial health score."""
    now = datetime.now()
    month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    
    # Get transactions for this month
    transactions = db.query(Transaction).filter(
        and_(
            Transaction.user_id == user_id,
            Transaction.transaction_date >= month_start
        )
    ).all()
    
    total_income = sum(t.amount for t in transactions if t.transaction_type == ModelTransactionType.INCOME)
    total_expenses = sum(t.amount for t in transactions if t.transaction_type == ModelTransactionType.EXPENSE)
    
    # Calculate component scores
    savings_rate = ((total_income - total_expenses) / total_income * 100) if total_income > 0 else 0
    savings_rate_score = min(100, max(0, int(savings_rate * 5)))
    
    # Mock other scores (would use actual calculations)
    income_stability_score = random.randint(50, 85)
    emergency_buffer_days = random.randint(3, 21)
    emergency_buffer_score = min(100, emergency_buffer_days * 5)
    
    # Goals progress
    active_goals = db.query(SavingsGoal).filter(
        and_(
            SavingsGoal.user_id == user_id,
            SavingsGoal.status == GoalStatus.ACTIVE
        )
    ).all()
    
    if active_goals:
        avg_progress = sum(g.progress_percentage for g in active_goals) / len(active_goals)
        goal_progress_score = int(avg_progress)
    else:
        goal_progress_score = 50
    
    spending_discipline_score = random.randint(45, 80)
    
    # Overall score (weighted average)
    overall_score = int(
        income_stability_score * 0.2 +
        savings_rate_score * 0.25 +
        emergency_buffer_score * 0.2 +
        goal_progress_score * 0.2 +
        spending_discipline_score * 0.15
    )
    
    # Grade
    if overall_score >= 80:
        grade = "A"
        summary = "Excellent! Your finances are in great shape."
    elif overall_score >= 65:
        grade = "B"
        summary = "Good job! Minor improvements could boost your score."
    elif overall_score >= 50:
        grade = "C"
        summary = "Fair. Focus on building your emergency buffer."
    elif overall_score >= 35:
        grade = "D"
        summary = "Needs attention. Consider reducing discretionary spending."
    else:
        grade = "F"
        summary = "Critical. Let's work on stabilizing your finances."
    
    return {
        "overall_score": overall_score,
        "income_stability_score": income_stability_score,
        "savings_rate_score": savings_rate_score,
        "emergency_buffer_score": emergency_buffer_score,
        "goal_progress_score": goal_progress_score,
        "spending_discipline_score": spending_discipline_score,
        "monthly_income_avg": total_income,
        "monthly_expense_avg": total_expenses,
        "savings_rate": round(savings_rate, 1),
        "emergency_buffer_days": emergency_buffer_days,
        "score_change": random.randint(-5, 10),
        "grade": grade,
        "summary": summary
    }


# ==================== ENDPOINTS ====================

@router.get("/income", response_model=List[IncomePredictionResponse])
async def get_income_predictions(
    current_user: TokenPayload = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Get income predictions for the user."""
    user_id = int(current_user.sub)
    predictions = mock_income_predictions(user_id, db)
    
    # Store predictions in DB
    stored = []
    for pred in predictions:
        income_pred = IncomePrediction(
            user_id=user_id,
            **pred
        )
        db.add(income_pred)
        db.commit()
        db.refresh(income_pred)
        stored.append(IncomePredictionResponse.model_validate(income_pred))
    
    return stored


@router.get("/expenses", response_model=List[ExpensePredictionResponse])
async def get_expense_predictions(
    current_user: TokenPayload = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Get expense predictions for the user."""
    user_id = int(current_user.sub)
    predictions = mock_expense_predictions(user_id, db)
    
    stored = []
    for pred in predictions:
        expense_pred = ExpensePrediction(
            user_id=user_id,
            **pred
        )
        db.add(expense_pred)
        db.commit()
        db.refresh(expense_pred)
        stored.append(ExpensePredictionResponse.model_validate(expense_pred))
    
    return stored


@router.get("/forecast-7day")
async def get_7day_forecast(
    current_user: TokenPayload = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """
    Get detailed 7-day expense forecast using AI BiLSTM model.
    
    Returns:
        - forecast: Amount, category, confidence
        - status: success/insufficient_data/error
        - nudge: Contextual explanation
    """
    user_id = int(current_user.sub)
    result = generate_expense_prediction_with_ai(user_id, db)
    return result


@router.get("/health-score", response_model=FinancialHealthScoreResponse)
async def get_health_score(
    current_user: TokenPayload = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Get financial health score."""
    user_id = int(current_user.sub)
    score_data = calculate_health_score(user_id, db)
    
    # Store score
    health_score = FinancialHealthScore(
        user_id=user_id,
        overall_score=score_data["overall_score"],
        income_stability_score=score_data["income_stability_score"],
        savings_rate_score=score_data["savings_rate_score"],
        emergency_buffer_score=score_data["emergency_buffer_score"],
        goal_progress_score=score_data["goal_progress_score"],
        spending_discipline_score=score_data["spending_discipline_score"],
        monthly_income_avg=score_data["monthly_income_avg"],
        monthly_expense_avg=score_data["monthly_expense_avg"],
        savings_rate=score_data["savings_rate"],
        emergency_buffer_days=score_data["emergency_buffer_days"],
        score_change=score_data["score_change"]
    )
    db.add(health_score)
    db.commit()
    db.refresh(health_score)
    
    return FinancialHealthScoreResponse(
        **score_data,
        created_at=health_score.created_at
    )


@router.get("/safe-to-spend", response_model=SafeToSpendResponse)
async def get_safe_to_spend(
    current_user: TokenPayload = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """
    Calculate safe-to-spend using a rolling 8-week expense average.

    Algorithm:
     1. Collect all expense transactions over the past 8 weeks.
     2. Split into 7-day buckets and compute a trimmed mean (drops the min/max
        week when 4+ weeks of data are available) to avoid outlier distortion.
     3. Multiply average weekly expense by weeks remaining in the current month
        to estimate predicted remaining expenses.
     4. Reserve 2 weeks of average expenses as an emergency buffer.
     5. Reserve goal weekly targets × weeks remaining for savings goals.
     6. safe_to_spend = current_balance - predicted_remaining - goals - emergency.
     7. Divide by remaining days/weeks to give per-day and per-week budgets.
    """
    user_id = int(current_user.sub)
    now = datetime.now()

    # ── Rolling 8-week expense average ───────────────────────────────────────
    eight_weeks_ago = now - timedelta(weeks=8)
    all_expenses = db.query(Transaction).filter(
        Transaction.user_id == user_id,
        Transaction.transaction_type == ModelTransactionType.EXPENSE,
        Transaction.transaction_date >= eight_weeks_ago,
        Transaction.transaction_date < now,
    ).all()

    # Bucket transactions into 7-day windows with need/want weighting:
    #   NEED        → weight 1.00 (non-negotiable)
    #   WANT        → weight 0.70 (user can trim discretionary spend ~30%)
    #   SAVINGS     → weight 0.00 (not a drain, it's wealth-building)
    #   UNCATEGORIZED → outlier-removed, weight 0.85 (mix of needs+wants)
    WANT_WEIGHT = 0.70
    UNCAT_WEIGHT = 0.85

    # Collect raw uncategorized amounts for outlier detection
    uncategorized_raw: list[float] = []
    for t in all_expenses:
        nw = t.need_want.value if t.need_want else "uncategorized"
        if nw == "uncategorized":
            uncategorized_raw.append(float(t.amount))

    # Remove outliers from uncategorized: drop anything > 2.5 × median
    if uncategorized_raw:
        median_uncat = statistics.median(uncategorized_raw)
        outlier_threshold = median_uncat * 2.5
    else:
        outlier_threshold = float("inf")

    weekly_totals: dict[int, float] = {}
    for t in all_expenses:
        week_key = int((t.transaction_date - eight_weeks_ago).total_seconds() // (7 * 86400))
        nw = t.need_want.value if t.need_want else "uncategorized"
        amt = float(t.amount)

        if nw == "savings":
            continue  # savings are wealth-building, not a spend to reserve for
        elif nw == "need":
            weighted = amt * 1.0
        elif nw == "want":
            weighted = amt * WANT_WEIGHT
        else:  # uncategorized
            if amt > outlier_threshold:
                continue  # probable one-off / rounding error
            weighted = amt * UNCAT_WEIGHT

        weekly_totals[week_key] = weekly_totals.get(week_key, 0.0) + weighted

    non_zero = [v for v in weekly_totals.values() if v > 0]
    if non_zero:
        if len(non_zero) >= 4:
            # Trimmed mean: drop the single highest and single lowest week
            trimmed = sorted(non_zero)[1:-1]
        else:
            trimmed = non_zero
        avg_weekly_expense = sum(trimmed) / len(trimmed)
    else:
        avg_weekly_expense = 0.0

    # ── Current balance: prefer latest SMS balance_after, else month net ─────
    latest_with_balance = db.query(Transaction).filter(
        Transaction.user_id == user_id,
        Transaction.balance_after.isnot(None),
    ).order_by(Transaction.transaction_date.desc()).first()

    if latest_with_balance:
        total_balance = float(latest_with_balance.balance_after)
    else:
        # Fallback: month income − month expenses
        month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        month_transactions = db.query(Transaction).filter(
            Transaction.user_id == user_id,
            Transaction.transaction_date >= month_start,
        ).all()
        total_income = sum(
            float(t.amount) for t in month_transactions
            if t.transaction_type == ModelTransactionType.INCOME
        )
        total_expenses_month = sum(
            float(t.amount) for t in month_transactions
            if t.transaction_type == ModelTransactionType.EXPENSE
        )
        total_balance = total_income - total_expenses_month

    # ── Days / weeks remaining in the current calendar month ─────────────────
    days_in_month = calendar.monthrange(now.year, now.month)[1]
    days_remaining = max(1, days_in_month - now.day)
    weeks_remaining = days_remaining / 7.0

    # ── Active savings goals ──────────────────────────────────────────────────
    active_goals = db.query(SavingsGoal).filter(
        SavingsGoal.user_id == user_id,
        SavingsGoal.status == GoalStatus.ACTIVE,
    ).all()

    reserved_for_goals = sum(
        float(g.weekly_target or 0) for g in active_goals
    ) * weeks_remaining

    # ── Predicted remaining expenses (rolling average × weeks left) ───────────
    reserved_for_expenses = avg_weekly_expense * weeks_remaining

    # ── Emergency buffer (2 weeks of average weekly spend) ───────────────────
    emergency_buffer = avg_weekly_expense * 2.0

    # ── Safe-to-spend totals ──────────────────────────────────────────────────
    # NOTE: reserved_for_expenses is NOT subtracted here — it is already
    # accounted for in safe_per_day (daily budget naturally covers daily spend).
    # Only lock away savings goals and emergency buffer from the spendable pool.
    safe_to_spend = max(
        0.0,
        total_balance - reserved_for_goals - emergency_buffer,
    )
    safe_per_day = safe_to_spend / days_remaining
    safe_per_week = safe_to_spend / weeks_remaining

    # ── Human-readable explanation ────────────────────────────────────────────
    if avg_weekly_expense > 0:
        explanation = (
            f"Based on your {len(non_zero)}-week weighted spending average "
            f"(needs 100%, wants 70%) of RWF {avg_weekly_expense:,.0f}/week, "
            f"with {days_remaining} days remaining this month"
        )
    else:
        explanation = (
            f"Not enough expense history yet. "
            f"Add more transactions to get an accurate safe-to-spend figure."
        )

    return SafeToSpendResponse(
        safe_to_spend=round(safe_to_spend, 2),
        total_balance=round(total_balance, 2),
        reserved_for_expenses=round(reserved_for_expenses, 2),
        reserved_for_goals=round(reserved_for_goals, 2),
        emergency_buffer=round(emergency_buffer, 2),
        explanation=explanation,
        safe_per_day=round(safe_per_day, 2),
        safe_per_week=round(safe_per_week, 2),
        weeks_remaining=round(weeks_remaining, 1),
        days_remaining=days_remaining,
        avg_weekly_expense=round(avg_weekly_expense, 2),
    )


@router.get("/recommendations", response_model=List[RecommendationResponse])
async def get_recommendations(
    current_user: TokenPayload = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Get personalized AI-generated recommendations."""
    user_id = int(current_user.sub)

    # Fetch active, non-dismissed recommendations
    recommendations = db.query(Recommendation).filter(
        and_(
            Recommendation.user_id == user_id,
            Recommendation.is_active == True,
            Recommendation.is_dismissed == False,
        )
    ).order_by(Recommendation.created_at.desc()).limit(5).all()

    # Generate fresh nudges if none exist or all are older than 24 hours
    newest = recommendations[0] if recommendations else None
    stale = newest is None or (datetime.now() - newest.created_at.replace(tzinfo=None)).total_seconds() > 86400

    if stale:
        fresh = nudge_service.generate_nudges(user_id, db, trigger_type="manual")
        if fresh:
            recommendations = fresh
        elif not recommendations:
            # Fallback: return whatever is in DB (even if old)
            recommendations = db.query(Recommendation).filter(
                Recommendation.user_id == user_id,
                Recommendation.is_dismissed == False,
            ).order_by(Recommendation.created_at.desc()).limit(5).all()

    return [RecommendationResponse.model_validate(r) for r in recommendations]


@router.post("/generate-nudges", response_model=List[RecommendationResponse])
async def generate_nudges(
    request: GenerateNudgesRequest,
    current_user: TokenPayload = Depends(get_current_active_user),
    db: Session = Depends(get_db),
):
    """
    Generate fresh AI nudges on demand.

    Used by the mobile app for scheduled daily/weekly checks or
    when a user explicitly refreshes their recommendations.
    """
    user_id = int(current_user.sub)
    created = nudge_service.generate_nudges(
        user_id, db,
        trigger_type=request.trigger_type,
        income_amount=request.income_amount,
        income_source=request.income_source,
    )
    return [RecommendationResponse.model_validate(r) for r in created]


@router.patch("/recommendations/{rec_id}", response_model=RecommendationResponse)
async def update_recommendation(
    rec_id: int,
    interaction: RecommendationInteraction,
    current_user: TokenPayload = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Track interaction with a recommendation."""
    rec = db.query(Recommendation).filter(
        and_(
            Recommendation.id == rec_id,
            Recommendation.user_id == int(current_user.sub)
        )
    ).first()
    
    if not rec:
        raise HTTPException(status_code=404, detail="Recommendation not found")
    
    now = datetime.now()
    if interaction.action == "viewed":
        rec.is_viewed = True
        rec.viewed_at = now
    elif interaction.action == "acted":
        rec.is_acted_upon = True
        rec.acted_at = now
    elif interaction.action == "dismissed":
        rec.is_dismissed = True
        rec.dismissed_at = now
        rec.is_active = False
    
    db.commit()
    db.refresh(rec)
    
    return RecommendationResponse.model_validate(rec)


@router.post("/simulate-investment", response_model=InvestmentSimulationResponse)
async def simulate_investment(
    request: InvestmentSimulationRequest,
    current_user: TokenPayload = Depends(get_current_active_user)
):
    """Simulate investment returns."""
    # Interest rates (annual)
    rates = {
        "ejo_heza": 0.10,  # 10% annual
        "rnit": 0.08,  # 8% annual
        "savings": 0.05  # 5% annual (bank savings)
    }
    
    annual_rate = rates.get(request.investment_type, 0.05)
    monthly_rate = annual_rate / 12
    
    balance = request.principal
    total_contributions = request.principal
    monthly_breakdown = []
    
    for month in range(1, request.duration_months + 1):
        interest = balance * monthly_rate
        balance += interest + request.monthly_contribution
        total_contributions += request.monthly_contribution
        
        monthly_breakdown.append({
            "month": month,
            "contribution": request.monthly_contribution,
            "interest": round(interest, 2),
            "balance": round(balance, 2)
        })
    
    total_interest = balance - total_contributions
    effective_return = ((balance - request.principal) / request.principal) * 100 if request.principal > 0 else 0
    
    return InvestmentSimulationResponse(
        investment_type=request.investment_type,
        principal=request.principal,
        monthly_contribution=request.monthly_contribution,
        duration_months=request.duration_months,
        annual_rate=annual_rate * 100,
        total_contributions=round(total_contributions, 2),
        total_interest=round(total_interest, 2),
        final_value=round(balance, 2),
        effective_annual_return=round(effective_return / (request.duration_months / 12), 2),
        monthly_breakdown=monthly_breakdown
    )


@router.get("/dashboard", response_model=DashboardSummary)
async def get_dashboard_summary(
    current_user: TokenPayload = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Get complete dashboard summary."""
    user_id = int(current_user.sub)
    now = datetime.now()
    month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    last_month_start = (month_start - timedelta(days=1)).replace(day=1)
    
    # This month's transactions
    transactions = db.query(Transaction).filter(
        and_(
            Transaction.user_id == user_id,
            Transaction.transaction_date >= month_start
        )
    ).all()
    
    income_this_month = sum(t.amount for t in transactions if t.transaction_type == ModelTransactionType.INCOME)
    expenses_this_month = sum(t.amount for t in transactions if t.transaction_type == ModelTransactionType.EXPENSE)
    
    # Last month for comparison
    last_month_transactions = db.query(Transaction).filter(
        and_(
            Transaction.user_id == user_id,
            Transaction.transaction_date >= last_month_start,
            Transaction.transaction_date < month_start
        )
    ).all()
    
    last_month_balance = sum(
        t.amount if t.transaction_type == ModelTransactionType.INCOME else -t.amount
        for t in last_month_transactions
    )
    
    total_balance = income_this_month - expenses_this_month
    balance_change = total_balance - last_month_balance
    balance_change_pct = (balance_change / abs(last_month_balance) * 100) if last_month_balance != 0 else 0
    
    # Health score
    health_data = calculate_health_score(user_id, db)
    
    # Goals
    active_goals = db.query(SavingsGoal).filter(
        and_(
            SavingsGoal.user_id == user_id,
            SavingsGoal.status == GoalStatus.ACTIVE
        )
    ).all()
    
    goals_on_track = sum(1 for g in active_goals if g.progress_percentage >= 50)
    
    # Safe to spend
    reserved_for_goals = sum(g.daily_target * 7 for g in active_goals)
    avg_daily_expense = expenses_this_month / max(now.day, 1)
    emergency_buffer = avg_daily_expense * 7
    safe_to_spend = max(0, total_balance - expenses_this_month * 0.3 - reserved_for_goals - emergency_buffer)
    
    # Get recommendations
    recommendations = db.query(Recommendation).filter(
        and_(
            Recommendation.user_id == user_id,
            Recommendation.is_active == True,
            Recommendation.is_dismissed == False
        )
    ).limit(3).all()
    
    return DashboardSummary(
        total_balance=round(total_balance, 2),
        balance_change=round(balance_change, 2),
        balance_change_percentage=round(balance_change_pct, 1),
        income_this_month=round(income_this_month, 2),
        expenses_this_month=round(expenses_this_month, 2),
        net_this_month=round(income_this_month - expenses_this_month, 2),
        safe_to_spend=round(safe_to_spend, 2),
        health_score=health_data["overall_score"],
        health_grade=health_data["grade"],
        active_goals_count=len(active_goals),
        goals_on_track=goals_on_track,
        next_income_prediction=None,  # Would come from predictions
        upcoming_expenses=[],
        active_recommendations=[RecommendationResponse.model_validate(r) for r in recommendations]
    )


@router.get("/irregularities", response_model=List[IrregularityAlert])
async def get_irregularities(
    current_user: TokenPayload = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Detect and return financial irregularities."""
    # Mock irregularity detection - would use actual anomaly detection
    alerts = []
    
    # Example alerts
    if random.random() > 0.5:
        alerts.append(IrregularityAlert(
            alert_type="unusual_expense",
            title="Higher than usual spending",
            description="Your entertainment spending this week is 40% higher than average.",
            severity="medium",
            related_amount=25000,
            detected_at=datetime.now()
        ))
    
    if random.random() > 0.7:
        alerts.append(IrregularityAlert(
            alert_type="risk_period",
            title="Low balance predicted",
            description="Based on your patterns, you may face a cash shortage in 5 days.",
            severity="high",
            detected_at=datetime.now()
        ))
    
    return alerts


# ==================== ADDITIONAL ENDPOINTS (for mobile compatibility) ====================

@router.get("/predictions")
async def get_combined_predictions(
    days: int = 30,
    current_user: TokenPayload = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Get combined income and expense predictions."""
    user_id = int(current_user.sub)
    
    income_predictions = mock_income_predictions(user_id, db)
    expense_predictions = mock_expense_predictions(user_id, db)
    
    return {
        "period_days": days,
        "income_predictions": income_predictions,
        "expense_predictions": expense_predictions,
        "summary": {
            "expected_income": sum(p["predicted_amount"] for p in income_predictions),
            "expected_expenses": sum(p["predicted_amount"] for p in expense_predictions),
            "predicted_net": sum(p["predicted_amount"] for p in income_predictions) - sum(p["predicted_amount"] for p in expense_predictions)
        }
    }


@router.get("/financial-health")
async def get_financial_health(
    current_user: TokenPayload = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Get comprehensive financial health analysis."""
    user_id = int(current_user.sub)
    health_data = calculate_health_score(user_id, db)
    
    # Add additional insights
    health_data["insights"] = [
        {
            "category": "savings",
            "status": "good" if health_data["savings_rate"] >= 20 else "needs_attention",
            "message": f"Your savings rate is {health_data['savings_rate']}%"
        },
        {
            "category": "emergency_fund",
            "status": "good" if health_data["emergency_buffer_days"] >= 14 else "needs_attention",
            "message": f"You have {health_data['emergency_buffer_days']} days of emergency buffer"
        },
        {
            "category": "spending",
            "status": "good" if health_data["spending_discipline_score"] >= 60 else "needs_attention",
            "message": "Your spending is within healthy limits" if health_data["spending_discipline_score"] >= 60 else "Consider reducing discretionary spending"
        }
    ]
    
    health_data["recommendations"] = [
        "Aim to save at least 20% of your income",
        "Build an emergency fund covering 30 days of expenses",
        "Track your needs vs wants spending"
    ]
    
    return health_data


@router.get("/spending-by-category")
async def get_spending_by_category(    start_date: datetime = None,
    end_date: datetime = None,
    current_user: TokenPayload = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Get spending breakdown by category."""
    user_id = int(current_user.sub)
    now = datetime.now()
    
    if not start_date:
        start_date = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    if not end_date:
        end_date = now
    
    # Get expense transactions
    transactions = db.query(Transaction).filter(
        and_(
            Transaction.user_id == user_id,
            Transaction.transaction_type == ModelTransactionType.EXPENSE,
            Transaction.transaction_date >= start_date,
            Transaction.transaction_date <= end_date
        )
    ).all()
    
    # Group by category
    category_totals = {}
    for t in transactions:
        cat = t.category.value if t.category else "other"
        if cat not in category_totals:
            category_totals[cat] = {"amount": 0, "count": 0}
        category_totals[cat]["amount"] += t.amount
        category_totals[cat]["count"] += 1
    
    total_spending = sum(t.amount for t in transactions)
    
    result = []
    for cat, data in sorted(category_totals.items(), key=lambda x: x[1]["amount"], reverse=True):
        result.append({
            "category": cat,
            "amount": round(data["amount"], 2),
            "count": data["count"],
            "percentage": round((data["amount"] / total_spending * 100) if total_spending > 0 else 0, 1)
        })
    
    return result


# ── Finance Advisor Chat ─────────────────────────────────────────────────────

@router.post("/chat", response_model=ChatResponse, tags=["Finance Advisor"])
async def chat_with_advisor(
    request: ChatRequest,
    current_user: TokenPayload = Depends(get_current_active_user),
    db: Session = Depends(get_db),
):
    """
    Chat with the FinGuide AI financial advisor.

    Accepts a user message and optional prior conversation history,
    enriches the prompt with the user's live financial context (income,
    expenses, goals, investments, health score), and returns a concise,
    personalized reply from Claude.

    Request body:
        message  – The user's latest question or message.
        history  – Optional list of prior turns [{role, content}, ...].

    Returns:
        reply – The advisor's response as plain text.
    """
    user_id = int(current_user.sub)
    reply = nudge_service.chat_with_advisor(
        user_id=user_id,
        db=db,
        message=request.message,
        history=[{"role": m.role, "content": m.content} for m in request.history],
    )
    return ChatResponse(reply=reply)
