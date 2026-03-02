"""
Unit tests for app.core.otp_service
=====================================
Tests OTP generation, phone normalisation, token create/verify,
and database-backed verify_otp_code — with SMS delivery mocked out.
"""

import os
import pytest
from datetime import datetime, timedelta
from unittest.mock import patch, MagicMock

os.environ.setdefault("SMS_USERNAME", "test_user")
os.environ.setdefault("SMS_PASSWORD", "test_pass")
os.environ.setdefault("SMS_AUTH", "http://localhost/auth")
os.environ.setdefault("SMS_SEND", "http://localhost/send")

from app.core.otp_service import (
    _generate_code,
    _format_phone,
    create_otp_token,
    verify_otp_token,
    verify_otp_code,
    create_and_send_otp,
)
from app.models.otp import OTPCode

pytestmark = pytest.mark.unit


# ──────────────────────────────────────────────────────────────────────────────
# _generate_code
# ──────────────────────────────────────────────────────────────────────────────

class TestGenerateCode:
    def test_returns_string(self):
        assert isinstance(_generate_code(), str)

    def test_exactly_six_digits(self):
        code = _generate_code()
        assert len(code) == 6
        assert code.isdigit()

    def test_leading_zeros_preserved(self):
        # Run many times to hit a code starting with 0
        codes = [_generate_code() for _ in range(200)]
        assert all(len(c) == 6 for c in codes)

    def test_codes_are_different(self):
        codes = {_generate_code() for _ in range(20)}
        # Very unlikely to get the same code 20 times in a row
        assert len(codes) > 1


# ──────────────────────────────────────────────────────────────────────────────
# _format_phone
# ──────────────────────────────────────────────────────────────────────────────

class TestFormatPhone:
    def test_07_prefix_to_e164(self):
        assert _format_phone("0781234567") == "+250781234567"

    def test_250_prefix_to_e164(self):
        assert _format_phone("250781234567") == "+250781234567"

    def test_already_e164_unchanged(self):
        assert _format_phone("+250781234567") == "+250781234567"

    def test_strips_whitespace(self):
        assert _format_phone("  0781234567  ") == "+250781234567"

    def test_fallback_returns_as_is(self):
        # Unknown format — returned as-is
        result = _format_phone("12345")
        assert result == "12345"


# ──────────────────────────────────────────────────────────────────────────────
# OTP JWT token
# ──────────────────────────────────────────────────────────────────────────────

class TestOtpToken:
    def test_create_token_returns_string(self):
        token = create_otp_token("0781234567")
        assert isinstance(token, str)
        assert len(token) > 0

    def test_verify_returns_phone_number(self):
        phone = "0781234567"
        token = create_otp_token(phone)
        result = verify_otp_token(token)
        assert result == phone

    def test_expired_token_raises_value_error(self):
        from app.core import config
        with patch.object(config.settings, "OTP_EXPIRE_MINUTES", -1):
            token = create_otp_token("0781111111")
        with pytest.raises(ValueError, match="Invalid or expired"):
            verify_otp_token(token)

    def test_invalid_token_raises_value_error(self):
        with pytest.raises(ValueError):
            verify_otp_token("this.is.not.a.valid.token")

    def test_wrong_token_type_raises_value_error(self):
        from app.core.security import create_access_token
        # A regular access token should be rejected
        access_token = create_access_token(subject="1")
        with pytest.raises(ValueError, match="Token type mismatch"):
            verify_otp_token(access_token)


# ──────────────────────────────────────────────────────────────────────────────
# verify_otp_code (requires DB fixture from conftest)
# ──────────────────────────────────────────────────────────────────────────────

class TestVerifyOtpCode:
    def _seed_otp(self, db, phone: str, code: str, minutes: int = 5, used: bool = False):
        record = OTPCode(
            phone_number=phone,
            code=code,
            expires_at=datetime.utcnow() + timedelta(minutes=minutes),
            is_used=used,
        )
        db.add(record)
        db.commit()
        return record

    def test_valid_code_returns_true(self, db):
        self._seed_otp(db, "0781000001", "123456")
        assert verify_otp_code(db, "0781000001", "123456") is True

    def test_valid_code_marked_as_used(self, db):
        self._seed_otp(db, "0781000002", "654321")
        verify_otp_code(db, "0781000002", "654321")
        record = db.query(OTPCode).filter(OTPCode.phone_number == "0781000002").first()
        assert record.is_used is True

    def test_wrong_code_returns_false(self, db):
        self._seed_otp(db, "0781000003", "111111")
        assert verify_otp_code(db, "0781000003", "999999") is False

    def test_expired_code_returns_false(self, db):
        self._seed_otp(db, "0781000004", "222222", minutes=-1)
        assert verify_otp_code(db, "0781000004", "222222") is False

    def test_already_used_code_returns_false(self, db):
        self._seed_otp(db, "0781000005", "333333", used=True)
        assert verify_otp_code(db, "0781000005", "333333") is False

    def test_unknown_phone_returns_false(self, db):
        assert verify_otp_code(db, "0781999999", "123456") is False

    def test_code_for_different_phone_returns_false(self, db):
        self._seed_otp(db, "0781000006", "444444")
        assert verify_otp_code(db, "0781999888", "444444") is False


# ──────────────────────────────────────────────────────────────────────────────
# create_and_send_otp (SMS delivery mocked)
# ──────────────────────────────────────────────────────────────────────────────

class TestCreateAndSendOtp:
    @patch("app.core.otp_service._send_sms")
    def test_otp_record_persisted(self, mock_send, db):
        create_and_send_otp(db, "0781000010")
        record = db.query(OTPCode).filter(
            OTPCode.phone_number == "0781000010",
            OTPCode.is_used == False,
        ).first()
        assert record is not None
        assert len(record.code) == 6

    @patch("app.core.otp_service._send_sms")
    def test_previous_otp_invalidated(self, mock_send, db):
        # Seed an old OTP
        old = OTPCode(
            phone_number="0781000011",
            code="000000",
            expires_at=datetime.utcnow() + timedelta(minutes=5),
            is_used=False,
        )
        db.add(old)
        db.commit()

        create_and_send_otp(db, "0781000011")

        old_record = db.query(OTPCode).filter(
            OTPCode.phone_number == "0781000011",
            OTPCode.code == "000000",
        ).first()
        assert old_record.is_used is True

    @patch("app.core.otp_service._send_sms")
    def test_sms_send_called_once(self, mock_send, db):
        create_and_send_otp(db, "0781000012")
        mock_send.assert_called_once()
