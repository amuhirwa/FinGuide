"""
Transaction Model
=================
SQLAlchemy model for financial transactions parsed from MoMo SMS.
"""

from sqlalchemy import Column, String, Integer, Float, DateTime, Boolean, Enum, ForeignKey, Text
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from datetime import datetime
import enum

from app.models.base import Base


class TransactionType(str, enum.Enum):
    """Transaction type classification."""
    INCOME = "income"
    EXPENSE = "expense"
    TRANSFER = "transfer"


class TransactionCategory(str, enum.Enum):
    """
    Transaction category classification.
    Based on Rwandan spending patterns.
    """
    # Income Categories
    SALARY = "salary"
    FREELANCE = "freelance"
    BUSINESS = "business"
    GIFT_RECEIVED = "gift_received"
    REFUND = "refund"
    OTHER_INCOME = "other_income"
    
    # Expense Categories - Basic Needs
    FOOD_GROCERIES = "food_groceries"
    TRANSPORT = "transport"
    UTILITIES = "utilities"
    RENT = "rent"
    HEALTHCARE = "healthcare"
    EDUCATION = "education"
    
    # Expense Categories - Wants
    ENTERTAINMENT = "entertainment"
    SHOPPING = "shopping"
    DINING_OUT = "dining_out"
    AIRTIME_DATA = "airtime_data"
    SUBSCRIPTIONS = "subscriptions"
    
    # Savings & Investment
    SAVINGS = "savings"
    EJO_HEZA = "ejo_heza"
    INVESTMENT = "investment"
    
    # Other
    TRANSFER_OUT = "transfer_out"
    FEES = "fees"
    OTHER = "other"


class NeedWantCategory(str, enum.Enum):
    """Classification for basic needs vs discretionary wants."""
    NEED = "need"
    WANT = "want"
    SAVINGS = "savings"
    UNCATEGORIZED = "uncategorized"


class Transaction(Base):
    """
    Transaction model representing financial transactions.
    
    Attributes:
        id: Unique identifier
        user_id: Foreign key to user
        transaction_type: Income, expense, or transfer
        category: Detailed category classification
        need_want: Basic need vs discretionary want
        amount: Transaction amount in RWF
        description: Transaction description
        counterparty: The other party (phone number or name)
        reference: MoMo transaction reference
        raw_sms: Original SMS text (for audit)
        transaction_date: When the transaction occurred
        is_recurring: Whether this appears to be recurring
        is_verified: User-verified transaction
        created_at: Record creation timestamp
    """
    
    __tablename__ = "transactions"
    
    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    
    # Transaction Details
    transaction_type = Column(Enum(TransactionType), nullable=False)
    category = Column(Enum(TransactionCategory), default=TransactionCategory.OTHER)
    need_want = Column(Enum(NeedWantCategory), default=NeedWantCategory.UNCATEGORIZED)
    
    amount = Column(Float, nullable=False)
    description = Column(String(255))
    counterparty = Column(String(100))  # Phone number or name
    counterparty_name = Column(String(100))  # Saved name for the counterparty
    reference = Column(String(50), unique=True, index=True)
    
    # SMS Data
    raw_sms = Column(Text)
    sms_sender = Column(String(50))
    
    # Metadata
    transaction_date = Column(DateTime(timezone=True), nullable=False)
    is_recurring = Column(Boolean, default=False)
    is_verified = Column(Boolean, default=False)
    confidence_score = Column(Float, default=1.0)  # AI parsing confidence
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationships
    user = relationship("User", back_populates="transactions")
    
    def __repr__(self) -> str:
        return f"<Transaction(id={self.id}, type={self.transaction_type}, amount={self.amount})>"


class CounterpartyMapping(Base):
    """
    Mapping of counterparties to categories for automatic classification.
    
    When a user categorizes a transaction from a specific counterparty,
    we remember it for future transactions.
    """
    
    __tablename__ = "counterparty_mappings"
    
    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    
    counterparty = Column(String(100), nullable=False)
    display_name = Column(String(100))
    category = Column(Enum(TransactionCategory), nullable=False)
    need_want = Column(Enum(NeedWantCategory), default=NeedWantCategory.UNCATEGORIZED)
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationships
    user = relationship("User", back_populates="counterparty_mappings")
