"""
Integration tests for /api/v1/insights endpoints.
====================================================
Covers recommendations CRUD, nudge generation, health score,
and the dashboard summary. Claude API calls are fully mocked.
"""

import json
import os
import pytest
from datetime import datetime, timedelta
from unittest.mock import MagicMock, patch

os.environ.setdefault("SMS_USERNAME", "test_user")
os.environ.setdefault("SMS_PASSWORD", "test_pass")
os.environ.setdefault("SMS_AUTH", "http://localhost/auth")
os.environ.setdefault("SMS_SEND", "http://localhost/send")

pytestmark = pytest.mark.integration

BASE = "/api/v1/insights"


def _mock_client_with(nudge_list: list):
    """Return a mock Anthropic client that emits nudge_list."""
    mock_client = MagicMock()
    content = MagicMock()
    content.text = json.dumps(nudge_list)
    mock_client.messages.create.return_value = MagicMock(content=[content])
    return mock_client


SAMPLE_NUDGE = [
    {
        "title": "Save now!",
        "message": "Great income today. Save 10%.",
        "recommendation_type": "savings",
        "action_type": "save",
        "action_amount": 5000,
        "urgency": "high",
        "reason": "Income received",
        "tone": "motivational",
    }
]


# ──────────────────────────────────────────────────────────────────────────────
# Auth guard
# ──────────────────────────────────────────────────────────────────────────────

class TestAuthGuard:
    def test_recommendations_unauthenticated(self, client):
        assert client.get(f"{BASE}/recommendations").status_code == 401

    def test_generate_nudges_unauthenticated(self, client):
        assert client.post(f"{BASE}/generate-nudges",
                           json={"trigger_type": "manual"}).status_code == 401

    def test_health_score_unauthenticated(self, client):
        assert client.get(f"{BASE}/health-score").status_code == 401


# ──────────────────────────────────────────────────────────────────────────────
# GET /insights/recommendations
# ──────────────────────────────────────────────────────────────────────────────

class TestGetRecommendations:
    @patch("app.api.v1.endpoints.predictions.nudge_service.generate_nudges")
    def test_returns_200(self, mock_gen, client, auth_headers):
        mock_gen.return_value = []
        resp = client.get(f"{BASE}/recommendations", headers=auth_headers)
        assert resp.status_code == 200

    @patch("app.api.v1.endpoints.predictions.nudge_service.generate_nudges")
    def test_returns_list(self, mock_gen, client, auth_headers):
        mock_gen.return_value = []
        resp = client.get(f"{BASE}/recommendations", headers=auth_headers)
        assert isinstance(resp.json(), list)

    def test_seeded_recommendation_returned(
        self, client, auth_headers, sample_recommendation
    ):
        resp = client.get(f"{BASE}/recommendations", headers=auth_headers)
        ids = [r["id"] for r in resp.json()]
        assert sample_recommendation.id in ids

    def test_dismissed_recommendation_excluded(
        self, client, auth_headers, db, test_user
    ):
        from app.models.prediction import Recommendation
        dismissed = Recommendation(
            user_id=test_user.id,
            title="Dismissed",
            message="Dismissed nudge",
            recommendation_type="savings",
            urgency="normal",
            trigger_type="manual",
            is_active=True,
            is_dismissed=True,
            valid_until=datetime.now() + timedelta(hours=1),
        )
        db.add(dismissed)
        db.commit()

        resp = client.get(f"{BASE}/recommendations", headers=auth_headers)
        titles = [r["title"] for r in resp.json()]
        assert "Dismissed" not in titles


# ──────────────────────────────────────────────────────────────────────────────
# PATCH /insights/recommendations/{id} — interaction tracking
# ──────────────────────────────────────────────────────────────────────────────

