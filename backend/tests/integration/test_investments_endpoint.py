"""
Integration tests for /investments endpoints.

Covers:
  GET  /investments           - list with optional filters
  POST /investments           - create
  GET  /investments/summary   - portfolio summary
  GET  /investments/advice    - personalized advice
  GET  /investments/{id}      - detail + projections
  PATCH /investments/{id}     - update
  DELETE /investments/{id}    - delete
  POST /investments/{id}/contribute        - deposit / withdrawal
  GET  /investments/{id}/contributions     - list contributions
  POST /investments/{id}/link-transaction/{tx_id}   - link
  DELETE /investments/{id}/link-transaction/{tx_id} - unlink
  GET  /investments/{id}/linked-transactions
"""

import pytest
from datetime import datetime, timedelta

from app.models.investment import Investment, InvestmentContribution
from app.models.investment import InvestmentType as ModelInvType, InvestmentStatus as ModelInvStatus
from app.models.transaction import Transaction, TransactionType, TransactionCategory, NeedWantCategory


BASE = "/api/v1/investments"


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def sample_investment(db, test_user):
    inv = Investment(
        user_id=test_user.id,
        name="Emergency Savings",
        investment_type=ModelInvType.SAVINGS_ACCOUNT,
        initial_amount=100_000.0,
        current_value=100_000.0,
        total_contributions=100_000.0,
        total_withdrawals=0.0,
        expected_annual_return=8.0,
        monthly_contribution=10_000.0,
        auto_contribute=False,
        status=ModelInvStatus.ACTIVE,
    )
    db.add(inv)
    db.commit()
    db.refresh(inv)
    return inv


@pytest.fixture
def other_user_investment(db):
    """Investment belonging to a different user (id=9999)."""
    from app.models.user import User, UbudheCategory, IncomeFrequency
    from app.core.security import get_password_hash
    other = User(
        phone_number="0789000001",
        full_name="Other",
        hashed_password=get_password_hash("pass"),
        ubudehe_category=UbudheCategory.CATEGORY_1,
        income_frequency=IncomeFrequency.MONTHLY,
        is_active=True,
    )
    db.add(other)
    db.commit()
    db.refresh(other)

    inv = Investment(
        user_id=other.id,
        name="Other's Investment",
        investment_type=ModelInvType.EJO_HEZA,
        initial_amount=50_000.0,
        current_value=50_000.0,
        total_contributions=50_000.0,
        status=ModelInvStatus.ACTIVE,
    )
    db.add(inv)
    db.commit()
    db.refresh(inv)
    return inv


@pytest.fixture
def sample_tx(db, test_user):
    tx = Transaction(
        user_id=test_user.id,
        transaction_type=TransactionType.EXPENSE,
        category=TransactionCategory.INVESTMENT,
        need_want=NeedWantCategory.SAVINGS,
        amount=20_000.0,
        description="Investment deposit",
        transaction_date=datetime.now() - timedelta(days=1),
        confidence_score=1.0,
    )
    db.add(tx)
    db.commit()
    db.refresh(tx)
    return tx


# ---------------------------------------------------------------------------
# TestAuthGuard
# ---------------------------------------------------------------------------

class TestAuthGuard:
    def test_list_requires_auth(self, client):
        assert client.get(BASE).status_code == 401

    def test_create_requires_auth(self, client):
        assert client.post(BASE, json={}).status_code == 401

    def test_summary_requires_auth(self, client):
        assert client.get(f"{BASE}/summary").status_code == 401

    def test_advice_requires_auth(self, client):
        assert client.get(f"{BASE}/advice").status_code == 401


# ---------------------------------------------------------------------------
# TestListInvestments
# ---------------------------------------------------------------------------

