"""
Investment Model
================
SQLAlchemy models for investment tracking.
"""

from sqlalchemy import Column, String, Integer, Float, DateTime, Boolean, Enum, ForeignKey, Text
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from datetime import datetime
import enum

from app.models.base import Base


class InvestmentType(str, enum.Enum):
    """Type of investment."""
    EJO_HEZA = "ejo_heza"  # Rwanda pension fund
    RNIT = "rnit"  # Rwanda National Investment Trust
    SAVINGS_ACCOUNT = "savings_account"
    FIXED_DEPOSIT = "fixed_deposit"
    SACCO = "sacco"  # Savings and Credit Cooperative
    STOCKS = "stocks"
    BONDS = "bonds"
    MUTUAL_FUND = "mutual_fund"
    REAL_ESTATE = "real_estate"
    BUSINESS = "business"
    OTHER = "other"


class InvestmentStatus(str, enum.Enum):
    """Status of investment."""
    ACTIVE = "active"
    MATURED = "matured"
    WITHDRAWN = "withdrawn"
    PAUSED = "paused"


class Investment(Base):
    """
    Investment tracking model.
    
    Tracks user investments including pensions, savings, and other assets.
    """
    
    __tablename__ = "investments"
    
    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    
    # Investment Details
    name = Column(String(100), nullable=False)
    investment_type = Column(Enum(InvestmentType), nullable=False)
    description = Column(Text)
    
    # Financial Details
    initial_amount = Column(Float, nullable=False, default=0)
    current_value = Column(Float, nullable=False, default=0)
    total_contributions = Column(Float, default=0)
    total_withdrawals = Column(Float, default=0)
    
    # Returns
    expected_annual_return = Column(Float, default=0)  # As percentage
    actual_return_to_date = Column(Float, default=0)
    
    # Contribution Settings
    monthly_contribution = Column(Float, default=0)
    contribution_day = Column(Integer, default=1)  # Day of month for auto-contribution
    auto_contribute = Column(Boolean, default=False)
    
    # Dates
    start_date = Column(DateTime(timezone=True), nullable=False)
    maturity_date = Column(DateTime(timezone=True))
    
    # Status
    status = Column(Enum(InvestmentStatus), default=InvestmentStatus.ACTIVE)
    
    # Institution Info
    institution_name = Column(String(100))
    account_number = Column(String(50))
    
    # Metadata
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    
    # Relationships
    user = relationship("User", back_populates="investments")
    contributions = relationship("InvestmentContribution", back_populates="investment", cascade="all, delete-orphan")


class InvestmentContribution(Base):
    """
    Tracks individual contributions/withdrawals to investments.
    """
    
    __tablename__ = "investment_contributions"
    
    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    investment_id = Column(Integer, ForeignKey("investments.id"), nullable=False, index=True)
    
    # Contribution Details
    amount = Column(Float, nullable=False)
    is_withdrawal = Column(Boolean, default=False)
    note = Column(String(200))
    
    # Timestamps
    contribution_date = Column(DateTime(timezone=True), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relationships
    investment = relationship("Investment", back_populates="contributions")
