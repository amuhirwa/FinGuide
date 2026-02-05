"""
Predictions & Insights Endpoints
================================
AI predictions, health score, recommendations, and dashboard.
"""

from typing import List
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import and_, func
import random

from app.models.base import get_db
from app.models.transaction import Transaction, TransactionType as ModelTransactionType
from app.models.savings_goal import SavingsGoal, GoalStatus
from app.models.prediction import (
    IncomePrediction, ExpensePrediction, FinancialHealthScore, Recommendation
)
from app.schemas.prediction import (
    IncomePredictionResponse, ExpensePredictionResponse,
    CashFlowForecast, FinancialHealthScoreResponse,
    SafeToSpendResponse, RecommendationResponse, RecommendationInteraction,
    InvestmentSimulationRequest, InvestmentSimulationResponse,
    DashboardSummary, IrregularityAlert
)
from app.schemas.user import TokenPayload
from app.core.deps import get_current_active_user

router = APIRouter()


# ==================== MOCK ML PREDICTIONS ====================
# These would be replaced with actual ML model calls

def mock_income_predictions(user_id: int, db: Session) -> List[dict]:
    """Mock income predictions - replace with actual BiLSTM model."""
    now = datetime.now()
    predictions = []
    
    # Generate 3 mock predictions
    for i in range(1, 4):
        predictions.append({
            "predicted_amount": random.randint(50000, 200000),
            "predicted_date": now + timedelta(days=random.randint(3, 14) * i),
            "confidence": round(random.uniform(0.65, 0.90), 2),
            "amount_lower_bound": random.randint(40000, 80000),
            "amount_upper_bound": random.randint(150000, 250000),
            "source_category": random.choice(["salary", "freelance", "business"])
        })
    
    return predictions


def mock_expense_predictions(user_id: int, db: Session) -> List[dict]:
    """Mock expense predictions - replace with actual model."""
    now = datetime.now()
    predictions = []
    
    expenses = [
        ("rent", 100000, True, "monthly"),
        ("utilities", 15000, True, "monthly"),
        ("airtime_data", 5000, True, "weekly"),
        ("food_groceries", 30000, False, None),
    ]
    
    for cat, amount, recurring, pattern in expenses:
        predictions.append({
            "predicted_amount": amount + random.randint(-5000, 5000),
            "predicted_date": now + timedelta(days=random.randint(1, 7)),
            "category": cat,
            "confidence": round(random.uniform(0.70, 0.95), 2),
            "is_recurring": recurring,
            "recurrence_pattern": pattern
        })
    
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
    """Calculate safe to spend amount."""
    user_id = int(current_user.sub)
    now = datetime.now()
    month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    
    # Get this month's transactions
    transactions = db.query(Transaction).filter(
        and_(
            Transaction.user_id == user_id,
            Transaction.transaction_date >= month_start
        )
    ).all()
    
    total_income = sum(t.amount for t in transactions if t.transaction_type == ModelTransactionType.INCOME)
    total_expenses = sum(t.amount for t in transactions if t.transaction_type == ModelTransactionType.EXPENSE)
    total_balance = total_income - total_expenses
    
    # Get active goals
    active_goals = db.query(SavingsGoal).filter(
        and_(
            SavingsGoal.user_id == user_id,
            SavingsGoal.status == GoalStatus.ACTIVE
        )
    ).all()
    
    # Calculate reserved amounts
    reserved_for_goals = sum(g.daily_target * 7 for g in active_goals)  # Weekly goal contributions
    
    # Mock expected expenses (would come from predictions)
    reserved_for_expenses = total_expenses * 0.3  # Assume 30% more expenses coming
    
    # Emergency buffer (7 days of average expenses)
    avg_daily_expense = total_expenses / max(now.day, 1)
    emergency_buffer = avg_daily_expense * 7
    
    safe_to_spend = max(0, total_balance - reserved_for_expenses - reserved_for_goals - emergency_buffer)
    
    return SafeToSpendResponse(
        safe_to_spend=round(safe_to_spend, 2),
        total_balance=round(total_balance, 2),
        reserved_for_expenses=round(reserved_for_expenses, 2),
        reserved_for_goals=round(reserved_for_goals, 2),
        emergency_buffer=round(emergency_buffer, 2),
        explanation=f"Based on your spending patterns and {len(active_goals)} active savings goals"
    )


@router.get("/recommendations", response_model=List[RecommendationResponse])
async def get_recommendations(
    current_user: TokenPayload = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Get personalized recommendations."""
    user_id = int(current_user.sub)
    
    # Get active recommendations
    recommendations = db.query(Recommendation).filter(
        and_(
            Recommendation.user_id == user_id,
            Recommendation.is_active == True,
            Recommendation.is_dismissed == False
        )
    ).order_by(Recommendation.created_at.desc()).limit(5).all()
    
    # If no recommendations, generate some
    if not recommendations:
        rec_templates = [
            {
                "title": "Start Your Emergency Fund",
                "message": "You have surplus cash this week. Consider starting an emergency fund to cover 7 days of expenses.",
                "recommendation_type": "savings",
                "action_type": "save",
                "action_amount": 10000,
                "reason": "You have predicted surplus cash in the next 7 days",
                "urgency": "normal"
            },
            {
                "title": "Ejo Heza Contribution",
                "message": "Make a small contribution to your Ejo Heza pension fund to secure your future.",
                "recommendation_type": "investment",
                "action_type": "invest",
                "action_amount": 5000,
                "reason": "Regular contributions build long-term wealth",
                "urgency": "low"
            },
            {
                "title": "Reduce Dining Out",
                "message": "You spent 15% more on dining out compared to last month. Consider cooking at home more.",
                "recommendation_type": "spending",
                "action_type": "reduce_spending",
                "reason": "Unusual increase in dining expenses detected",
                "urgency": "normal"
            }
        ]
        
        for template in rec_templates:
            rec = Recommendation(
                user_id=user_id,
                valid_until=datetime.now() + timedelta(days=7),
                **template
            )
            db.add(rec)
        db.commit()
        
        recommendations = db.query(Recommendation).filter(
            Recommendation.user_id == user_id
        ).all()
    
    return [RecommendationResponse.model_validate(r) for r in recommendations]


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
