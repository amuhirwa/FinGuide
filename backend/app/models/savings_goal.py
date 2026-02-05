"""
Savings Goal Model
==================
SQLAlchemy model for user savings goals.
"""

from sqlalchemy import Column, String, Integer, Float, DateTime, Boolean, Enum, ForeignKey
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from datetime import datetime
import enum

from app.models.base import Base


class GoalPriority(str, enum.Enum):
    """Savings goal priority levels."""
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"


class GoalStatus(str, enum.Enum):
    """Savings goal status."""
    ACTIVE = "active"
    PAUSED = "paused"
    COMPLETED = "completed"
    CANCELLED = "cancelled"


class SavingsGoal(Base):
    """
    Savings goal model for tracking user financial goals.
    
    Attributes:
        id: Unique identifier
        user_id: Foreign key to user
        name: Goal name
        target_amount: Target amount to save
        current_amount: Currently saved amount
        priority: Goal priority level
        deadline: Target date to achieve goal
        status: Current goal status
        is_flexible: Whether deadline can be extended
        daily_target: Calculated daily savings target
        weekly_target: Calculated weekly savings target
    """
    
    __tablename__ = "savings_goals"
    
    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    
    # Goal Details
    name = Column(String(100), nullable=False)
    description = Column(String(255))
    target_amount = Column(Float, nullable=False)
    current_amount = Column(Float, default=0.0)
    
    # Priority & Timeline
    priority = Column(Enum(GoalPriority), default=GoalPriority.MEDIUM)
    deadline = Column(DateTime(timezone=True))
    is_flexible = Column(Boolean, default=True)  # Can deadline be extended?
    
    # Status
    status = Column(Enum(GoalStatus), default=GoalStatus.ACTIVE)
    
    # Calculated Targets (updated by the system)
    daily_target = Column(Float, default=0.0)
    weekly_target = Column(Float, default=0.0)
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    completed_at = Column(DateTime(timezone=True))
    
    # Relationships
    user = relationship("User", back_populates="savings_goals")
    contributions = relationship("GoalContribution", back_populates="goal", cascade="all, delete-orphan")
    
    @property
    def progress_percentage(self) -> float:
        """Calculate progress percentage."""
        if self.target_amount <= 0:
            return 0.0
        return min((self.current_amount / self.target_amount) * 100, 100.0)
    
    @property
    def remaining_amount(self) -> float:
        """Calculate remaining amount to reach goal."""
        return max(self.target_amount - self.current_amount, 0.0)
    
    def __repr__(self) -> str:
        return f"<SavingsGoal(id={self.id}, name={self.name}, progress={self.progress_percentage:.1f}%)>"


class GoalContribution(Base):
    """
    Individual contributions to a savings goal.
    """
    
    __tablename__ = "goal_contributions"
    
    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    goal_id = Column(Integer, ForeignKey("savings_goals.id"), nullable=False, index=True)
    
    amount = Column(Float, nullable=False)
    note = Column(String(255))
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relationships
    goal = relationship("SavingsGoal", back_populates="contributions")