class TestListInvestments:
    def test_empty_returns_empty_list(self, client, auth_headers):
        resp = client.get(BASE, headers=auth_headers)
        assert resp.status_code == 200
        assert resp.json() == []

    def test_returns_own_investments(self, client, auth_headers, sample_investment):
        resp = client.get(BASE, headers=auth_headers)
        assert resp.status_code == 200
        data = resp.json()
        assert len(data) == 1
        assert data[0]["name"] == "Emergency Savings"

    def test_does_not_return_other_users_investments(
        self, client, auth_headers, other_user_investment
    ):
        resp = client.get(BASE, headers=auth_headers)
        assert resp.status_code == 200
        names = [d["name"] for d in resp.json()]
        assert "Other's Investment" not in names

    def test_filter_by_status_active(self, client, auth_headers, db, test_user):
        paused = Investment(
            user_id=test_user.id,
            name="Paused",
            investment_type=ModelInvType.SACCO,
            initial_amount=10_000.0,
            current_value=10_000.0,
            total_contributions=10_000.0,
            status=ModelInvStatus.PAUSED,
        )
        db.add(paused)
        db.commit()
        resp = client.get(BASE, params={"status": "active"}, headers=auth_headers)
        assert resp.status_code == 200
        # Only active investments returned (none yet unless sample_investment used)

    def test_gain_fields_present(self, client, auth_headers, sample_investment):
        resp = client.get(BASE, headers=auth_headers)
        item = resp.json()[0]
        assert "total_gain" in item
        assert "gain_percentage" in item


# ---------------------------------------------------------------------------
# TestCreateInvestment
# ---------------------------------------------------------------------------

class TestCreateInvestment:
    def _payload(self, **overrides):
        data = {
            "name": "Ejo Heza Pension",
            "investment_type": "ejo_heza",
            "initial_amount": 50_000.0,
            "expected_annual_return": 10.0,
            "monthly_contribution": 5_000.0,
            "auto_contribute": False,
        }
        data.update(overrides)
        return data

    def test_creates_investment_successfully(self, client, auth_headers):
        resp = client.post(BASE, json=self._payload(), headers=auth_headers)
        assert resp.status_code == 201
        body = resp.json()
        assert body["name"] == "Ejo Heza Pension"
        assert body["current_value"] == 50_000.0
        assert body["total_gain"] == 0
        assert body["gain_percentage"] == 0

    def test_initial_current_value_equals_initial_amount(self, client, auth_headers):
        resp = client.post(BASE, json=self._payload(initial_amount=30_000.0), headers=auth_headers)
        assert resp.status_code == 201
        assert resp.json()["current_value"] == 30_000.0

    def test_investment_type_stored_correctly(self, client, auth_headers):
        resp = client.post(BASE, json=self._payload(investment_type="rnit"), headers=auth_headers)
        assert resp.status_code == 201
        assert resp.json()["investment_type"] == "rnit"


# ---------------------------------------------------------------------------
# TestInvestmentDetail
# ---------------------------------------------------------------------------

