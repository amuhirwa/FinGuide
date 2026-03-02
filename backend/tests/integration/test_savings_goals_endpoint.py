"""
Integration tests for /goals endpoints.

Covers:
  GET  /goals             - list goals (optionally filtered by status)
  POST /goals             - create goal with realistic savings calculation
  GET  /goals/piggybank   - piggybank balance from savings transactions
  GET  /goals/{id}        - detail with contributions
  PATCH /goals/{id}       - update goal fields / status
  DELETE /goals/{id}      - delete
  POST /goals/{id}/contribute - contribute to goal (with auto-completion)
"""

import pytest
from datetime import datetime, timedelta

from app.models.savings_goal import SavingsGoal, GoalStatus, GoalPriority, GoalContribution
from app.models.transaction import Transaction, TransactionType, TransactionCategory, NeedWantCategory


BASE = "/api/v1/goals"
FUTURE = datetime.now() + timedelta(days=180)
DEADLINE_STR = FUTURE.isoformat()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _create_goal_payload(**overrides):
    data = {
        "name": "Emergency Fund",
        "target_amount": 100_000.0,
        "priority": "medium",
        "deadline": DEADLINE_STR,
        "is_flexible": False,
    }
    data.update(overrides)
    return data


def _add_income(db, user, amount=50_000.0, weeks_ago=1):
    tx = Transaction(
        user_id=user.id,
        transaction_type=TransactionType.INCOME,
        category=TransactionCategory.OTHER_INCOME,
        need_want=NeedWantCategory.UNCATEGORIZED,
        amount=amount,
        description="Salary",
        transaction_date=datetime.now() - timedelta(weeks=weeks_ago),
        confidence_score=1.0,
    )
    db.add(tx)
    db.commit()
    return tx


def _add_expense(db, user, amount=20_000.0, weeks_ago=1):
    tx = Transaction(
        user_id=user.id,
        transaction_type=TransactionType.EXPENSE,
        category=TransactionCategory.FOOD_GROCERIES,
        need_want=NeedWantCategory.NEED,
        amount=amount,
        description="Groceries",
        transaction_date=datetime.now() - timedelta(weeks=weeks_ago),
        confidence_score=1.0,
    )
    db.add(tx)
    db.commit()
    return tx


def _add_savings_tx(db, user, amount=10_000.0, counterparty="MyBank"):
    tx = Transaction(
        user_id=user.id,
        transaction_type=TransactionType.EXPENSE,
        category=TransactionCategory.SAVINGS,
        need_want=NeedWantCategory.SAVINGS,
        amount=amount,
        description="Savings deposit",
        counterparty=counterparty,
        transaction_date=datetime.now() - timedelta(days=1),
        confidence_score=1.0,
    )
    db.add(tx)
    db.commit()
    return tx


# ---------------------------------------------------------------------------
# TestAuthGuard
# ---------------------------------------------------------------------------

class TestAuthGuard:
    def test_list_requires_auth(self, client):
        assert client.get(BASE).status_code == 401

    def test_create_requires_auth(self, client):
        assert client.post(BASE, json={}).status_code == 401

    def test_piggybank_requires_auth(self, client):
        assert client.get(f"{BASE}/piggybank").status_code == 401

    def test_detail_requires_auth(self, client):
        assert client.get(f"{BASE}/1").status_code == 401


# ---------------------------------------------------------------------------
# TestCreateGoal
# ---------------------------------------------------------------------------

class TestCreateGoal:
    def test_creates_goal_returns_201(self, client, auth_headers):
        resp = client.post(BASE, json=_create_goal_payload(), headers=auth_headers)
        assert resp.status_code == 201
        body = resp.json()
        assert body["name"] == "Emergency Fund"
        assert body["target_amount"] == 100_000.0
        assert body["current_amount"] == 0.0
        assert body["status"] == "active"

    def test_progress_percentage_is_zero_on_creation(self, client, auth_headers):
        resp = client.post(BASE, json=_create_goal_payload(), headers=auth_headers)
        assert resp.json()["progress_percentage"] == 0.0

    def test_realistic_saving_zero_with_no_history(self, client, auth_headers):
        resp = client.post(BASE, json=_create_goal_payload(), headers=auth_headers)
        body = resp.json()
        # No transactions in DB → no weekly surplus → realistic_weekly_saving == 0
        assert body["realistic_weekly_saving"] == 0.0

    def test_realistic_saving_nonzero_with_transaction_history(
        self, client, auth_headers, db, test_user
    ):
        # Add income > expenses across multiple weeks so surplus is positive
        for w in range(1, 9):
            _add_income(db, test_user, amount=50_000.0, weeks_ago=w)
            _add_expense(db, test_user, amount=20_000.0, weeks_ago=w)

        resp = client.post(BASE, json=_create_goal_payload(), headers=auth_headers)
        body = resp.json()
        assert body["realistic_weekly_saving"] > 0.0
        assert body["realistic_weeks"] is not None
        assert body["avg_weekly_income"] > 0.0
        assert body["avg_weekly_surplus"] > 0.0

    def test_daily_and_weekly_targets_computed(self, client, auth_headers):
        resp = client.post(BASE, json=_create_goal_payload(), headers=auth_headers)
        body = resp.json()
        assert body["daily_target"] > 0.0
        assert body["weekly_target"] > 0.0
        assert abs(body["weekly_target"] - body["daily_target"] * 7) < 0.1


