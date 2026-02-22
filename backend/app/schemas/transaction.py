"""
Transaction Schemas
===================
Pydantic schemas for transaction data validation.
"""

from typing import Optional, List
from datetime import datetime
from pydantic import BaseModel, Field
from enum import Enum


class TransactionType(str, Enum):
    INCOME = "income"
    EXPENSE = "expense"
    TRANSFER = "transfer"


class TransactionCategory(str, Enum):
    # Income
    SALARY = "salary"
    FREELANCE = "freelance"
    BUSINESS = "business"
    GIFT_RECEIVED = "gift_received"
    REFUND = "refund"
    OTHER_INCOME = "other_income"
    # Expense - Needs
    FOOD_GROCERIES = "food_groceries"
    TRANSPORT = "transport"
    UTILITIES = "utilities"
    RENT = "rent"
    HEALTHCARE = "healthcare"
    EDUCATION = "education"
    # Expense - Wants
    ENTERTAINMENT = "entertainment"
    SHOPPING = "shopping"
    DINING_OUT = "dining_out"
    AIRTIME_DATA = "airtime_data"
    SUBSCRIPTIONS = "subscriptions"
    # Savings
    SAVINGS = "savings"
    EJO_HEZA = "ejo_heza"
    INVESTMENT = "investment"
    # Other
    TRANSFER_OUT = "transfer_out"
    FEES = "fees"
    OTHER = "other"


class NeedWantCategory(str, Enum):
    NEED = "need"
    WANT = "want"
    SAVINGS = "savings"
    UNCATEGORIZED = "uncategorized"


class TransactionBase(BaseModel):
    """Base transaction schema."""
    transaction_type: TransactionType
    category: TransactionCategory = TransactionCategory.OTHER
    need_want: NeedWantCategory = NeedWantCategory.UNCATEGORIZED
    amount: float = Field(..., gt=0, description="Transaction amount in RWF")
    description: Optional[str] = None
    counterparty: Optional[str] = None
    counterparty_name: Optional[str] = None
    transaction_date: datetime


class TransactionCreate(TransactionBase):
    """Schema for creating a transaction."""
    reference: Optional[str] = None
    raw_sms: Optional[str] = None


class TransactionUpdate(BaseModel):
    """Schema for updating a transaction."""
    category: Optional[TransactionCategory] = None
    need_want: Optional[NeedWantCategory] = None
    description: Optional[str] = None
    counterparty_name: Optional[str] = None
    is_verified: Optional[bool] = None


class TransactionResponse(TransactionBase):
    """Transaction response schema."""
    id: int
    # Override amount to allow zero for legacy records saved by old parser
    amount: float = Field(..., ge=0, description="Transaction amount in RWF")
    reference: Optional[str] = None
    is_recurring: bool = False
    is_verified: bool = False
    confidence_score: float = 1.0
    created_at: datetime

    class Config:
        from_attributes = True


class TransactionListResponse(BaseModel):
    """Paginated transaction list response."""
    transactions: List[TransactionResponse]
    total: int
    page: int
    page_size: int
    total_pages: int


class SMSParseRequest(BaseModel):
    """Request schema for parsing SMS messages."""
    messages: List[str] = Field(..., description="List of SMS message texts to parse")


class SMSParseResponse(BaseModel):
    """Response schema for parsed SMS."""
    parsed_count: int
    failed_count: int
    transactions: List[TransactionResponse]


class TransactionSummary(BaseModel):
    """Summary of transactions for a period."""
    total_income: float
    total_expenses: float
    net_flow: float
    transaction_count: int
    category_breakdown: dict
    need_want_breakdown: dict


class CounterpartyMappingCreate(BaseModel):
    """Schema for creating counterparty mapping."""
    counterparty: str
    display_name: Optional[str] = None
    category: TransactionCategory
    need_want: NeedWantCategory = NeedWantCategory.UNCATEGORIZED


class CounterpartyMappingResponse(CounterpartyMappingCreate):
    """Counterparty mapping response."""
    id: int
    created_at: datetime
    
    class Config:
        from_attributes = True