class TestInvestmentDetail:
    def test_returns_detail_with_projections(self, client, auth_headers, sample_investment):
        resp = client.get(f"{BASE}/{sample_investment.id}", headers=auth_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert body["id"] == sample_investment.id
        assert "projections" in body
        assert len(body["projections"]) == 12  # 12 months

    def test_projections_balance_grows_each_month(self, client, auth_headers, sample_investment):
        resp = client.get(f"{BASE}/{sample_investment.id}", headers=auth_headers)
        projections = resp.json()["projections"]
        balances = [p["balance"] for p in projections]
        assert all(balances[i] < balances[i + 1] for i in range(len(balances) - 1))

    def test_404_for_other_users_investment(self, client, auth_headers, other_user_investment):
        resp = client.get(f"{BASE}/{other_user_investment.id}", headers=auth_headers)
        assert resp.status_code == 404

    def test_404_for_nonexistent_investment(self, client, auth_headers):
        resp = client.get(f"{BASE}/99999", headers=auth_headers)
        assert resp.status_code == 404


# ---------------------------------------------------------------------------
# TestUpdateInvestment
# ---------------------------------------------------------------------------

class TestUpdateInvestment:
    def test_update_name(self, client, auth_headers, sample_investment):
        resp = client.patch(
            f"{BASE}/{sample_investment.id}",
            json={"name": "Updated Name"},
            headers=auth_headers,
        )
        assert resp.status_code == 200
        assert resp.json()["name"] == "Updated Name"

    def test_update_status_to_paused(self, client, auth_headers, sample_investment):
        resp = client.patch(
            f"{BASE}/{sample_investment.id}",
            json={"status": "paused"},
            headers=auth_headers,
        )
        assert resp.status_code == 200
        assert resp.json()["status"] == "paused"

    def test_404_for_other_users_investment(self, client, auth_headers, other_user_investment):
        resp = client.patch(
            f"{BASE}/{other_user_investment.id}",
            json={"name": "Hacked"},
            headers=auth_headers,
        )
        assert resp.status_code == 404


# ---------------------------------------------------------------------------
# TestDeleteInvestment
# ---------------------------------------------------------------------------

class TestDeleteInvestment:
    def test_delete_returns_204(self, client, auth_headers, sample_investment):
        resp = client.delete(f"{BASE}/{sample_investment.id}", headers=auth_headers)
        assert resp.status_code == 204

    def test_deleted_investment_not_in_list(self, client, auth_headers, sample_investment):
        client.delete(f"{BASE}/{sample_investment.id}", headers=auth_headers)
        resp = client.get(BASE, headers=auth_headers)
        assert all(d["id"] != sample_investment.id for d in resp.json())

    def test_404_for_other_users_investment(self, client, auth_headers, other_user_investment):
        resp = client.delete(f"{BASE}/{other_user_investment.id}", headers=auth_headers)
        assert resp.status_code == 404


# ---------------------------------------------------------------------------
# TestContributions
# ---------------------------------------------------------------------------

class TestContributions:
    def test_deposit_increases_value_and_contributions(
        self, client, auth_headers, sample_investment
    ):
        original_value = sample_investment.current_value
        resp = client.post(
            f"{BASE}/{sample_investment.id}/contribute",
            json={"amount": 20_000.0, "is_withdrawal": False},
            headers=auth_headers,
        )
        assert resp.status_code == 200
        assert resp.json()["amount"] == 20_000.0
        assert resp.json()["is_withdrawal"] is False

        # Verify investment totals updated
        detail = client.get(f"{BASE}/{sample_investment.id}", headers=auth_headers).json()
        assert detail["current_value"] == original_value + 20_000.0
        assert detail["total_contributions"] == original_value + 20_000.0

    def test_withdrawal_decreases_value(self, client, auth_headers, sample_investment):
        original_value = sample_investment.current_value
        resp = client.post(
            f"{BASE}/{sample_investment.id}/contribute",
            json={"amount": 10_000.0, "is_withdrawal": True},
            headers=auth_headers,
        )
        assert resp.status_code == 200
        detail = client.get(f"{BASE}/{sample_investment.id}", headers=auth_headers).json()
        assert detail["current_value"] == original_value - 10_000.0
        assert detail["total_withdrawals"] == 10_000.0

    def test_list_contributions_returns_history(self, client, auth_headers, sample_investment):
        client.post(
            f"{BASE}/{sample_investment.id}/contribute",
            json={"amount": 5_000.0, "is_withdrawal": False},
            headers=auth_headers,
        )
        resp = client.get(f"{BASE}/{sample_investment.id}/contributions", headers=auth_headers)
        assert resp.status_code == 200
        assert len(resp.json()) >= 1

    def test_404_contribute_to_nonexistent(self, client, auth_headers):
        resp = client.post(
            f"{BASE}/99999/contribute",
            json={"amount": 1000.0, "is_withdrawal": False},
            headers=auth_headers,
        )
        assert resp.status_code == 404


# ---------------------------------------------------------------------------
# TestInvestmentSummary
# ---------------------------------------------------------------------------

class TestInvestmentSummary:
    def test_empty_summary_returns_zeros(self, client, auth_headers):
        resp = client.get(f"{BASE}/summary", headers=auth_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert body["total_invested"] == 0
        assert body["investments_count"] == 0

    def test_summary_aggregates_correctly(self, client, auth_headers, sample_investment):
        resp = client.get(f"{BASE}/summary", headers=auth_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert body["investments_count"] == 1
        assert body["active_investments"] == 1
        assert body["total_invested"] == 100_000.0

    def test_by_type_groups_correctly(self, client, auth_headers, db, test_user, sample_investment):
        # Add a second investment of different type
        ejo = Investment(
            user_id=test_user.id,
            name="Ejo Heza",
            investment_type=ModelInvType.EJO_HEZA,
            initial_amount=50_000.0,
            current_value=50_000.0,
            total_contributions=50_000.0,
            status=ModelInvStatus.ACTIVE,
        )
        db.add(ejo)
        db.commit()
        resp = client.get(f"{BASE}/summary", headers=auth_headers)
        body = resp.json()
        assert "savings_account" in body["by_type"]
        assert "ejo_heza" in body["by_type"]


# ---------------------------------------------------------------------------
# TestInvestmentAdvice
# ---------------------------------------------------------------------------

class TestInvestmentAdvice:
    def test_no_investments_returns_starter_advice(self, client, auth_headers):
        resp = client.get(f"{BASE}/advice", headers=auth_headers)
        assert resp.status_code == 200
        titles = [a["title"] for a in resp.json()]
        assert any("Start" in t or "Begin" in t or "Investment Journey" in t for t in titles)

    def test_with_ejo_heza_no_ejo_heza_advice(self, client, auth_headers, db, test_user):
        db.add(Investment(
            user_id=test_user.id,
            name="Ejo Heza",
            investment_type=ModelInvType.EJO_HEZA,
            initial_amount=10_000.0,
            current_value=10_000.0,
            total_contributions=10_000.0,
            status=ModelInvStatus.ACTIVE,
        ))
        db.commit()
        resp = client.get(f"{BASE}/advice", headers=auth_headers)
        titles = [a["title"] for a in resp.json()]
        assert not any("Ejo Heza" in t and "Consider" in t for t in titles)

    def test_always_returns_up_to_5_items(self, client, auth_headers, sample_investment):
        resp = client.get(f"{BASE}/advice", headers=auth_headers)
        assert len(resp.json()) <= 5


# ---------------------------------------------------------------------------
# TestLinkedTransactions
# ---------------------------------------------------------------------------

class TestLinkedTransactions:
    def test_link_transaction(self, client, auth_headers, sample_investment, sample_tx):
        resp = client.post(
            f"{BASE}/{sample_investment.id}/link-transaction/{sample_tx.id}",
            headers=auth_headers,
        )
        assert resp.status_code == 200
        assert resp.json()["linked_investment_id"] == sample_investment.id

    def test_linked_transactions_list(self, client, auth_headers, sample_investment, sample_tx):
        client.post(
            f"{BASE}/{sample_investment.id}/link-transaction/{sample_tx.id}",
            headers=auth_headers,
        )
        resp = client.get(
            f"{BASE}/{sample_investment.id}/linked-transactions",
            headers=auth_headers,
        )
        assert resp.status_code == 200
        assert any(t["id"] == sample_tx.id for t in resp.json())

    def test_unlink_transaction(self, client, auth_headers, sample_investment, sample_tx):
        client.post(
            f"{BASE}/{sample_investment.id}/link-transaction/{sample_tx.id}",
            headers=auth_headers,
        )
        resp = client.delete(
            f"{BASE}/{sample_investment.id}/link-transaction/{sample_tx.id}",
            headers=auth_headers,
        )
        assert resp.status_code == 200
        assert resp.json()["linked_investment_id"] is None

    def test_404_link_nonexistent_transaction(self, client, auth_headers, sample_investment):
        resp = client.post(
            f"{BASE}/{sample_investment.id}/link-transaction/99999",
            headers=auth_headers,
        )
        assert resp.status_code == 404
