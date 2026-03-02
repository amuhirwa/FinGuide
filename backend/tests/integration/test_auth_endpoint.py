"""
Integration tests for /auth endpoints.

Flow:
  POST /auth/send-otp   → 200 (Twilio mocked)
  POST /auth/verify-otp → 200 + otp_token (OTPCode row created in DB)
  POST /auth/register   → 201 + access_token
  POST /auth/login      → 200 + access_token
"""

import pytest
from datetime import datetime, timedelta
from unittest.mock import patch, MagicMock

from twilio.base.exceptions import TwilioRestException

from app.models.otp import OTPCode
from app.core.otp_service import create_otp_token
from app.core.security import get_password_hash


SEND_OTP_URL = "/api/v1/auth/send-otp"
VERIFY_OTP_URL = "/api/v1/auth/verify-otp"
REGISTER_URL = "/api/v1/auth/register"
LOGIN_URL = "/api/v1/auth/login"

NEW_PHONE = "+250781111222"
NEW_PHONE_LOCAL = "0781111222"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_otp(db, phone: str = NEW_PHONE, code: str = "123456", used: bool = False):
    """Insert an OTPCode row and return it."""
    record = OTPCode(
        phone_number=phone,
        code=code,
        expires_at=datetime.utcnow() + timedelta(minutes=5),
        is_used=used,
    )
    db.add(record)
    db.commit()
    db.refresh(record)
    return record


# ---------------------------------------------------------------------------
# TestSendOtp
# ---------------------------------------------------------------------------

class TestSendOtp:
    """POST /auth/send-otp"""

    def test_success_returns_200_message(self, client):
        with patch("app.api.v1.endpoints.auth.create_and_send_otp") as mock_send:
            mock_send.return_value = None
            resp = client.post(SEND_OTP_URL, json={"phone_number": NEW_PHONE})

        assert resp.status_code == 200
        assert "OTP sent" in resp.json()["message"]
        mock_send.assert_called_once_with(mock_send.call_args.args[0], NEW_PHONE)

    def test_twilio_error_returns_503(self, client):
        exc = TwilioRestException(
            status=400,
            uri="/Accounts/x/Messages.json",
            msg="Invalid phone number",
            method="POST",
            code=21211,
        )
        with patch("app.api.v1.endpoints.auth.create_and_send_otp", side_effect=exc):
            resp = client.post(SEND_OTP_URL, json={"phone_number": NEW_PHONE})

        assert resp.status_code == 503
        assert "Could not send OTP" in resp.json()["detail"]

    def test_unexpected_error_returns_503(self, client):
        with patch(
            "app.api.v1.endpoints.auth.create_and_send_otp",
            side_effect=RuntimeError("Network error"),
        ):
            resp = client.post(SEND_OTP_URL, json={"phone_number": NEW_PHONE})

        assert resp.status_code == 503
        assert "SMS delivery failed" in resp.json()["detail"]


# ---------------------------------------------------------------------------
# TestVerifyOtp
# ---------------------------------------------------------------------------

class TestVerifyOtp:
    """POST /auth/verify-otp"""

    def test_valid_code_returns_otp_token(self, client, db):
        _make_otp(db, phone=NEW_PHONE, code="654321")
        resp = client.post(
            VERIFY_OTP_URL,
            json={"phone_number": NEW_PHONE, "otp_code": "654321"},
        )
        assert resp.status_code == 200
        body = resp.json()
        assert "otp_token" in body
        assert body["otp_token"]  # non-empty JWT
        assert "verified" in body["message"].lower()

    def test_wrong_code_returns_400(self, client, db):
        _make_otp(db, phone=NEW_PHONE, code="000000")
        resp = client.post(
            VERIFY_OTP_URL,
            json={"phone_number": NEW_PHONE, "otp_code": "999999"},
        )
        assert resp.status_code == 400
        assert "Invalid" in resp.json()["detail"]

    def test_already_used_code_returns_400(self, client, db):
        _make_otp(db, phone=NEW_PHONE, code="111111", used=True)
        resp = client.post(
            VERIFY_OTP_URL,
            json={"phone_number": NEW_PHONE, "otp_code": "111111"},
        )
        assert resp.status_code == 400

    def test_expired_code_returns_400(self, client, db):
        record = OTPCode(
            phone_number=NEW_PHONE,
            code="222222",
            expires_at=datetime.utcnow() - timedelta(minutes=1),  # already expired
            is_used=False,
        )
        db.add(record)
        db.commit()
        resp = client.post(
            VERIFY_OTP_URL,
            json={"phone_number": NEW_PHONE, "otp_code": "222222"},
        )
        assert resp.status_code == 400


