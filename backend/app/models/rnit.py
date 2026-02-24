"""
RNIT Investment Models
======================
Models for tracking Rwanda National Investment Trust (RNIT) fund purchases
and Net Asset Value (NAV) history cache.
"""

from sqlalchemy import Column, String, Integer, Float, DateTime, ForeignKey, UniqueConstraint
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from datetime import datetime

from app.models.base import Base


class RnitPurchase(Base):
    """
    Records an individual RNIT purchase detected from an MTN MoMo SMS.

    units = amount_rwf / nav_at_purchase  (computed at creation time)
    """

    __tablename__ = "rnit_purchases"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)

    # The transaction that triggered this purchase (optional link)
    transaction_id = Column(Integer, ForeignKey("transactions.id"), nullable=True)

    # Purchase details
    purchase_date = Column(DateTime(timezone=True), nullable=False)
    amount_rwf = Column(Float, nullable=False)          # RWF paid
    nav_at_purchase = Column(Float, nullable=True)      # NAV on that date (filled async)
    units = Column(Float, nullable=True)                # amount_rwf / nav_at_purchase

    # Metadata
    raw_sms = Column(String(500), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class RnitNavCache(Base):
    """
    Cached NAV (Net Asset Value) history scraped from rnit.rw.
    One row per date.
    """

    __tablename__ = "rnit_nav_cache"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    nav_date = Column(DateTime(timezone=True), nullable=False, unique=True, index=True)
    nav_rwf = Column(Float, nullable=False)
    scraped_at = Column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (
        UniqueConstraint("nav_date", name="uq_rnit_nav_date"),
    )
