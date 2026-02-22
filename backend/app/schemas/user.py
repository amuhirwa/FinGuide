"""
User Schemas
============
Pydantic schemas for user data validation and serialization.
"""

from typing import Optional
from datetime import datetime
from pydantic import BaseModel, Field, field_validator
from enum import Enum
import re


class UbudheCategory(str, Enum):
    """
    Rwandan Ubudehe socioeconomic classification categories.
    
    The Ubudehe program classifies Rwandan households into categories
    based on their socioeconomic status to target social protection programs.
    """
    CATEGORY_1 = "category_1"  # Poorest - eligible for full government support
    CATEGORY_2 = "category_2"  # Poor - partial support eligibility
    CATEGORY_3 = "category_3"  # Middle class - limited support
    CATEGORY_4 = "category_4"  # Wealthiest - no support needed


class IncomeFrequency(str, Enum):
    """
    Income frequency classification for financial profiling.
    
    This field is critical for the BiLSTM forecasting model to accurately
    predict cash flow patterns for users with irregular income.
    """
    DAILY = "daily"           # Daily wages (e.g., moto taxi drivers, vendors)
    WEEKLY = "weekly"         # Weekly payments
    BI_WEEKLY = "bi_weekly"   # Every two weeks
    MONTHLY = "monthly"       # Regular monthly salary (formal employment)
    IRREGULAR = "irregular"   # Gig economy / variable income (polyjobbers)
    SEASONAL = "seasonal"     # Agricultural / seasonal work


class UserBase(BaseModel):
    """
    Base user schema with common fields.
    """
    phone_number: str = Field(
        ...,
        description="Rwandan phone number (format: 07XXXXXXXX or +2507XXXXXXXX)",
        examples=["0781234567", "+250781234567"]
    )
    full_name: str = Field(
        ...,
        min_length=2,
        max_length=100,
        description="User's full name",
        examples=["Jean Baptiste Uwimana"]
    )
    
    @field_validator("phone_number")
    @classmethod
    def validate_phone_number(cls, v: str) -> str:
        """
        Validate and normalize Rwandan phone numbers.
        
        Accepts formats:
        - 07XXXXXXXX (local)
        - +2507XXXXXXXX (international)
        - 2507XXXXXXXX (without plus)
        """
        # Remove spaces and dashes
        cleaned = re.sub(r"[\s\-]", "", v)
        
        # Rwandan phone number patterns
        patterns = [
            r"^07[238]\d{7}$",           # Local format: 07X XXXX XXX
            r"^\+2507[238]\d{7}$",       # International with +
            r"^2507[238]\d{7}$",         # International without +
        ]
        
        if not any(re.match(p, cleaned) for p in patterns):
            raise ValueError(
                "Invalid Rwandan phone number. Use format: 07XXXXXXXX or +2507XXXXXXXX"
            )
        
        # Normalize to local format
        if cleaned.startswith("+250"):
            cleaned = "0" + cleaned[4:]
        elif cleaned.startswith("250"):
            cleaned = "0" + cleaned[3:]
        
        return cleaned


class UserCreate(UserBase):
    """
    Schema for user registration.
    
    Includes all required fields for creating a new FinGuide account,
    with Rwandan-specific financial profile fields.
    """
    password: str = Field(
        ...,
        min_length=6,
        description="Password (minimum 6 characters)",
        examples=["securePassword123"]
    )
    ubudehe_category: UbudheCategory = Field(
        default=UbudheCategory.CATEGORY_3,
        description="Rwandan Ubudehe socioeconomic category"
    )
    income_frequency: IncomeFrequency = Field(
        default=IncomeFrequency.IRREGULAR,
        description="How frequently the user receives income"
    )
    
    @field_validator("password")
    @classmethod
    def validate_password(cls, v: str) -> str:
        """Validate password strength."""
        if len(v) < 6:
            raise ValueError("Password must be at least 6 characters")
        return v


class UserLogin(BaseModel):
    """
    Schema for user login.
    
    Phone-centric authentication as per Rwandan mobile-first context.
    """
    phone_number: str = Field(
        ...,
        description="Registered phone number"
    )
    password: str = Field(
        ...,
        description="Account password"
    )

    @field_validator("phone_number")
    @classmethod
    def normalize_phone_number(cls, v: str) -> str:
        """Normalize phone number to local format, matching registration behaviour."""
        cleaned = re.sub(r"[\s\-]", "", v)
        if cleaned.startswith("+250"):
            cleaned = "0" + cleaned[4:]
        elif cleaned.startswith("250"):
            cleaned = "0" + cleaned[3:]
        return cleaned


class UserResponse(UserBase):
    """
    Schema for user response (excludes sensitive data).
    """
    id: int
    ubudehe_category: UbudheCategory
    income_frequency: IncomeFrequency
    is_active: bool
    is_verified: bool
    created_at: datetime
    
    class Config:
        from_attributes = True


class UserUpdate(BaseModel):
    """
    Schema for updating user profile.
    
    All fields are optional to allow partial updates.
    """
    full_name: Optional[str] = Field(
        None,
        min_length=2,
        max_length=100,
        description="User's full name"
    )
    ubudehe_category: Optional[UbudheCategory] = Field(
        None,
        description="Rwandan Ubudehe socioeconomic category"
    )
    income_frequency: Optional[IncomeFrequency] = Field(
        None,
        description="How frequently the user receives income"
    )


class Token(BaseModel):
    """
    JWT Token response schema.
    """
    access_token: str = Field(..., description="JWT access token")
    token_type: str = Field(default="bearer", description="Token type")
    user: UserResponse = Field(..., description="Authenticated user data")


class TokenPayload(BaseModel):
    """
    JWT Token payload schema.
    """
    sub: str = Field(..., description="Subject (user ID)")
    exp: Optional[int] = Field(None, description="Expiration timestamp")
