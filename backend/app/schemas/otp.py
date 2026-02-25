"""
OTP Schemas
===========
Pydantic schemas for send-OTP and verify-OTP request/response payloads.

Phone numbers are normalised to local Rwandan format (07XXXXXXXX) so they
always match the value stored in the OTP token and in UserCreate/UserLogin.
"""

import re
from pydantic import BaseModel, Field, field_validator


def _normalise_phone(v: str) -> str:
    """
    Normalise a Rwandan phone number to local format (07XXXXXXXX).

    Accepts: 07XXXXXXXX | +2507XXXXXXXX | 2507XXXXXXXX
    """
    cleaned = re.sub(r"[\s\-]", "", v)
    if cleaned.startswith("+250"):
        cleaned = "0" + cleaned[4:]
    elif cleaned.startswith("250"):
        cleaned = "0" + cleaned[3:]
    return cleaned


class SendOtpRequest(BaseModel):
    """
    Request body for POST /auth/send-otp.
    """
    phone_number: str = Field(
        ...,
        description="Rwandan phone number to send the OTP to (07XXXXXXXX or +2507XXXXXXXX)",
        examples=["0781234567"],
    )

    @field_validator("phone_number")
    @classmethod
    def normalise(cls, v: str) -> str:
        return _normalise_phone(v)


class SendOtpResponse(BaseModel):
    """
    Response for a successful OTP dispatch.
    """
    message: str = Field(
        default="OTP sent successfully",
        description="Human-readable confirmation message",
    )


class VerifyOtpRequest(BaseModel):
    """
    Request body for POST /auth/verify-otp.
    """
    phone_number: str = Field(
        ...,
        description="Phone number the OTP was sent to",
        examples=["0781234567"],
    )
    otp_code: str = Field(
        ...,
        min_length=6,
        max_length=6,
        description="Six-digit OTP code received via SMS",
        examples=["482931"],
    )

    @field_validator("phone_number")
    @classmethod
    def normalise(cls, v: str) -> str:
        return _normalise_phone(v)


class VerifyOtpResponse(BaseModel):
    """
    Response containing the short-lived OTP verification token.

    This token must be included as *otp_token* in the subsequent
    /auth/register or /auth/login request to prove the caller owns
    the phone number.
    """
    otp_token: str = Field(
        ...,
        description=(
            "Short-lived JWT (expires in OTP_EXPIRE_MINUTES). "
            "Pass this as otp_token when calling /auth/register or /auth/login."
        ),
    )
    message: str = Field(default="Phone number verified successfully")