class TestRecommendationInteraction:
    def test_mark_viewed(self, client, auth_headers, sample_recommendation):
        resp = client.patch(
            f"{BASE}/recommendations/{sample_recommendation.id}",
            json={"action": "viewed"},
            headers=auth_headers,
        )
        assert resp.status_code == 200
        assert resp.json()["is_viewed"] is True

    def test_mark_acted(self, client, auth_headers, sample_recommendation):
        resp = client.patch(
            f"{BASE}/recommendations/{sample_recommendation.id}",
            json={"action": "acted"},
            headers=auth_headers,
        )
        assert resp.status_code == 200
        assert resp.json()["is_acted_upon"] is True

    def test_mark_dismissed_deactivates(self, client, auth_headers, sample_recommendation):
        resp = client.patch(
            f"{BASE}/recommendations/{sample_recommendation.id}",
            json={"action": "dismissed"},
            headers=auth_headers,
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["is_dismissed"] is True

    def test_invalid_action_returns_422(self, client, auth_headers, sample_recommendation):
        resp = client.patch(
            f"{BASE}/recommendations/{sample_recommendation.id}",
            json={"action": "invalid_action"},
            headers=auth_headers,
        )
        assert resp.status_code == 422

    def test_other_user_recommendation_returns_404(
        self, client, auth_headers, db
    ):
        from app.models.user import User, UbudheCategory, IncomeFrequency
        from app.models.prediction import Recommendation
        from app.core.security import get_password_hash

        other = User(
            phone_number="0781888001",
            full_name="Other",
            hashed_password=get_password_hash("pw"),
            ubudehe_category=UbudheCategory.CATEGORY_1,
            income_frequency=IncomeFrequency.MONTHLY,
            is_active=True, is_verified=True,
        )
        db.add(other)
        db.commit()
        db.refresh(other)

        rec = Recommendation(
            user_id=other.id,
            title="Other rec",
            message="Other",
            recommendation_type="savings",
            urgency="normal",
            trigger_type="manual",
            is_active=True,
            valid_until=datetime.now() + timedelta(hours=1),
        )
        db.add(rec)
        db.commit()

        resp = client.patch(
            f"{BASE}/recommendations/{rec.id}",
            json={"action": "viewed"},
            headers=auth_headers,
        )
        assert resp.status_code == 404


# ──────────────────────────────────────────────────────────────────────────────
# POST /insights/generate-nudges
# ──────────────────────────────────────────────────────────────────────────────

class TestGenerateNudges:
    @patch("app.api.v1.endpoints.predictions.nudge_service.generate_nudges")
    def test_manual_trigger_returns_200(self, mock_gen, client, auth_headers):
        mock_gen.return_value = []
        resp = client.post(
            f"{BASE}/generate-nudges",
            json={"trigger_type": "manual"},
            headers=auth_headers,
        )
        assert resp.status_code == 200

    @patch("app.api.v1.endpoints.predictions.nudge_service.generate_nudges")
    def test_daily_trigger_accepted(self, mock_gen, client, auth_headers):
        mock_gen.return_value = []
        resp = client.post(
            f"{BASE}/generate-nudges",
            json={"trigger_type": "daily"},
            headers=auth_headers,
        )
        assert resp.status_code == 200

    @patch("app.api.v1.endpoints.predictions.nudge_service.generate_nudges")
    def test_weekly_trigger_accepted(self, mock_gen, client, auth_headers):
        mock_gen.return_value = []
        resp = client.post(
            f"{BASE}/generate-nudges",
            json={"trigger_type": "weekly"},
            headers=auth_headers,
        )
        assert resp.status_code == 200

    def test_invalid_trigger_type_returns_422(self, client, auth_headers):
        resp = client.post(
            f"{BASE}/generate-nudges",
            json={"trigger_type": "invalid"},
            headers=auth_headers,
        )
        assert resp.status_code == 422

    @patch("app.core.nudge_service._get_client")
    def test_returns_created_nudges(self, mock_get_client, client, auth_headers):
        mock_get_client.return_value = _mock_client_with(SAMPLE_NUDGE)
        with patch("app.core.nudge_service.settings") as mock_settings:
            mock_settings.ANTHROPIC_API_KEY = "sk-test"
            mock_settings.OTP_EXPIRE_MINUTES = 5
            resp = client.post(
                f"{BASE}/generate-nudges",
                json={"trigger_type": "manual"},
                headers=auth_headers,
            )
        assert resp.status_code == 200
        assert isinstance(resp.json(), list)


# ──────────────────────────────────────────────────────────────────────────────
# GET /insights/health-score
# ──────────────────────────────────────────────────────────────────────────────

class TestHealthScore:
    def test_returns_200(self, client, auth_headers):
        resp = client.get(f"{BASE}/health-score", headers=auth_headers)
        assert resp.status_code == 200

    def test_has_required_fields(self, client, auth_headers):
        resp = client.get(f"{BASE}/health-score", headers=auth_headers)
        data = resp.json()
        assert "overall_score" in data
        assert "grade" in data

    def test_score_in_valid_range(self, client, auth_headers):
        resp = client.get(f"{BASE}/health-score", headers=auth_headers)
        score = resp.json()["overall_score"]
        assert 0 <= score <= 100

    def test_grade_is_valid(self, client, auth_headers):
        resp = client.get(f"{BASE}/health-score", headers=auth_headers)
        assert resp.json()["grade"] in ("A", "B", "C", "D", "F")


# ──────────────────────────────────────────────────────────────────────────────
# GET /insights/safe-to-spend
# ──────────────────────────────────────────────────────────────────────────────

class TestSafeToSpend:
    def test_returns_200(self, client, auth_headers):
        resp = client.get(f"{BASE}/safe-to-spend", headers=auth_headers)
        assert resp.status_code == 200

    def test_safe_to_spend_non_negative(self, client, auth_headers):
        resp = client.get(f"{BASE}/safe-to-spend", headers=auth_headers)
        assert resp.json()["safe_to_spend"] >= 0

    def test_explanation_present(self, client, auth_headers):
        resp = client.get(f"{BASE}/safe-to-spend", headers=auth_headers)
        assert "explanation" in resp.json()


# ──────────────────────────────────────────────────────────────────────────────
# GET /insights/dashboard
# ──────────────────────────────────────────────────────────────────────────────

class TestDashboardSummary:
    def test_returns_200(self, client, auth_headers):
        resp = client.get(f"{BASE}/dashboard", headers=auth_headers)
        assert resp.status_code == 200

    def test_has_balance_fields(self, client, auth_headers):
        data = resp = client.get(f"{BASE}/dashboard", headers=auth_headers).json()
        assert "total_balance" in data
        assert "income_this_month" in data
        assert "expenses_this_month" in data

    def test_has_health_score(self, client, auth_headers):
        data = client.get(f"{BASE}/dashboard", headers=auth_headers).json()
        assert "health_score" in data
        assert 0 <= data["health_score"] <= 100


# ──────────────────────────────────────────────────────────────────────────────
# POST /insights/simulate-investment
# ──────────────────────────────────────────────────────────────────────────────

class TestInvestmentSimulation:
    def test_basic_ejo_heza_simulation(self, client, auth_headers):
        resp = client.post(
            f"{BASE}/simulate-investment",
            json={
                "principal": 100000,
                "monthly_contribution": 5000,
                "investment_type": "ejo_heza",
                "duration_months": 12,
            },
            headers=auth_headers,
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["final_value"] > 100000
        assert data["annual_rate"] == pytest.approx(10.0, abs=0.1)

    def test_returns_monthly_breakdown(self, client, auth_headers):
        resp = client.post(
            f"{BASE}/simulate-investment",
            json={
                "principal": 50000,
                "monthly_contribution": 0,
                "investment_type": "savings",
                "duration_months": 3,
            },
            headers=auth_headers,
        )
        breakdown = resp.json()["monthly_breakdown"]
        assert len(breakdown) == 3

    def test_invalid_duration_rejected(self, client, auth_headers):
        resp = client.post(
            f"{BASE}/simulate-investment",
            json={
                "principal": 100000,
                "monthly_contribution": 0,
                "investment_type": "ejo_heza",
                "duration_months": 0,
            },
            headers=auth_headers,
        )
        assert resp.status_code == 422
