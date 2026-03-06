"""
Integration tests for /api/v1/transactions endpoints.
=======================================================
Uses the FastAPI TestClient with an in-memory SQLite DB.
The income nudge background task is mocked to keep tests fast.
"""

import os
import pytest
from unittest.mock import patch

os.environ.setdefault("SMS_USERNAME", "test_user")
os.environ.setdefault("SMS_PASSWORD", "test_pass")
os.environ.setdefault("SMS_AUTH", "http://localhost/auth")
os.environ.setdefault("SMS_SEND", "http://localhost/send")

pytestmark = pytest.mark.integration

BASE = "/api/v1/transactions"


# ──────────────────────────────────────────────────────────────────────────────
# Auth guard
# ──────────────────────────────────────────────────────────────────────────────

class TestAuthGuard:
    def test_unauthenticated_list_returns_401(self, client):
        resp = client.get(BASE)
        assert resp.status_code == 401

    def test_unauthenticated_parse_sms_returns_401(self, client):
        resp = client.post(f"{BASE}/parse-sms", json={"messages": ["test"]})
        assert resp.status_code == 401


# ──────────────────────────────────────────────────────────────────────────────
# GET /transactions
# ──────────────────────────────────────────────────────────────────────────────

class TestListTransactions:
    def test_authenticated_returns_200(self, client, auth_headers):
        resp = client.get(BASE, headers=auth_headers)
        assert resp.status_code == 200

    def test_returns_list(self, client, auth_headers):
        resp = client.get(BASE, headers=auth_headers)
        data = resp.json()
        assert "transactions" in data
        assert isinstance(data["transactions"], list)

    def test_empty_for_new_user(self, client, auth_headers):
        resp = client.get(BASE, headers=auth_headers)
        assert resp.json()["transactions"] == []

    def test_seeded_transaction_appears(
        self, client, auth_headers, sample_income_transaction
    ):
        resp = client.get(BASE, headers=auth_headers)
        ids = [t["id"] for t in resp.json()["transactions"]]
        assert sample_income_transaction.id in ids

    def test_pagination_limit_respected(self, client, auth_headers, db, test_user):
        from app.models.transaction import Transaction, TransactionType, TransactionCategory, NeedWantCategory
        from datetime import datetime
        for i in range(5):
            db.add(Transaction(
                user_id=test_user.id,
                transaction_type=TransactionType.EXPENSE,
                category=TransactionCategory.OTHER,
                need_want=NeedWantCategory.UNCATEGORIZED,
                amount=100.0,
                transaction_date=datetime.now(),
                confidence_score=0.5,
                is_verified=False,
            ))
        db.commit()

        resp = client.get(f"{BASE}?page_size=3", headers=auth_headers)
        assert len(resp.json()["transactions"]) <= 3


# ──────────────────────────────────────────────────────────────────────────────
# GET /transactions/summary
# ──────────────────────────────────────────────────────────────────────────────

class TestTransactionSummary:
    def test_summary_authenticated_returns_200(self, client, auth_headers):
        resp = client.get(f"{BASE}/summary", headers=auth_headers)
        assert resp.status_code == 200

    def test_summary_includes_totals(self, client, auth_headers, sample_income_transaction):
        resp = client.get(f"{BASE}/summary", headers=auth_headers)
        data = resp.json()
        assert "total_income" in data
        assert "total_expenses" in data
        assert "net_flow" in data

    def test_income_counted_correctly(
        self, client, auth_headers, sample_income_transaction
    ):
        resp = client.get(f"{BASE}/summary", headers=auth_headers)
        assert resp.json()["total_income"] == sample_income_transaction.amount


# ──────────────────────────────────────────────────────────────────────────────
# POST /transactions/parse-sms
# ──────────────────────────────────────────────────────────────────────────────

