"""
Prediction Model
================
SQLAlchemy models for AI predictions (income, expense forecasting).
"""

from sqlalchemy import Column, String, Integer, Float, DateTime, Boolean, Enum, ForeignKey, JSON
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from datetime import datetime
import enum

from app.models.base import Base


class PredictionType(str, enum.Enum):
    """Type of prediction."""
    INCOME = "income"
    EXPENSE = "expense"
    CASH_FLOW = "cash_flow"


class IncomePrediction(Base):
    """
    Income prediction model.
    
    Stores AI-generated predictions for upcoming income.
    """
    
    __tablename__ = "income_predictions"
    
    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    
    # Prediction Details
    predicted_amount = Column(Float, nullable=False)
    predicted_date = Column(DateTime(timezone=True), nullable=False)
    confidence = Column(Float, default=0.7)  # 0-1 confidence score
    
    # Confidence Bands
    amount_lower_bound = Column(Float)  # Best case
    amount_upper_bound = Column(Float)  # Worst case
    
    # Source Info
    source_category = Column(String(50))  # e.g., "salary", "freelance"
    
    # Metadata
    is_realized = Column(Boolean, default=False)  # Did this prediction come true?
    actual_amount = Column(Float)  # Actual amount received
    actual_date = Column(DateTime(timezone=True))
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relationships
    user = relationship("User", back_populates="income_predictions")


class ExpensePrediction(Base):
    """
    Expense prediction model.
    
    Stores AI-generated predictions for upcoming expenses.
    """
    
    __tablename__ = "expense_predictions"
    
    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    
    # Prediction Details
    predicted_amount = Column(Float, nullable=False)
    predicted_date = Column(DateTime(timezone=True), nullable=False)
    category = Column(String(50))
    confidence = Column(Float, default=0.7)
    
    # Confidence Bands
    amount_lower_bound = Column(Float)
    amount_upper_bound = Column(Float)
    
    # Metadata
    is_recurring = Column(Boolean, default=False)
    recurrence_pattern = Column(String(50))  # daily, weekly, monthly
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relationships
    user = relationship("User", back_populates="expense_predictions")


class FinancialHealthScore(Base):
    """
    Financial health score tracking.
    
    A composite score based on:
    - Income volatility
    - Savings rate
    - Emergency buffer (liquidity)
    - Debt-to-income ratio
    - Goal progress
    """
    
    __tablename__ = "financial_health_scores"
    
    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    
    # Overall Score (0-100)
    overall_score = Column(Integer, nullable=False)
    
    # Component Scores (0-100)
    income_stability_score = Column(Integer, default=50)
    savings_rate_score = Column(Integer, default=50)
    emergency_buffer_score = Column(Integer, default=50)
    goal_progress_score = Column(Integer, default=50)
    spending_discipline_score = Column(Integer, default=50)
    
    # Metrics
    monthly_income_avg = Column(Float, default=0)
    monthly_expense_avg = Column(Float, default=0)
    savings_rate = Column(Float, default=0)  # Percentage
    emergency_buffer_days = Column(Integer, default=0)  # Days of expenses covered
    
    # Trend
    score_change = Column(Integer, default=0)  # Change from last score
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relationships
    user = relationship("User", back_populates="health_scores")


class Recommendation(Base):
    """
    AI-generated financial recommendations and nudges.
    """
    
    __tablename__ = "recommendations"
    
    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    
    # Recommendation Details
    title = Column(String(100), nullable=False)
    message = Column(String(500), nullable=False)
    recommendation_type = Column(String(50))  # savings, investment, spending, etc.
    
    # Action
    action_type = Column(String(50))  # save, invest, reduce_spending, etc.
    action_amount = Column(Float)
    action_url = Column(String(255))  # Deep link or external URL
    
    # Context
    reason = Column(String(255))  # "Why am I seeing this?"
    urgency = Column(String(20), default="normal")  # low, normal, high
    
    # Interaction Tracking
    is_viewed = Column(Boolean, default=False)
    viewed_at = Column(DateTime(timezone=True))
    is_acted_upon = Column(Boolean, default=False)
    acted_at = Column(DateTime(timezone=True))
    is_dismissed = Column(Boolean, default=False)
    dismissed_at = Column(DateTime(timezone=True))
    
    # Validity
    valid_until = Column(DateTime(timezone=True))
    is_active = Column(Boolean, default=True)
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relationships
    user = relationship("User", back_populates="recommendations")
