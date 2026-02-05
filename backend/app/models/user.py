"""
User Model
==========
SQLAlchemy model for user data persistence.
"""

from sqlalchemy import Column, String, Integer, DateTime, Boolean, Enum
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from datetime import datetime
import enum

from app.models.base import Base


class UbudheCategory(str, enum.Enum):
    """
    Rwandan Ubudehe socioeconomic classification categories.
    
    Categories range from 1 (poorest) to 4 (wealthiest).
    """
    CATEGORY_1 = "category_1"  # Poorest - extreme poverty
    CATEGORY_2 = "category_2"  # Poor
    CATEGORY_3 = "category_3"  # Middle class
    CATEGORY_4 = "category_4"  # Wealthiest


class IncomeFrequency(str, enum.Enum):
    """
    Income frequency classification for financial profiling.
    """
    DAILY = "daily"           # Daily wages (e.g., day laborers)
    WEEKLY = "weekly"         # Weekly payments
    BI_WEEKLY = "bi_weekly"   # Every two weeks
    MONTHLY = "monthly"       # Regular monthly salary
    IRREGULAR = "irregular"   # Gig economy / variable income
    SEASONAL = "seasonal"     # Agricultural / seasonal work


class User(Base):
    """
    User model representing FinGuide application users.
    
    Attributes:
        id: Unique identifier
        phone_number: Primary identifier for authentication (Rwandan format)
        full_name: User's full name
        hashed_password: Bcrypt hashed password
        ubudehe_category: Rwandan socioeconomic classification
        income_frequency: How often the user receives income
        is_active: Whether the account is active
        is_verified: Whether phone number is verified
        created_at: Account creation timestamp
        updated_at: Last update timestamp
    """
    
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    phone_number = Column(String(15), unique=True, index=True, nullable=False)
    full_name = Column(String(100), nullable=False)
    hashed_password = Column(String(255), nullable=False)
    
    # Financial Profile Fields (Rwandan Context)
    ubudehe_category = Column(
        Enum(UbudheCategory),
        default=UbudheCategory.CATEGORY_3,
        nullable=False
    )
    income_frequency = Column(
        Enum(IncomeFrequency),
        default=IncomeFrequency.IRREGULAR,
        nullable=False
    )
    
    # Account Status
    is_active = Column(Boolean, default=True)
    is_verified = Column(Boolean, default=False)
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationships
    transactions = relationship("Transaction", back_populates="user", cascade="all, delete-orphan")
    counterparty_mappings = relationship("CounterpartyMapping", back_populates="user", cascade="all, delete-orphan")
    savings_goals = relationship("SavingsGoal", back_populates="user", cascade="all, delete-orphan")
    income_predictions = relationship("IncomePrediction", back_populates="user", cascade="all, delete-orphan")
    expense_predictions = relationship("ExpensePrediction", back_populates="user", cascade="all, delete-orphan")
    health_scores = relationship("FinancialHealthScore", back_populates="user", cascade="all, delete-orphan")
    recommendations = relationship("Recommendation", back_populates="user", cascade="all, delete-orphan")
    
    def __repr__(self) -> str:
        return f"<User(id={self.id}, phone={self.phone_number}, name={self.full_name})>"
