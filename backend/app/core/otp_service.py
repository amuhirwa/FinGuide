"""
OTP Service
===========
Handles OTP generation, Twilio SMS delivery, verification, and token creation.

Flow:
  1. Call create_and_send_otp() → invalidates old codes, generates new 6-digit
     code, stores it in DB, sends via Twilio SMS.
  2. Call verify_otp_code()     → validates code against DB (not expired, not used),
     marks it used.
  3. Call create_otp_token()    → returns a short-lived JWT confirming the phone
     was OTP-verified.  Auth endpoints (register/login) call verify_otp_token()
     to prove the caller owns the phone before creating a session.
"""

import json
import random
from datetime import datetime, timedelta
from typing import Optional
import uuid
import requests
import os

from jose import JWTError, jwt
from twilio.rest import Client
from twilio.base.exceptions import TwilioRestException
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.otp import OTPCode

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _generate_code() -> str:
    """Return a cryptographically-adequate 6-digit numeric OTP."""
    return f"{random.SystemRandom().randint(0, 999999):06d}"


def _format_phone(phone_number: str) -> str:
    """
    Normalise a Rwandan number to E.164 for Twilio (+2507XXXXXXXX).

    Accepts: 07XXXXXXXX  |  2507XXXXXXXX  |  +2507XXXXXXXX
    """
    phone_number = phone_number.strip()
    if phone_number.startswith("+"):
        return phone_number
    if phone_number.startswith("250"):
        return "+" + phone_number
    if phone_number.startswith("07") or phone_number.startswith("07"):
        return "+250" + phone_number[1:]
    # Fallback – return as-is
    return phone_number


# ---------------------------------------------------------------------------
# Core public API
# ---------------------------------------------------------------------------

def create_and_send_otp(db: Session, phone_number: str) -> None:
    """
    Generate a fresh OTP for *phone_number*, persist it, and deliver via SMS.

    Any previous unused codes for the same number are invalidated first so
    only one valid OTP exists at a time.

    Raises:
        TwilioRestException: If the SMS could not be delivered.
    """
    # Invalidate all existing unused OTPs for this phone
    db.query(OTPCode).filter(
        OTPCode.phone_number == phone_number,
        OTPCode.is_used == False,
    ).update({"is_used": True})
    db.commit()

    # Create new OTP record
    code = _generate_code()
    expires_at = datetime.utcnow() + timedelta(minutes=settings.OTP_EXPIRE_MINUTES)
    otp_record = OTPCode(
        phone_number=phone_number,
        code=code,
        expires_at=expires_at,
    )
    db.add(otp_record)
    db.commit()

    # Deliver via Twilio
    _send_sms(phone_number, code)


def verify_otp_code(db: Session, phone_number: str, otp_code: str) -> bool:
    """
    Verify *otp_code* for *phone_number*.

    Returns True and marks the record as used if valid.
    Returns False for unknown, expired, or already-used codes.
    """
    record = db.query(OTPCode).filter(
        OTPCode.phone_number == phone_number,
        OTPCode.code == otp_code,
        OTPCode.is_used == False,
        OTPCode.expires_at > datetime.utcnow(),
    ).first()

    if not record:
        return False

    record.is_used = True
    db.commit()
    return True


def create_otp_token(phone_number: str) -> str:
    """
    Issue a short-lived JWT confirming *phone_number* passed OTP verification.

    The token expires after OTP_EXPIRE_MINUTES and carries type='otp_verified'
    so it cannot be confused with a regular access token.
    """
    expire = datetime.utcnow() + timedelta(minutes=settings.OTP_EXPIRE_MINUTES)
    payload = {
        "sub": phone_number,
        "exp": expire,
        "iat": datetime.utcnow(),
        "type": "otp_verified",
    }
    return jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


def verify_otp_token(token: str) -> str:
    """
    Decode an OTP verification token and return the phone number.

    Raises:
        ValueError: If the token is invalid, expired, or of the wrong type.
    """
    try:
        payload = jwt.decode(
            token,
            settings.SECRET_KEY,
            algorithms=[settings.ALGORITHM],
        )
        if payload.get("type") != "otp_verified":
            raise ValueError("Token type mismatch – expected otp_verified")
        phone: Optional[str] = payload.get("sub")
        if not phone:
            raise ValueError("Missing phone number in token")
        return phone
    except JWTError as exc:
        raise ValueError(f"Invalid or expired OTP token: {exc}") from exc


# ---------------------------------------------------------------------------
# Private
# ---------------------------------------------------------------------------

def _send_sms(phone_number: str, code: str) -> None:
    """Send the OTP SMS via Twilio."""
    login_payload = {
        "api_username": settings.SMS_USERNAME,
        "api_password": settings.SMS_PASSWORD
    }
    access_token = json.loads(requests.post(settings.SMS_AUTH, data=json.dumps(login_payload)).text)

    sms_payload = {
        "msisdn": _format_phone(phone_number),
        "message": f"Your FinGuide OTP is {code}. Valid for {settings.OTP_EXPIRE_MINUTES} minutes. Do not share this code with anyone.",
        "msgRef": str(uuid.uuid4()),
        "sender_id": "NLA"
    }

    send_sms = requests.post(settings.SMS_SEND, json.dumps(sms_payload), headers={"Authorization": "Bearer " + access_token["access_token"]})

    if send_sms.status_code != 200:
        raise TwilioRestException(send_sms.text)