# ---------------------------------------------------------------------------
# TestListGoals
# ---------------------------------------------------------------------------

class TestListGoals:
    def test_empty_list_when_no_goals(self, client, auth_headers):
        resp = client.get(BASE, headers=auth_headers)
        assert resp.status_code == 200
        assert resp.json() == []

    def test_returns_created_goals(self, client, auth_headers, sample_savings_goal):
        resp = client.get(BASE, headers=auth_headers)
        assert resp.status_code == 200
        assert len(resp.json()) >= 1

    def test_filter_by_status_active(self, client, auth_headers, db, test_user):
        active = SavingsGoal(
            user_id=test_user.id,
            name="Active Goal",
            target_amount=50_000.0,
            status=GoalStatus.ACTIVE,
            priority=GoalPriority.MEDIUM,
        )
        paused = SavingsGoal(
            user_id=test_user.id,
            name="Paused Goal",
            target_amount=30_000.0,
            status=GoalStatus.PAUSED,
            priority=GoalPriority.LOW,
        )
        db.add_all([active, paused])
        db.commit()
        resp = client.get(BASE, params={"status": "active"}, headers=auth_headers)
        names = [g["name"] for g in resp.json()]
        assert "Active Goal" in names
        assert "Paused Goal" not in names


# ---------------------------------------------------------------------------
# TestGetGoal
# ---------------------------------------------------------------------------

