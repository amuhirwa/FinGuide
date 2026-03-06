"""
Integration tests for /reports endpoints.

Covers:
  GET /reports/transactions  - export transactions as CSV rows
  GET /reports/goals         - export savings goals + contributions
  GET /reports/investments   - export investment portfolio
"""

import pytest
from datetime import datetime, timedelta

from app.models.investment import Investment, InvestmentType as ModelInvType, InvestmentStatus as ModelInvStatus
from app.models.savings_goal import SavingsGoal, GoalStatus, GoalPriority


BASE = "/api/v1/reports"


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def sample_investment(db, test_user):
    inv = Investment(
        user_id=test_user.id,
        name="SACCO Savings",
        investment_type=ModelInvType.SACCO,
        initial_amount=75_000.0,
        current_value=80_000.0,
        total_contributions=75_000.0,
        total_withdrawals=0.0,
        expected_annual_return=12.0,
        monthly_contribution=5_000.0,
        status=ModelInvStatus.ACTIVE,
        institution_name="Umurimo SACCO",
    )
    db.add(inv)
    db.commit()
    db.refresh(inv)
    return inv


# ---------------------------------------------------------------------------
# TestAuthGuard
# ---------------------------------------------------------------------------

class TestAuthGuard:
    def test_transactions_report_requires_auth(self, client):
        assert client.get(f"{BASE}/transactions").status_code == 401

    def test_goals_report_requires_auth(self, client):
        assert client.get(f"{BASE}/goals").status_code == 401

    def test_investments_report_requires_auth(self, client):
        assert client.get(f"{BASE}/investments").status_code == 401


# ---------------------------------------------------------------------------
# TestTransactionReport
# ---------------------------------------------------------------------------

class TestTransactionReport:
    def test_empty_returns_zero_records(self, client, auth_headers):
        resp = client.get(f"{BASE}/transactions", headers=auth_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert body["report_type"] == "transactions"
        assert body["record_count"] == 0
        assert body["rows"] == []
        assert body["summary"]["total_income"] == 0
        assert body["summary"]["total_expense"] == 0
        assert body["summary"]["net"] == 0

    def test_headers_present(self, client, auth_headers):
        resp = client.get(f"{BASE}/transactions", headers=auth_headers)
        headers = resp.json()["headers"]
        assert "Date" in headers
        assert "Type" in headers
        assert "Amount (RWF)" in headers

    def test_income_transaction_appears_in_report(
        self, client, auth_headers, sample_income_transaction
    ):
        resp = client.get(f"{BASE}/transactions", headers=auth_headers)
        body = resp.json()
        assert body["record_count"] == 1
        assert body["summary"]["total_income"] == sample_income_transaction.amount
        assert body["summary"]["total_expense"] == 0

    def test_expense_transaction_in_summary(
        self, client, auth_headers, sample_expense_transaction
    ):
        resp = client.get(f"{BASE}/transactions", headers=auth_headers)
        body = resp.json()
        assert body["summary"]["total_expense"] == sample_expense_transaction.amount

    def test_net_equals_income_minus_expense(
        self, client, auth_headers, sample_income_transaction, sample_expense_transaction
    ):
        resp = client.get(f"{BASE}/transactions", headers=auth_headers)
        summary = resp.json()["summary"]
        expected_net = (
            sample_income_transaction.amount - sample_expense_transaction.amount
        )
        assert summary["net"] == expected_net

    def test_date_filter_excludes_old_transactions(
        self, client, auth_headers, sample_income_transaction
    ):
        # Filter from tomorrow onward → should exclude the existing transaction
        from_date = (datetime.now() + timedelta(days=1)).isoformat()
        resp = client.get(
            f"{BASE}/transactions",
            params={"start_date": from_date},
            headers=auth_headers,
        )
        assert resp.json()["record_count"] == 0

    def test_row_values_are_strings(self, client, auth_headers, sample_income_transaction):
        resp = client.get(f"{BASE}/transactions", headers=auth_headers)
        row = resp.json()["rows"][0]
        assert all(isinstance(cell, str) for cell in row)

    def test_generated_at_present(self, client, auth_headers):
        resp = client.get(f"{BASE}/transactions", headers=auth_headers)
        assert "generated_at" in resp.json()


# ---------------------------------------------------------------------------
# TestGoalsReport
# ---------------------------------------------------------------------------

class TestGoalsReport:
    def test_empty_returns_zero_goals(self, client, auth_headers):
        resp = client.get(f"{BASE}/goals", headers=auth_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert body["report_type"] == "goals"
        assert body["record_count"] == 0
        assert body["summary"]["total_goals"] == 0
        assert body["summary"]["total_saved"] == 0
        assert body["summary"]["total_target"] == 0

    def test_goal_appears_in_report(self, client, auth_headers, sample_savings_goal):
        resp = client.get(f"{BASE}/goals", headers=auth_headers)
        body = resp.json()
        assert body["record_count"] == 1
        assert body["summary"]["total_goals"] == 1
        assert body["summary"]["total_saved"] == sample_savings_goal.current_amount
        assert body["summary"]["total_target"] == sample_savings_goal.target_amount

    def test_contributions_sub_table_present(self, client, auth_headers):
        resp = client.get(f"{BASE}/goals", headers=auth_headers)
        body = resp.json()
        assert "contributions" in body
        assert "headers" in body["contributions"]
        assert "rows" in body["contributions"]

    def test_goal_headers_present(self, client, auth_headers):
        resp = client.get(f"{BASE}/goals", headers=auth_headers)
        headers = resp.json()["headers"]
        assert "Goal Name" in headers
        assert "Target (RWF)" in headers
        assert "Progress %" in headers


# ---------------------------------------------------------------------------
# TestInvestmentReport
# ---------------------------------------------------------------------------

class TestInvestmentReport:
    def test_empty_returns_zero_investments(self, client, auth_headers):
        resp = client.get(f"{BASE}/investments", headers=auth_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert body["report_type"] == "investments"
        assert body["record_count"] == 0
        assert body["summary"]["total_investments"] == 0

    def test_investment_headers_present(self, client, auth_headers):
        resp = client.get(f"{BASE}/investments", headers=auth_headers)
        headers = resp.json()["headers"]
        assert "Name" in headers
        assert "Type" in headers
        assert "Current Value (RWF)" in headers
