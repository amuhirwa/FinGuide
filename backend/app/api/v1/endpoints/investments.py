"""
Investment Endpoints
====================
CRUD operations and insights for investments.
"""

from typing import List, Optional
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from sqlalchemy import and_, func

from app.models.base import get_db
from app.models.investment import (
    Investment, InvestmentContribution,
    InvestmentType as ModelInvestmentType,
    InvestmentStatus as ModelInvestmentStatus
)
from app.schemas.investment import (
    InvestmentCreate, InvestmentUpdate, InvestmentResponse,
    InvestmentDetailResponse, InvestmentSummary,
    ContributionCreate, ContributionResponse,
    InvestmentAdvice, InvestmentProjection,
    InvestmentType, InvestmentStatus
)
from app.schemas.user import TokenPayload
from app.core.deps import get_current_active_user

router = APIRouter()


# ==================== Investment CRUD ====================

@router.get("", response_model=List[InvestmentResponse])
async def get_investments(
    status: Optional[InvestmentStatus] = None,
    investment_type: Optional[InvestmentType] = None,
    current_user: TokenPayload = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Get all investments for the current user."""
    user_id = int(current_user.sub)
    
    query = db.query(Investment).filter(Investment.user_id == user_id)
    
    if status:
        query = query.filter(Investment.status == ModelInvestmentStatus(status.value))
    if investment_type:
        query = query.filter(Investment.investment_type == ModelInvestmentType(investment_type.value))
    
    investments = query.order_by(Investment.created_at.desc()).all()
    
    result = []
    for inv in investments:
        inv_data = InvestmentResponse.model_validate(inv)
        inv_data.total_gain = inv.current_value - inv.total_contributions + inv.total_withdrawals
        inv_data.gain_percentage = (inv_data.total_gain / inv.total_contributions * 100) if inv.total_contributions > 0 else 0
        result.append(inv_data)
    
    return result


@router.post("", response_model=InvestmentResponse, status_code=status.HTTP_201_CREATED)
async def create_investment(
    investment_data: InvestmentCreate,
    current_user: TokenPayload = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Create a new investment."""
    user_id = int(current_user.sub)
    
    investment = Investment(
        user_id=user_id,
        name=investment_data.name,
        investment_type=ModelInvestmentType(investment_data.investment_type.value),
        description=investment_data.description,
        initial_amount=investment_data.initial_amount,
        current_value=investment_data.initial_amount,
        total_contributions=investment_data.initial_amount,
        expected_annual_return=investment_data.expected_annual_return,
        monthly_contribution=investment_data.monthly_contribution,
        contribution_day=investment_data.contribution_day,
        auto_contribute=investment_data.auto_contribute,
        start_date=investment_data.start_date,
        maturity_date=investment_data.maturity_date,
        institution_name=investment_data.institution_name,
        account_number=investment_data.account_number,
        status=ModelInvestmentStatus.ACTIVE
    )
    
    db.add(investment)
    db.commit()
    db.refresh(investment)
    
    result = InvestmentResponse.model_validate(investment)
    result.total_gain = 0
    result.gain_percentage = 0
    
    return result


@router.get("/summary", response_model=InvestmentSummary)
async def get_investment_summary(
    current_user: TokenPayload = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Get summary of all investments."""
    user_id = int(current_user.sub)
    
    investments = db.query(Investment).filter(Investment.user_id == user_id).all()
    
    total_invested = sum(inv.total_contributions - inv.total_withdrawals for inv in investments)
    total_current_value = sum(inv.current_value for inv in investments)
    total_gain = total_current_value - total_invested
    
    by_type = {}
    for inv in investments:
        inv_type = inv.investment_type.value
        if inv_type not in by_type:
            by_type[inv_type] = {"count": 0, "value": 0, "invested": 0}
        by_type[inv_type]["count"] += 1
        by_type[inv_type]["value"] += inv.current_value
        by_type[inv_type]["invested"] += inv.total_contributions - inv.total_withdrawals
    
    return InvestmentSummary(
        total_invested=round(total_invested, 2),
        total_current_value=round(total_current_value, 2),
        total_gain=round(total_gain, 2),
        overall_return_percentage=round((total_gain / total_invested * 100) if total_invested > 0 else 0, 2),
        investments_count=len(investments),
        active_investments=sum(1 for inv in investments if inv.status == ModelInvestmentStatus.ACTIVE),
        by_type=by_type
    )


@router.get("/advice", response_model=List[InvestmentAdvice])
async def get_investment_advice(
    current_user: TokenPayload = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Get personalized investment advice."""
    user_id = int(current_user.sub)
    
    investments = db.query(Investment).filter(
        and_(
            Investment.user_id == user_id,
            Investment.status == ModelInvestmentStatus.ACTIVE
        )
    ).all()
    
    advice_list = []
    
    # Check if user has any investments
    if not investments:
        advice_list.append(InvestmentAdvice(
            title="Start Your Investment Journey",
            message="Consider opening an Ejo Heza pension account. It offers tax benefits and helps secure your retirement with up to 10% annual returns.",
            advice_type="opportunity",
            priority="high"
        ))
        advice_list.append(InvestmentAdvice(
            title="Build an Emergency Fund First",
            message="Before investing, ensure you have at least 3 months of expenses saved in an easily accessible account.",
            advice_type="tip",
            priority="high"
        ))
    else:
        total_value = sum(inv.current_value for inv in investments)
        
        # Check for Ejo Heza
        has_ejo_heza = any(inv.investment_type == ModelInvestmentType.EJO_HEZA for inv in investments)
        if not has_ejo_heza:
            advice_list.append(InvestmentAdvice(
                title="Consider Ejo Heza Pension",
                message="Ejo Heza is Rwanda's voluntary pension scheme offering competitive returns and tax benefits. It's a great way to save for retirement.",
                advice_type="opportunity",
                priority="medium"
            ))
        
        # Check for SACCO
        has_sacco = any(inv.investment_type == ModelInvestmentType.SACCO for inv in investments)
        if not has_sacco:
            advice_list.append(InvestmentAdvice(
                title="Join a SACCO",
                message="Savings and Credit Cooperatives (SACCOs) offer higher interest rates than banks and provide access to affordable loans.",
                advice_type="tip",
                priority="medium"
            ))
        
        # Diversification advice
        investment_types = set(inv.investment_type for inv in investments)
        if len(investment_types) < 3:
            advice_list.append(InvestmentAdvice(
                title="Diversify Your Portfolio",
                message="Consider spreading your investments across different types (pensions, savings, stocks) to reduce risk.",
                advice_type="tip",
                priority="low"
            ))
        
        # Check for auto-contribution
        auto_contributors = [inv for inv in investments if inv.auto_contribute]
        if not auto_contributors:
            advice_list.append(InvestmentAdvice(
                title="Set Up Auto-Contributions",
                message="Automatic monthly contributions help build wealth consistently without the temptation to skip.",
                advice_type="tip",
                priority="medium"
            ))
        
        # RNIT recommendation
        has_rnit = any(inv.investment_type == ModelInvestmentType.RNIT for inv in investments)
        if not has_rnit and total_value > 100000:
            advice_list.append(InvestmentAdvice(
                title="Explore RNIT Investments",
                message="The Rwanda National Investment Trust offers a way to invest in the Rwandan economy with professional fund management.",
                advice_type="opportunity",
                priority="low"
            ))
    
    # General tips
    advice_list.append(InvestmentAdvice(
        title="Review Investments Quarterly",
        message="Set a reminder to review your investment performance every 3 months and adjust your strategy if needed.",
        advice_type="tip",
        priority="low"
    ))
    
    return advice_list[:5]  # Return top 5 advice


@router.get("/{investment_id}", response_model=InvestmentDetailResponse)
async def get_investment_detail(
    investment_id: int,
    current_user: TokenPayload = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Get detailed information about an investment."""
    user_id = int(current_user.sub)
    
    investment = db.query(Investment).filter(
        and_(
            Investment.id == investment_id,
            Investment.user_id == user_id
        )
    ).first()
    
    if not investment:
        raise HTTPException(status_code=404, detail="Investment not found")
    
    # Get contributions
    contributions = db.query(InvestmentContribution).filter(
        InvestmentContribution.investment_id == investment_id
    ).order_by(InvestmentContribution.contribution_date.desc()).all()
    
    # Generate projections (12 months)
    projections = []
    monthly_rate = investment.expected_annual_return / 100 / 12
    balance = investment.current_value
    
    for month in range(1, 13):
        interest = balance * monthly_rate
        contribution = investment.monthly_contribution
        balance += interest + contribution
        projections.append(InvestmentProjection(
            month=month,
            contribution=round(contribution, 2),
            interest=round(interest, 2),
            balance=round(balance, 2)
        ))
    
    # Generate advice specific to this investment
    advice = []
    if investment.investment_type == ModelInvestmentType.EJO_HEZA:
        advice.append(InvestmentAdvice(
            title="Maximize Tax Benefits",
            message="Contributions to Ejo Heza are tax-deductible. Consider increasing contributions before year-end.",
            advice_type="tip",
            priority="medium"
        ))
    
    if investment.monthly_contribution < investment.current_value * 0.05:
        advice.append(InvestmentAdvice(
            title="Increase Contributions",
            message="Consider increasing your monthly contribution to accelerate growth.",
            advice_type="tip",
            priority="low"
        ))
    
    result = InvestmentDetailResponse.model_validate(investment)
    result.total_gain = investment.current_value - investment.total_contributions + investment.total_withdrawals
    result.gain_percentage = (result.total_gain / investment.total_contributions * 100) if investment.total_contributions > 0 else 0
    result.contributions = [ContributionResponse.model_validate(c) for c in contributions]
    result.projections = projections
    result.advice = advice
    
    return result


@router.patch("/{investment_id}", response_model=InvestmentResponse)
async def update_investment(
    investment_id: int,
    update_data: InvestmentUpdate,
    current_user: TokenPayload = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Update an investment."""
    user_id = int(current_user.sub)
    
    investment = db.query(Investment).filter(
        and_(
            Investment.id == investment_id,
            Investment.user_id == user_id
        )
    ).first()
    
    if not investment:
        raise HTTPException(status_code=404, detail="Investment not found")
    
    update_dict = update_data.model_dump(exclude_unset=True)
    
    for field, value in update_dict.items():
        if field == "status" and value:
            value = ModelInvestmentStatus(value.value)
        setattr(investment, field, value)
    
    db.commit()
    db.refresh(investment)
    
    result = InvestmentResponse.model_validate(investment)
    result.total_gain = investment.current_value - investment.total_contributions + investment.total_withdrawals
    result.gain_percentage = (result.total_gain / investment.total_contributions * 100) if investment.total_contributions > 0 else 0
    
    return result


@router.delete("/{investment_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_investment(
    investment_id: int,
    current_user: TokenPayload = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Delete an investment."""
    user_id = int(current_user.sub)
    
    investment = db.query(Investment).filter(
        and_(
            Investment.id == investment_id,
            Investment.user_id == user_id
        )
    ).first()
    
    if not investment:
        raise HTTPException(status_code=404, detail="Investment not found")
    
    db.delete(investment)
    db.commit()


# ==================== Contributions ====================

@router.post("/{investment_id}/contribute", response_model=ContributionResponse)
async def add_contribution(
    investment_id: int,
    contribution_data: ContributionCreate,
    current_user: TokenPayload = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Add a contribution to an investment."""
    user_id = int(current_user.sub)
    
    investment = db.query(Investment).filter(
        and_(
            Investment.id == investment_id,
            Investment.user_id == user_id
        )
    ).first()
    
    if not investment:
        raise HTTPException(status_code=404, detail="Investment not found")
    
    contribution = InvestmentContribution(
        investment_id=investment_id,
        amount=contribution_data.amount,
        is_withdrawal=contribution_data.is_withdrawal,
        note=contribution_data.note,
        contribution_date=contribution_data.contribution_date
    )
    
    db.add(contribution)
    
    # Update investment totals
    if contribution_data.is_withdrawal:
        investment.total_withdrawals += contribution_data.amount
        investment.current_value -= contribution_data.amount
    else:
        investment.total_contributions += contribution_data.amount
        investment.current_value += contribution_data.amount
    
    db.commit()
    db.refresh(contribution)
    
    return ContributionResponse.model_validate(contribution)


@router.get("/{investment_id}/contributions", response_model=List[ContributionResponse])
async def get_contributions(
    investment_id: int,
    current_user: TokenPayload = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Get all contributions for an investment."""
    user_id = int(current_user.sub)
    
    # Verify ownership
    investment = db.query(Investment).filter(
        and_(
            Investment.id == investment_id,
            Investment.user_id == user_id
        )
    ).first()
    
    if not investment:
        raise HTTPException(status_code=404, detail="Investment not found")
    
    contributions = db.query(InvestmentContribution).filter(
        InvestmentContribution.investment_id == investment_id
    ).order_by(InvestmentContribution.contribution_date.desc()).all()
    
    return [ContributionResponse.model_validate(c) for c in contributions]
