"""
Investment Schemas
==================
Pydantic schemas for investment data validation.
"""

from typing import Optional, List
from datetime import datetime
from pydantic import BaseModel, Field
from enum import Enum


class InvestmentType(str, Enum):
    EJO_HEZA = "ejo_heza"
    RNIT = "rnit"
    SAVINGS_ACCOUNT = "savings_account"
    FIXED_DEPOSIT = "fixed_deposit"
    SACCO = "sacco"
    STOCKS = "stocks"
    BONDS = "bonds"
    MUTUAL_FUND = "mutual_fund"
    REAL_ESTATE = "real_estate"
    BUSINESS = "business"
    OTHER = "other"


class InvestmentStatus(str, Enum):
    ACTIVE = "active"
    MATURED = "matured"
    WITHDRAWN = "withdrawn"
    PAUSED = "paused"


class InvestmentBase(BaseModel):
    """Base investment schema."""
    name: str = Field(..., min_length=1, max_length=100)
    investment_type: InvestmentType
    description: Optional[str] = None
    initial_amount: float = Field(default=0, ge=0)
    expected_annual_return: float = Field(default=0, ge=0, le=100)
    monthly_contribution: float = Field(default=0, ge=0)
    contribution_day: int = Field(default=1, ge=1, le=28)
    auto_contribute: bool = False
    start_date: datetime
    maturity_date: Optional[datetime] = None
    institution_name: Optional[str] = None
    account_number: Optional[str] = None


class InvestmentCreate(InvestmentBase):
    """Schema for creating an investment."""
    pass


class InvestmentUpdate(BaseModel):
    """Schema for updating an investment."""
    name: Optional[str] = None
    description: Optional[str] = None
    expected_annual_return: Optional[float] = None
    monthly_contribution: Optional[float] = None
    contribution_day: Optional[int] = None
    auto_contribute: Optional[bool] = None
    maturity_date: Optional[datetime] = None
    status: Optional[InvestmentStatus] = None


class InvestmentResponse(InvestmentBase):
    """Investment response schema."""
    id: int
    current_value: float
    total_contributions: float
    total_withdrawals: float
    actual_return_to_date: float
    status: InvestmentStatus
    created_at: datetime
    updated_at: Optional[datetime] = None
    
    # Calculated fields
    total_gain: Optional[float] = None
    gain_percentage: Optional[float] = None
    
    class Config:
        from_attributes = True


class ContributionCreate(BaseModel):
    """Schema for adding a contribution."""
    amount: float = Field(..., gt=0)
    is_withdrawal: bool = False
    note: Optional[str] = None
    contribution_date: datetime


class ContributionResponse(BaseModel):
    """Contribution response schema."""
    id: int
    investment_id: int
    amount: float
    is_withdrawal: bool
    note: Optional[str] = None
    contribution_date: datetime
    created_at: datetime
    
    class Config:
        from_attributes = True


class InvestmentSummary(BaseModel):
    """Summary of all investments."""
    total_invested: float
    total_current_value: float
    total_gain: float
    overall_return_percentage: float
    investments_count: int
    active_investments: int
    by_type: dict


class InvestmentAdvice(BaseModel):
    """Investment advice/tip."""
    title: str
    message: str
    advice_type: str  # tip, warning, opportunity
    priority: str  # high, medium, low
    action_url: Optional[str] = None


class InvestmentProjection(BaseModel):
    """Investment projection data."""
    month: int
    contribution: float
    interest: float
    balance: float


class InvestmentDetailResponse(InvestmentResponse):
    """Detailed investment response with contributions."""
    contributions: List[ContributionResponse] = []
    projections: List[InvestmentProjection] = []
    advice: List[InvestmentAdvice] = []