# ---------------------------------------------------------------------------
# TestRegister
# ---------------------------------------------------------------------------

class TestRegister:
    """POST /auth/register"""

    def _payload(self, phone=NEW_PHONE, otp_token=None):
        otp_token = otp_token or create_otp_token(phone)
        return {
            "phone_number": phone,
            "full_name": "New User",
            "password": "Secure123!",
            "ubudehe_category": "category_2",
            "income_frequency": "monthly",
            "otp_token": otp_token,
        }

    def test_happy_path_creates_user_and_returns_token(self, client, db):
        resp = client.post(REGISTER_URL, json=self._payload())
        assert resp.status_code == 201
        body = resp.json()
        assert "access_token" in body
        assert body["token_type"] == "bearer"
        assert body["user"]["phone_number"] == NEW_PHONE

    def test_phone_mismatch_returns_400(self, client):
        otp_token = create_otp_token("+250781999999")  # different phone
        resp = client.post(REGISTER_URL, json=self._payload(otp_token=otp_token))
        assert resp.status_code == 400
        assert "mismatch" in resp.json()["detail"].lower() or "does not match" in resp.json()["detail"].lower()

    def test_tampered_token_returns_400(self, client):
        payload = self._payload()
        payload["otp_token"] = "not.a.valid.jwt"
        resp = client.post(REGISTER_URL, json=payload)
        assert resp.status_code == 400

    def test_duplicate_phone_returns_400(self, client, test_user):
        # test_user already has phone "0781234567" → normalised to +250781234567 or "0781234567"
        otp_token = create_otp_token(test_user.phone_number)
        payload = {
            "phone_number": test_user.phone_number,
            "full_name": "Dupe",
            "password": "Pass123!",
            "ubudehe_category": "category_1",
            "income_frequency": "monthly",
            "otp_token": otp_token,
        }
        resp = client.post(REGISTER_URL, json=payload)
        assert resp.status_code == 400
        assert "already registered" in resp.json()["detail"].lower()


# ---------------------------------------------------------------------------
# TestLogin
# ---------------------------------------------------------------------------

class TestLogin:
    """POST /auth/login"""

    def _payload(self, user, password="password123", otp_token=None):
        otp_token = otp_token or create_otp_token(user.phone_number)
        return {
            "phone_number": user.phone_number,
            "password": password,
            "otp_token": otp_token,
        }

    def test_valid_credentials_returns_token(self, client, test_user):
        resp = client.post(LOGIN_URL, json=self._payload(test_user))
        assert resp.status_code == 200
        body = resp.json()
        assert "access_token" in body
        assert body["user"]["phone_number"] == test_user.phone_number

    def test_wrong_password_returns_401(self, client, test_user):
        resp = client.post(LOGIN_URL, json=self._payload(test_user, password="wrongpass"))
        assert resp.status_code == 401
        assert "Invalid" in resp.json()["detail"]

    def test_unknown_phone_returns_401(self, client, test_user):
        otp_token = create_otp_token("+250781000000")
        resp = client.post(
            LOGIN_URL,
            json={
                "phone_number": "+250781000000",
                "password": "password123",
                "otp_token": otp_token,
            },
        )
        assert resp.status_code == 401

    def test_phone_mismatch_in_token_returns_400(self, client, test_user):
        otp_token = create_otp_token("+250781999999")
        payload = self._payload(test_user, otp_token=otp_token)
        resp = client.post(LOGIN_URL, json=payload)
        assert resp.status_code == 400

    def test_tampered_token_returns_400(self, client, test_user):
        payload = self._payload(test_user)
        payload["otp_token"] = "bad.token.here"
        resp = client.post(LOGIN_URL, json=payload)
        assert resp.status_code == 400

    def test_deactivated_account_returns_403(self, client, db, test_user):
        test_user.is_active = False
        db.commit()
        resp = client.post(LOGIN_URL, json=self._payload(test_user))
        assert resp.status_code == 403
        assert "deactivated" in resp.json()["detail"].lower()