class TestParseSms:
    INCOME_SMS = (
        "You have received 20,000 RWF from MUTONI BRICE (*********726) "
        "at 2024-11-15 10:23:45. Balance: 250,000 RWF."
    )
    TRANSFER_SMS = (
        "1,500 RWF transferred to Juldas NYIRISHEMA (250788217896) "
        "at 2024-11-16 14:05:00. Balance: 48,500 RWF."
    )
    JUNK_SMS = "Your MTN bundle expires in 2 days."

    @patch("app.api.v1.endpoints.transactions._trigger_income_nudge")
    def test_parse_income_sms_success(self, mock_nudge, client, auth_headers):
        resp = client.post(
            f"{BASE}/parse-sms",
            json={"messages": [self.INCOME_SMS]},
            headers=auth_headers,
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["parsed_count"] == 1
        assert data["failed_count"] == 0

    @patch("app.api.v1.endpoints.transactions._trigger_income_nudge")
    def test_parsed_transaction_has_correct_type(self, mock_nudge, client, auth_headers):
        resp = client.post(
            f"{BASE}/parse-sms",
            json={"messages": [self.INCOME_SMS]},
            headers=auth_headers,
        )
        tx = resp.json()["transactions"][0]
        assert tx["transaction_type"] == "income"
        assert tx["amount"] == 20000.0

    @patch("app.api.v1.endpoints.transactions._trigger_income_nudge")
    def test_parsed_transfer_sms(self, mock_nudge, client, auth_headers):
        resp = client.post(
            f"{BASE}/parse-sms",
            json={"messages": [self.TRANSFER_SMS]},
            headers=auth_headers,
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["parsed_count"] == 1
        tx = data["transactions"][0]
        assert tx["transaction_type"] == "expense"

    @patch("app.api.v1.endpoints.transactions._trigger_income_nudge")
    def test_unparseable_sms_counted_as_failed(self, mock_nudge, client, auth_headers):
        resp = client.post(
            f"{BASE}/parse-sms",
            json={"messages": [self.JUNK_SMS]},
            headers=auth_headers,
        )
        data = resp.json()
        assert data["parsed_count"] == 0
        assert data["failed_count"] == 1

    @patch("app.api.v1.endpoints.transactions._trigger_income_nudge")
    def test_mixed_batch(self, mock_nudge, client, auth_headers):
        resp = client.post(
            f"{BASE}/parse-sms",
            json={"messages": [self.INCOME_SMS, self.TRANSFER_SMS, self.JUNK_SMS]},
            headers=auth_headers,
        )
        data = resp.json()
        assert data["parsed_count"] == 2
        assert data["failed_count"] == 1

    @patch("app.api.v1.endpoints.transactions._trigger_income_nudge")
    def test_duplicate_sms_skipped(self, mock_nudge, client, auth_headers):
        resp1 = client.post(
            f"{BASE}/parse-sms",
            json={"messages": [self.INCOME_SMS]},
            headers=auth_headers,
        )
        resp2 = client.post(
            f"{BASE}/parse-sms",
            json={"messages": [self.INCOME_SMS]},
            headers=auth_headers,
        )
        assert resp1.json()["parsed_count"] == 1
        assert resp2.json()["parsed_count"] == 0  # duplicate skipped

    @patch("app.api.v1.endpoints.transactions._trigger_income_nudge")
    def test_income_triggers_background_nudge(self, mock_nudge, client, auth_headers):
        client.post(
            f"{BASE}/parse-sms",
            json={"messages": [self.INCOME_SMS]},
            headers=auth_headers,
        )
        # Background task was scheduled (TestClient runs tasks synchronously)
        mock_nudge.assert_called_once()

    @patch("app.api.v1.endpoints.transactions._trigger_income_nudge")
    def test_empty_list_succeeds(self, mock_nudge, client, auth_headers):
        resp = client.post(
            f"{BASE}/parse-sms", json={"messages": []}, headers=auth_headers
        )
        assert resp.status_code == 200
        assert resp.json()["parsed_count"] == 0


# ──────────────────────────────────────────────────────────────────────────────
# DELETE /transactions/{id}
# ──────────────────────────────────────────────────────────────────────────────

class TestDeleteTransaction:
    def test_delete_own_transaction(
        self, client, auth_headers, sample_income_transaction
    ):
        resp = client.delete(
            f"{BASE}/{sample_income_transaction.id}", headers=auth_headers
        )
        assert resp.status_code in (200, 204)

    def test_cannot_delete_other_users_transaction(
        self, client, auth_headers, db
    ):
        from app.models.user import User, UbudheCategory, IncomeFrequency
        from app.models.transaction import Transaction, TransactionType, TransactionCategory, NeedWantCategory
        from app.core.security import get_password_hash
        from datetime import datetime

        other_user = User(
            phone_number="0781999001",
            full_name="Other User",
            hashed_password=get_password_hash("pw"),
            ubudehe_category=UbudheCategory.CATEGORY_1,
            income_frequency=IncomeFrequency.MONTHLY,
            is_active=True, is_verified=True,
        )
        db.add(other_user)
        db.commit()
        db.refresh(other_user)

        other_tx = Transaction(
            user_id=other_user.id,
            transaction_type=TransactionType.EXPENSE,
            category=TransactionCategory.OTHER,
            need_want=NeedWantCategory.UNCATEGORIZED,
            amount=500.0,
            transaction_date=datetime.now(),
            confidence_score=0.5,
            is_verified=False,
        )
        db.add(other_tx)
        db.commit()

        resp = client.delete(f"{BASE}/{other_tx.id}", headers=auth_headers)
        assert resp.status_code == 404

    def test_delete_nonexistent_transaction(self, client, auth_headers):
        resp = client.delete(f"{BASE}/999999", headers=auth_headers)
        assert resp.status_code == 404
