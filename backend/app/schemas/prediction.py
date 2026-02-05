"""
Prediction Schemas
==================
Pydantic schemas for AI predictions and insights.
"""

from typing import Optional, List
from datetime import datetime
from pydantic import BaseModel, Field


class IncomePredictionResponse(BaseModel):
    """Income prediction response."""
    id: int
    predicted_amount: float
    predicted_date: datetime
    confidence: float
    amount_lower_bound: Optional[float] = None
    amount_upper_bound: Optional[float] = None
    source_category: Optional[str] = None
    created_at: datetime
    
    class Config:
        from_attributes = True


class ExpensePredictionResponse(BaseModel):
    """Expense prediction response."""
    id: int
    predicted_amount: float
    predicted_date: datetime
    category: Optional[str] = None
    confidence: float
    amount_lower_bound: Optional[float] = None
    amount_upper_bound: Optional[float] = None
    is_recurring: bool = False
    created_at: datetime
    
    class Config:
        from_attributes = True


class CashFlowForecast(BaseModel):
    """Cash flow forecast for a period."""
    period_start: datetime
    period_end: datetime
    predicted_income: float
    predicted_expenses: float
    predicted_net_flow: float
    confidence: float
    daily_breakdown: List[dict]  # [{date, income, expense, balance}]


class FinancialHealthScoreResponse(BaseModel):
    """Financial health score response."""
    overall_score: int = Field(..., ge=0, le=100)
    income_stability_score: int = Field(..., ge=0, le=100)
    savings_rate_score: int = Field(..., ge=0, le=100)
    emergency_buffer_score: int = Field(..., ge=0, le=100)
    goal_progress_score: int = Field(..., ge=0, le=100)
    spending_discipline_score: int = Field(..., ge=0, le=100)
    
    monthly_income_avg: float
    monthly_expense_avg: float
    savings_rate: float
    emergency_buffer_days: int
    
    score_change: int  # Change from previous
    grade: str  # A, B, C, D, F
    summary: str
    
    created_at: datetime
    
    class Config:
        from_attributes = True


class SafeToSpendResponse(BaseModel):
    """Safe to spend calculation response."""
    safe_to_spend: float
    total_balance: float
    reserved_for_expenses: float
    reserved_for_goals: float
    emergency_buffer: float
    explanation: str


class RecommendationResponse(BaseModel):
    """Recommendation/nudge response."""
    id: int
    title: str
    message: str
    recommendation_type: str
    action_type: Optional[str] = None
    action_amount: Optional[float] = None
    action_url: Optional[str] = None
    reason: Optional[str] = None
    urgency: str = "normal"
    is_viewed: bool = False
    is_acted_upon: bool = False
    created_at: datetime
    
    class Config:
        from_attributes = True


class RecommendationInteraction(BaseModel):
    """Schema for tracking recommendation interactions."""
    action: str = Field(..., pattern="^(viewed|acted|dismissed)$")


class InvestmentSimulationRequest(BaseModel):
    """Request for investment simulation."""
    principal: float = Field(..., gt=0, description="Initial investment amount")
    monthly_contribution: float = Field(default=0, ge=0)
    investment_type: str = Field(default="ejo_heza", description="Type: ejo_heza, rnit, savings")
    duration_months: int = Field(..., gt=0, le=360, description="Investment duration in months")


class InvestmentSimulationResponse(BaseModel):
    """Investment simulation response."""
    investment_type: str
    principal: float
    monthly_contribution: float
    duration_months: int
    annual_rate: float
    
    # Results
    total_contributions: float
    total_interest: float
    final_value: float
    effective_annual_return: float
    
    # Monthly breakdown
    monthly_breakdown: List[dict]  # [{month, contribution, interest, balance}]


class DashboardSummary(BaseModel):
    """Dashboard summary response."""
    # Balance
    total_balance: float
    balance_change: float
    balance_change_percentage: float
    
    # Income/Expense
    income_this_month: float
    expenses_this_month: float
    net_this_month: float
    
    # Safe to Spend
    safe_to_spend: float
    
    # Health Score
    health_score: int
    health_grade: str
    
    # Goals
    active_goals_count: int
    goals_on_track: int
    
    # Predictions
    next_income_prediction: Optional[IncomePredictionResponse] = None
    upcoming_expenses: List[ExpensePredictionResponse] = []
    
    # Recent Recommendations
    active_recommendations: List[RecommendationResponse] = []


class IrregularityAlert(BaseModel):
    """Irregularity detection alert."""
    alert_type: str  # unusual_income, unusual_expense, risk_period
    title: str
    description: str
    severity: str  # low, medium, high
    related_amount: Optional[float] = None
    detected_at: datetime
