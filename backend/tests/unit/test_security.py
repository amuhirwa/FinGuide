"""
Unit tests for app.core.security
==================================
Tests password hashing, JWT creation, and JWT decoding without touching
the database.
"""

import os
import pytest
from datetime import timedelta

os.environ.setdefault("SMS_USERNAME", "test_user")
os.environ.setdefault("SMS_PASSWORD", "test_pass")
os.environ.setdefault("SMS_AUTH", "http://localhost/auth")
os.environ.setdefault("SMS_SEND", "http://localhost/send")

from app.core.security import (
    verify_password,
    get_password_hash,
    create_access_token,
    decode_token,
)

pytestmark = pytest.mark.unit


# ──────────────────────────────────────────────────────────────────────────────
# Password hashing
# ──────────────────────────────────────────────────────────────────────────────

class TestPasswordHashing:
    def test_hash_is_different_from_plain(self):
        hashed = get_password_hash("secret123")
        assert hashed != "secret123"

    def test_correct_password_verifies(self):
        hashed = get_password_hash("correct_password")
        assert verify_password("correct_password", hashed) is True

    def test_wrong_password_fails(self):
        hashed = get_password_hash("correct_password")
        assert verify_password("wrong_password", hashed) is False

    def test_same_password_produces_different_hashes(self):
        # bcrypt generates a salt each time
        h1 = get_password_hash("same_password")
        h2 = get_password_hash("same_password")
        assert h1 != h2
        # But both should verify
        assert verify_password("same_password", h1)
        assert verify_password("same_password", h2)

    def test_empty_password_can_be_hashed_and_verified(self):
        hashed = get_password_hash("")
        assert verify_password("", hashed) is True

    def test_unicode_password(self):
        hashed = get_password_hash("Kigali2024🔑")
        assert verify_password("Kigali2024🔑", hashed) is True


# ──────────────────────────────────────────────────────────────────────────────
# Token creation
# ──────────────────────────────────────────────────────────────────────────────

class TestCreateAccessToken:
    def test_returns_string(self):
        token = create_access_token(subject="42")
        assert isinstance(token, str)
        assert len(token) > 0

    def test_token_is_decodeable(self):
        token = create_access_token(subject="99")
        payload = decode_token(token)
        assert payload is not None

    def test_subject_stored_as_string(self):
        token = create_access_token(subject=7)
        payload = decode_token(token)
        assert payload["sub"] == "7"

    def test_token_type_is_access(self):
        token = create_access_token(subject="1")
        payload = decode_token(token)
        assert payload["type"] == "access"

    def test_custom_expiry_respected(self):
        # 1-hour token
        token = create_access_token(subject="1", expires_delta=timedelta(hours=1))
        payload = decode_token(token)
        assert payload is not None

    def test_expired_token_returns_none(self):
        token = create_access_token(subject="1", expires_delta=timedelta(seconds=-1))
        payload = decode_token(token)
        assert payload is None

    def test_string_and_int_subject_equivalent(self):
        t1 = create_access_token(subject="5")
        t2 = create_access_token(subject=5)
        p1 = decode_token(t1)
        p2 = decode_token(t2)
        assert p1["sub"] == p2["sub"] == "5"


# ──────────────────────────────────────────────────────────────────────────────
# Token decoding
# ──────────────────────────────────────────────────────────────────────────────

class TestDecodeToken:
    def test_valid_token_decoded(self):
        token = create_access_token(subject="123")
        payload = decode_token(token)
        assert payload is not None
        assert payload["sub"] == "123"

    def test_invalid_token_returns_none(self):
        assert decode_token("not.a.valid.token") is None

    def test_empty_string_returns_none(self):
        assert decode_token("") is None

    def test_tampered_token_returns_none(self):
        token = create_access_token(subject="1")
        # Flip one character in the signature
        tampered = token[:-1] + ("X" if token[-1] != "X" else "Y")
        assert decode_token(tampered) is None

    def test_iat_claim_present(self):
        token = create_access_token(subject="1")
        payload = decode_token(token)
        assert "iat" in payload

    def test_exp_claim_present(self):
        token = create_access_token(subject="1")
        payload = decode_token(token)
        assert "exp" in payload
