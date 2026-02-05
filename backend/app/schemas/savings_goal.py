"""
Savings Goal Schemas
====================
Pydantic schemas for savings goals validation.
"""

from typing import Optional, List
from datetime import datetime
from pydantic import BaseModel, Field
from enum import Enum


class GoalPriority(str, Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"


class GoalStatus(str, Enum):
    ACTIVE = "active"
    PAUSED = "paused"
    COMPLETED = "completed"
    CANCELLED = "cancelled"


class SavingsGoalBase(BaseModel):
    """Base savings goal schema."""
    name: str = Field(..., min_length=1, max_length=100)
    description: Optional[str] = None
    target_amount: float = Field(..., gt=0)
    priority: GoalPriority = GoalPriority.MEDIUM
    deadline: Optional[datetime] = None
    is_flexible: bool = True


class SavingsGoalCreate(SavingsGoalBase):
    """Schema for creating a savings goal."""
    pass


class SavingsGoalUpdate(BaseModel):
    """Schema for updating a savings goal."""
    name: Optional[str] = None
    description: Optional[str] = None
    target_amount: Optional[float] = None
    priority: Optional[GoalPriority] = None
    deadline: Optional[datetime] = None
    is_flexible: Optional[bool] = None
    status: Optional[GoalStatus] = None


class SavingsGoalResponse(SavingsGoalBase):
    """Savings goal response schema."""
    id: int
    current_amount: float
    status: GoalStatus
    daily_target: float
    weekly_target: float
    progress_percentage: float
    remaining_amount: float
    created_at: datetime
    completed_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True


class GoalContributionCreate(BaseModel):
    """Schema for adding contribution to a goal."""
    amount: float = Field(..., gt=0)
    note: Optional[str] = None


class GoalContributionResponse(GoalContributionCreate):
    """Goal contribution response."""
    id: int
    goal_id: int
    created_at: datetime
    
    class Config:
        from_attributes = True


class SavingsGoalDetailResponse(SavingsGoalResponse):
    """Detailed savings goal with contributions."""
    contributions: List[GoalContributionResponse] = []