class TestGetGoal:
    def test_returns_goal_detail(self, client, auth_headers, sample_savings_goal):
        resp = client.get(f"{BASE}/{sample_savings_goal.id}", headers=auth_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert body["id"] == sample_savings_goal.id
        assert "contributions" in body

    def test_404_nonexistent(self, client, auth_headers):
        resp = client.get(f"{BASE}/99999", headers=auth_headers)
        assert resp.status_code == 404

    def test_404_other_users_goal(self, client, auth_headers, db):
        from app.models.user import User, UbudheCategory, IncomeFrequency
        from app.core.security import get_password_hash
        other = User(
            phone_number="0789333444",
            full_name="Other",
            hashed_password=get_password_hash("pass"),
            ubudehe_category=UbudheCategory.CATEGORY_1,
            income_frequency=IncomeFrequency.MONTHLY,
            is_active=True,
        )
        db.add(other)
        db.commit()
        goal = SavingsGoal(
            user_id=other.id,
            name="Other's Goal",
            target_amount=10_000.0,
            status=GoalStatus.ACTIVE,
            priority=GoalPriority.LOW,
        )
        db.add(goal)
        db.commit()
        resp = client.get(f"{BASE}/{goal.id}", headers=auth_headers)
        assert resp.status_code == 404


# ---------------------------------------------------------------------------
# TestUpdateGoal
# ---------------------------------------------------------------------------

class TestUpdateGoal:
    def test_update_name(self, client, auth_headers, sample_savings_goal):
        resp = client.patch(
            f"{BASE}/{sample_savings_goal.id}",
            json={"name": "Renamed Goal"},
            headers=auth_headers,
        )
        assert resp.status_code == 200
        assert resp.json()["name"] == "Renamed Goal"

    def test_update_target_amount(self, client, auth_headers, sample_savings_goal):
        resp = client.patch(
            f"{BASE}/{sample_savings_goal.id}",
            json={"target_amount": 200_000.0},
            headers=auth_headers,
        )
        assert resp.status_code == 200
        assert resp.json()["target_amount"] == 200_000.0

    def test_mark_completed_sets_completed_at(self, client, auth_headers, sample_savings_goal):
        resp = client.patch(
            f"{BASE}/{sample_savings_goal.id}",
            json={"status": "completed"},
            headers=auth_headers,
        )
        assert resp.status_code == 200
        body = resp.json()
        assert body["status"] == "completed"
        assert body["completed_at"] is not None

    def test_404_nonexistent(self, client, auth_headers):
        resp = client.patch(f"{BASE}/99999", json={"name": "X"}, headers=auth_headers)
        assert resp.status_code == 404


# ---------------------------------------------------------------------------
# TestDeleteGoal
# ---------------------------------------------------------------------------

class TestDeleteGoal:
    def test_delete_returns_204(self, client, auth_headers, sample_savings_goal):
        resp = client.delete(f"{BASE}/{sample_savings_goal.id}", headers=auth_headers)
        assert resp.status_code == 204

    def test_deleted_goal_not_in_list(self, client, auth_headers, sample_savings_goal):
        client.delete(f"{BASE}/{sample_savings_goal.id}", headers=auth_headers)
        resp = client.get(BASE, headers=auth_headers)
        ids = [g["id"] for g in resp.json()]
        assert sample_savings_goal.id not in ids

    def test_404_nonexistent(self, client, auth_headers):
        resp = client.delete(f"{BASE}/99999", headers=auth_headers)
        assert resp.status_code == 404


# ---------------------------------------------------------------------------
# TestContributeToGoal
# ---------------------------------------------------------------------------

class TestContributeToGoal:
    def test_contribution_increases_current_amount(
        self, client, auth_headers, sample_savings_goal
    ):
        before = sample_savings_goal.current_amount
        resp = client.post(
            f"{BASE}/{sample_savings_goal.id}/contribute",
            json={"amount": 5_000.0},
            headers=auth_headers,
        )
        assert resp.status_code == 200
        assert resp.json()["current_amount"] == before + 5_000.0

    def test_contribution_completes_goal_when_full(
        self, client, auth_headers, db, test_user
    ):
        goal = SavingsGoal(
            user_id=test_user.id,
            name="Nearly Done",
            target_amount=10_000.0,
            current_amount=9_000.0,
            status=GoalStatus.ACTIVE,
            priority=GoalPriority.HIGH,
        )
        db.add(goal)
        db.commit()
        db.refresh(goal)

        resp = client.post(
            f"{BASE}/{goal.id}/contribute",
            json={"amount": 1_500.0},
            headers=auth_headers,
        )
        assert resp.status_code == 200
        body = resp.json()
        assert body["status"] == "completed"
        assert body["completed_at"] is not None

    def test_cannot_contribute_to_paused_goal(self, client, auth_headers, db, test_user):
        paused = SavingsGoal(
            user_id=test_user.id,
            name="Paused",
            target_amount=50_000.0,
            current_amount=0.0,
            status=GoalStatus.PAUSED,
            priority=GoalPriority.LOW,
        )
        db.add(paused)
        db.commit()
        resp = client.post(
            f"{BASE}/{paused.id}/contribute",
            json={"amount": 1_000.0},
            headers=auth_headers,
        )
        assert resp.status_code == 400
        assert "inactive" in resp.json()["detail"].lower()

    def test_404_nonexistent_goal(self, client, auth_headers):
        resp = client.post(
            f"{BASE}/99999/contribute",
            json={"amount": 1_000.0},
            headers=auth_headers,
        )
        assert resp.status_code == 404


# ---------------------------------------------------------------------------
# TestPiggybank
# ---------------------------------------------------------------------------

class TestPiggybank:
    def test_empty_piggybank_returns_zero_balance(self, client, auth_headers):
        resp = client.get(f"{BASE}/piggybank", headers=auth_headers)
        assert resp.status_code == 200
        body = resp.json()
        assert body["balance"] == 0.0
        assert body["total_contributed"] == 0.0
        assert body["contribution_count"] == 0

    def test_savings_expense_contributes_to_piggybank(
        self, client, auth_headers, db, test_user
    ):
        _add_savings_tx(db, test_user, amount=15_000.0, counterparty="BK Savings")
        resp = client.get(f"{BASE}/piggybank", headers=auth_headers)
        body = resp.json()
        assert body["balance"] == 15_000.0
        assert body["total_contributed"] == 15_000.0
        assert body["contribution_count"] == 1

    def test_withdrawal_from_savings_counterparty_reduces_balance(
        self, client, auth_headers, db, test_user
    ):
        _add_savings_tx(db, test_user, amount=20_000.0, counterparty="BK Savings")
        # Simulate withdrawal: INCOME from same counterparty
        withdrawal = Transaction(
            user_id=test_user.id,
            transaction_type=TransactionType.INCOME,
            category=TransactionCategory.OTHER_INCOME,
            need_want=NeedWantCategory.UNCATEGORIZED,
            amount=5_000.0,
            description="Withdrawal from savings",
            counterparty="BK Savings",
            transaction_date=datetime.now(),
            confidence_score=1.0,
        )
        db.add(withdrawal)
        db.commit()
        resp = client.get(f"{BASE}/piggybank", headers=auth_headers)
        body = resp.json()
        assert body["balance"] == 15_000.0  # 20_000 - 5_000
        assert body["withdrawal_count"] == 1

    def test_by_party_groups_savings_by_counterparty(
        self, client, auth_headers, db, test_user
    ):
        _add_savings_tx(db, test_user, amount=10_000.0, counterparty="BK Savings")
        _add_savings_tx(db, test_user, amount=5_000.0, counterparty="GT Bank")
        resp = client.get(f"{BASE}/piggybank", headers=auth_headers)
        parties = {p["name"]: p for p in resp.json()["by_party"]}
        assert "BK Savings" in parties
        assert "GT Bank" in parties
