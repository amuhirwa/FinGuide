"""
Savings Goals Endpoints
=======================
CRUD operations for savings goals.
"""

from typing import List
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import and_

from app.models.base import get_db
from app.models.savings_goal import SavingsGoal, GoalContribution
from app.models.savings_goal import GoalPriority as ModelPriority, GoalStatus as ModelStatus
from app.schemas.savings_goal import (
    SavingsGoalCreate, SavingsGoalUpdate, SavingsGoalResponse,
    SavingsGoalDetailResponse, GoalContributionCreate, GoalContributionResponse
)
from app.schemas.user import TokenPayload
from app.core.deps import get_current_active_user

router = APIRouter()


def calculate_targets(goal: SavingsGoal):
    """Calculate daily and weekly savings targets for a goal."""
    if goal.status != ModelStatus.ACTIVE or not goal.deadline:
        return 0, 0
    
    remaining = goal.target_amount - goal.current_amount
    if remaining <= 0:
        return 0, 0
    
    days_remaining = (goal.deadline - datetime.now()).days
    if days_remaining <= 0:
        return remaining, remaining
    
    daily_target = remaining / days_remaining
    weekly_target = daily_target * 7
    
    return round(daily_target, 2), round(weekly_target, 2)


@router.get("", response_model=List[SavingsGoalResponse])
async def get_savings_goals(
    status: str = None,
    current_user: TokenPayload = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Get all savings goals for the user."""
    query = db.query(SavingsGoal).filter(
        SavingsGoal.user_id == int(current_user.sub)
    )
    
    if status:
        query = query.filter(SavingsGoal.status == ModelStatus(status))
    
    goals = query.order_by(SavingsGoal.priority.desc(), SavingsGoal.deadline).all()
    
    # Update calculated fields
    response_goals = []
    for goal in goals:
        daily, weekly = calculate_targets(goal)
        goal.daily_target = daily
        goal.weekly_target = weekly
        
        response_goals.append(SavingsGoalResponse(
            id=goal.id,
            name=goal.name,
            description=goal.description,
            target_amount=goal.target_amount,
            current_amount=goal.current_amount,
            priority=goal.priority.value,
            deadline=goal.deadline,
            is_flexible=goal.is_flexible,
            status=goal.status.value,
            daily_target=daily,
            weekly_target=weekly,
            progress_percentage=goal.progress_percentage,
            remaining_amount=goal.remaining_amount,
            created_at=goal.created_at,
            completed_at=goal.completed_at
        ))
    
    return response_goals


@router.post("", response_model=SavingsGoalResponse, status_code=status.HTTP_201_CREATED)
async def create_savings_goal(
    goal_data: SavingsGoalCreate,
    current_user: TokenPayload = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Create a new savings goal."""
    goal = SavingsGoal(
        user_id=int(current_user.sub),
        name=goal_data.name,
        description=goal_data.description,
        target_amount=goal_data.target_amount,
        priority=ModelPriority(goal_data.priority.value),
        deadline=goal_data.deadline,
        is_flexible=goal_data.is_flexible
    )
    
    db.add(goal)
    db.commit()
    db.refresh(goal)
    
    daily, weekly = calculate_targets(goal)
    
    return SavingsGoalResponse(
        id=goal.id,
        name=goal.name,
        description=goal.description,
        target_amount=goal.target_amount,
        current_amount=goal.current_amount,
        priority=goal.priority.value,
        deadline=goal.deadline,
        is_flexible=goal.is_flexible,
        status=goal.status.value,
        daily_target=daily,
        weekly_target=weekly,
        progress_percentage=goal.progress_percentage,
        remaining_amount=goal.remaining_amount,
        created_at=goal.created_at,
        completed_at=goal.completed_at
    )


@router.get("/{goal_id}", response_model=SavingsGoalDetailResponse)
async def get_savings_goal(
    goal_id: int,
    current_user: TokenPayload = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Get a specific savings goal with contributions."""
    goal = db.query(SavingsGoal).filter(
        and_(
            SavingsGoal.id == goal_id,
            SavingsGoal.user_id == int(current_user.sub)
        )
    ).first()
    
    if not goal:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Savings goal not found"
        )
    
    daily, weekly = calculate_targets(goal)
    
    contributions = [
        GoalContributionResponse(
            id=c.id,
            goal_id=c.goal_id,
            amount=c.amount,
            note=c.note,
            created_at=c.created_at
        )
        for c in goal.contributions
    ]
    
    return SavingsGoalDetailResponse(
        id=goal.id,
        name=goal.name,
        description=goal.description,
        target_amount=goal.target_amount,
        current_amount=goal.current_amount,
        priority=goal.priority.value,
        deadline=goal.deadline,
        is_flexible=goal.is_flexible,
        status=goal.status.value,
        daily_target=daily,
        weekly_target=weekly,
        progress_percentage=goal.progress_percentage,
        remaining_amount=goal.remaining_amount,
        created_at=goal.created_at,
        completed_at=goal.completed_at,
        contributions=contributions
    )


@router.patch("/{goal_id}", response_model=SavingsGoalResponse)
async def update_savings_goal(
    goal_id: int,
    update_data: SavingsGoalUpdate,
    current_user: TokenPayload = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Update a savings goal."""
    goal = db.query(SavingsGoal).filter(
        and_(
            SavingsGoal.id == goal_id,
            SavingsGoal.user_id == int(current_user.sub)
        )
    ).first()
    
    if not goal:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Savings goal not found"
        )
    
    if update_data.name is not None:
        goal.name = update_data.name
    if update_data.description is not None:
        goal.description = update_data.description
    if update_data.target_amount is not None:
        goal.target_amount = update_data.target_amount
    if update_data.priority is not None:
        goal.priority = ModelPriority(update_data.priority.value)
    if update_data.deadline is not None:
        goal.deadline = update_data.deadline
    if update_data.is_flexible is not None:
        goal.is_flexible = update_data.is_flexible
    if update_data.status is not None:
        goal.status = ModelStatus(update_data.status.value)
        if update_data.status.value == "completed":
            goal.completed_at = datetime.now()
    
    db.commit()
    db.refresh(goal)
    
    daily, weekly = calculate_targets(goal)
    
    return SavingsGoalResponse(
        id=goal.id,
        name=goal.name,
        description=goal.description,
        target_amount=goal.target_amount,
        current_amount=goal.current_amount,
        priority=goal.priority.value,
        deadline=goal.deadline,
        is_flexible=goal.is_flexible,
        status=goal.status.value,
        daily_target=daily,
        weekly_target=weekly,
        progress_percentage=goal.progress_percentage,
        remaining_amount=goal.remaining_amount,
        created_at=goal.created_at,
        completed_at=goal.completed_at
    )


@router.delete("/{goal_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_savings_goal(
    goal_id: int,
    current_user: TokenPayload = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Delete a savings goal."""
    goal = db.query(SavingsGoal).filter(
        and_(
            SavingsGoal.id == goal_id,
            SavingsGoal.user_id == int(current_user.sub)
        )
    ).first()
    
    if not goal:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Savings goal not found"
        )
    
    db.delete(goal)
    db.commit()


@router.post("/{goal_id}/contribute", response_model=SavingsGoalResponse)
async def contribute_to_goal(
    goal_id: int,
    contribution: GoalContributionCreate,
    current_user: TokenPayload = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Add a contribution to a savings goal."""
    goal = db.query(SavingsGoal).filter(
        and_(
            SavingsGoal.id == goal_id,
            SavingsGoal.user_id == int(current_user.sub)
        )
    ).first()
    
    if not goal:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Savings goal not found"
        )
    
    if goal.status != ModelStatus.ACTIVE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot contribute to an inactive goal"
        )
    
    # Create contribution record
    contrib = GoalContribution(
        goal_id=goal.id,
        amount=contribution.amount,
        note=contribution.note
    )
    db.add(contrib)
    
    # Update goal amount
    goal.current_amount += contribution.amount
    
    # Check if goal is completed
    if goal.current_amount >= goal.target_amount:
        goal.status = ModelStatus.COMPLETED
        goal.completed_at = datetime.now()
    
    db.commit()
    db.refresh(goal)
    
    daily, weekly = calculate_targets(goal)
    
    return SavingsGoalResponse(
        id=goal.id,
        name=goal.name,
        description=goal.description,
        target_amount=goal.target_amount,
        current_amount=goal.current_amount,
        priority=goal.priority.value,
        deadline=goal.deadline,
        is_flexible=goal.is_flexible,
        status=goal.status.value,
        daily_target=daily,
        weekly_target=weekly,
        progress_percentage=goal.progress_percentage,
        remaining_amount=goal.remaining_amount,
        created_at=goal.created_at,
        completed_at=goal.completed_at
    )
