"""
OTP Code Model
==============
SQLAlchemy model for one-time password codes used in phone verification.
"""

from sqlalchemy import Column, String, Integer, DateTime, Boolean
from sqlalchemy.sql import func
from datetime import datetime

from app.models.base import Base


class OTPCode(Base):
    """
    Stores one-time password codes tied to phone numbers.

    Each record represents a single OTP send attempt.
    Codes are marked as used once verified, or expire after OTP_EXPIRE_MINUTES.

    Attributes:
        id: Auto-incremented primary key
        phone_number: Rwandan phone number the OTP was sent to
        code: Six-digit numeric OTP code
        created_at: When the OTP was generated
        expires_at: When the OTP expires (typically 5 minutes after creation)
        is_used: True once the code has been successfully verified
    """

    __tablename__ = "otp_codes"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    phone_number = Column(String(20), index=True, nullable=False)
    code = Column(String(6), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    expires_at = Column(DateTime, nullable=False)
    is_used = Column(Boolean, default=False, nullable=False)

    def __repr__(self) -> str:
        return (
            f"<OTPCode id={self.id} phone={self.phone_number} "
            f"used={self.is_used} expires={self.expires_at}>"
        )
