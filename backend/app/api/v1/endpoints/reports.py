"""
Reports Endpoints
=================
Export / download reports for transactions, savings goals, and investments.
Returns CSV data as JSON-encoded rows so the mobile client can build the file locally.
"""

from typing import Optional, List
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from sqlalchemy import and_

from app.models.base import get_db
from app.models.transaction import Transaction
from app.models.savings_goal import SavingsGoal, GoalContribution
from app.models.investment import Investment, InvestmentContribution
from app.schemas.user import TokenPayload
from app.core.deps import get_current_active_user

router = APIRouter()


# ── Transactions Report ─────────────────────────────────────────────

@router.get("/transactions")
async def export_transactions(
    start_date: Optional[datetime] = Query(None),
    end_date: Optional[datetime] = Query(None),
    current_user: TokenPayload = Depends(get_current_active_user),
    db: Session = Depends(get_db),
):
    """Export transaction history as structured rows for CSV generation."""
    user_id = int(current_user.sub)
    query = db.query(Transaction).filter(Transaction.user_id == user_id)

    if start_date:
        query = query.filter(Transaction.transaction_date >= start_date)
    if end_date:
        query = query.filter(Transaction.transaction_date <= end_date)

    transactions = query.order_by(Transaction.transaction_date.desc()).all()

    headers = [
        "Date", "Type", "Category", "Need/Want", "Amount (RWF)",
        "Description", "Counterparty", "Reference", "Verified",
    ]
    rows = []
    for t in transactions:
        rows.append([
            t.transaction_date.strftime("%Y-%m-%d %H:%M") if t.transaction_date else "",
            t.transaction_type.value if t.transaction_type else "",
            t.category.value if t.category else "",
            t.need_want.value if t.need_want else "",
            f"{t.amount:.2f}",
            t.description or "",
            t.counterparty or "",
            t.reference or "",
            "Yes" if t.is_verified else "No",
        ])

    total_income = sum(t.amount for t in transactions if t.transaction_type and t.transaction_type.value == "income")
    total_expense = sum(t.amount for t in transactions if t.transaction_type and t.transaction_type.value == "expense")

    return {
        "report_type": "transactions",
        "generated_at": datetime.utcnow().isoformat(),
        "record_count": len(rows),
        "headers": headers,
        "rows": rows,
        "summary": {
            "total_income": total_income,
            "total_expense": total_expense,
            "net": total_income - total_expense,
        },
    }


# ── Goals Report ─────────────────────────────────────────────────────

@router.get("/goals")
async def export_goals(
    current_user: TokenPayload = Depends(get_current_active_user),
    db: Session = Depends(get_db),
):
    """Export savings goals and their contributions."""
    user_id = int(current_user.sub)
    goals = db.query(SavingsGoal).filter(SavingsGoal.user_id == user_id).all()

    headers = [
        "Goal Name", "Target (RWF)", "Saved (RWF)", "Progress %",
        "Priority", "Deadline", "Status", "Daily Target", "Weekly Target",
    ]
    rows = []
    for g in goals:
        rows.append([
            g.name,
            f"{g.target_amount:.2f}",
            f"{g.current_amount:.2f}",
            f"{g.progress_percentage:.1f}",
            g.priority.value if g.priority else "",
            g.deadline.strftime("%Y-%m-%d") if g.deadline else "No deadline",
            g.status.value if g.status else "",
            f"{g.daily_target:.2f}" if g.daily_target else "0.00",
            f"{g.weekly_target:.2f}" if g.weekly_target else "0.00",
        ])

    # Contributions sub-table
    contribution_headers = ["Goal", "Amount (RWF)", "Note", "Date"]
    contribution_rows = []
    for g in goals:
        for c in g.contributions:
            contribution_rows.append([
                g.name,
                f"{c.amount:.2f}",
                c.note or "",
                c.created_at.strftime("%Y-%m-%d %H:%M") if c.created_at else "",
            ])

    return {
        "report_type": "goals",
        "generated_at": datetime.utcnow().isoformat(),
        "record_count": len(rows),
        "headers": headers,
        "rows": rows,
        "contributions": {
            "headers": contribution_headers,
            "rows": contribution_rows,
        },
        "summary": {
            "total_goals": len(goals),
            "total_saved": sum(g.current_amount for g in goals),
            "total_target": sum(g.target_amount for g in goals),
        },
    }


# ── Investments Report ───────────────────────────────────────────────

@router.get("/investments")
async def export_investments(
    current_user: TokenPayload = Depends(get_current_active_user),
    db: Session = Depends(get_db),
):
    """Export investment portfolio data."""
    user_id = int(current_user.sub)
    investments = db.query(Investment).filter(Investment.user_id == user_id).all()

    headers = [
        "Name", "Type", "Initial (RWF)", "Current Value (RWF)",
        "Total Contributions (RWF)", "Expected Return %", "Actual Return (RWF)",
        "Monthly Contribution (RWF)", "Start Date", "Maturity", "Status", "Institution",
    ]
    rows = []
    for inv in investments:
        rows.append([
            inv.name,
            inv.investment_type.value if inv.investment_type else "",
            f"{inv.initial_amount:.2f}",
            f"{inv.current_value:.2f}",
            f"{inv.total_contributions:.2f}" if inv.total_contributions else "0.00",
            f"{inv.expected_annual_return:.1f}" if inv.expected_annual_return else "0.0",
            f"{inv.actual_return_to_date:.2f}" if inv.actual_return_to_date else "0.00",
            f"{inv.monthly_contribution:.2f}" if inv.monthly_contribution else "0.00",
            inv.start_date.strftime("%Y-%m-%d") if inv.start_date else "",
            inv.maturity_date.strftime("%Y-%m-%d") if inv.maturity_date else "Open-ended",
            inv.status.value if inv.status else "",
            inv.institution_name or "",
        ])

    total_value = sum(inv.current_value or 0 for inv in investments)
    total_invested = sum((inv.initial_amount or 0) + (inv.total_contributions or 0) for inv in investments)

    return {
        "report_type": "investments",
        "generated_at": datetime.utcnow().isoformat(),
        "record_count": len(rows),
        "headers": headers,
        "rows": rows,
        "summary": {
            "total_investments": len(investments),
            "total_current_value": total_value,
            "total_invested": total_invested,
            "total_gain_loss": total_value - total_invested,
        },
    }
