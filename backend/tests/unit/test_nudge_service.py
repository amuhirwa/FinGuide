"""
Unit tests for app.core.nudge_service
========================================
Tests context gathering, preference analysis, and Claude-powered nudge
generation with the Anthropic API fully mocked.
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

from app.core import nudge_service
from app.models.prediction import Recommendation
from app.models.transaction import Transaction, TransactionType, TransactionCategory, NeedWantCategory

pytestmark = pytest.mark.unit


# ──────────────────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────────────────

def _make_anthropic_response(nudge_list: list) -> MagicMock:
    """Build a mock Anthropic response that returns a JSON nudge list."""
    content_block = MagicMock()
    content_block.text = json.dumps(nudge_list)
    mock_response = MagicMock()
    mock_response.content = [content_block]
    return mock_response


SAMPLE_NUDGES = [
    {
        "title": "Save 5,000 RWF now!",
        "message": "You received income. Save 10% while you still have it.",
        "recommendation_type": "savings",
        "action_type": "save",
        "action_amount": 5000,
        "urgency": "high",
        "reason": "Income just received",
        "tone": "motivational",
    }
]


# ──────────────────────────────────────────────────────────────────────────────
# _get_user_context
# ──────────────────────────────────────────────────────────────────────────────

class TestGetUserContext:
    def test_empty_db_returns_zeroes(self, db, test_user):
        ctx = nudge_service._get_user_context(test_user.id, db)
        assert ctx["income_30d"] == 0.0
        assert ctx["expenses_30d"] == 0.0
        assert ctx["active_goals"] == []
        assert ctx["investments"] == []

    def test_income_transaction_counted(self, db, test_user, sample_income_transaction):
        ctx = nudge_service._get_user_context(test_user.id, db)
        assert ctx["income_30d"] == sample_income_transaction.amount

    def test_expense_transaction_counted(self, db, test_user, sample_expense_transaction):
        ctx = nudge_service._get_user_context(test_user.id, db)
        assert ctx["expenses_30d"] == sample_expense_transaction.amount

    def test_goals_included(self, db, test_user, sample_savings_goal):
        ctx = nudge_service._get_user_context(test_user.id, db)
        assert len(ctx["active_goals"]) == 1
        goal = ctx["active_goals"][0]
        assert goal["name"] == "Emergency Fund"
        assert goal["progress_pct"] == pytest.approx(20.0, abs=0.1)

    def test_top_categories_present(self, db, test_user):
        # Add multiple expense categories
        for i, cat in enumerate([
            TransactionCategory.FOOD_GROCERIES,
            TransactionCategory.TRANSPORT,
            TransactionCategory.ENTERTAINMENT,
        ]):
            tx = Transaction(
                user_id=test_user.id,
                transaction_type=TransactionType.EXPENSE,
                category=cat,
                need_want=NeedWantCategory.WANT,
                amount=1000.0 * (i + 1),
                transaction_date=datetime.now() - timedelta(days=i),
                confidence_score=0.9,
                is_verified=False,
            )
            db.add(tx)
        db.commit()

        ctx = nudge_service._get_user_context(test_user.id, db)
        assert len(ctx["top_expense_categories"]) <= 5
        categories = [c["category"] for c in ctx["top_expense_categories"]]
        assert "entertainment" in categories


# ──────────────────────────────────────────────────────────────────────────────
# _analyze_nudge_preferences
# ──────────────────────────────────────────────────────────────────────────────

class TestAnalyzeNudgePreferences:
    def test_no_history_returns_defaults(self, db, test_user):
        prefs = nudge_service._analyze_nudge_preferences(test_user.id, db)
        assert prefs["acted_rate"] == 0.0
        assert prefs["preferred_tone"] == "normal"
        assert prefs["preferred_type"] == "savings"
        assert "No history" in prefs.get("note", "")

    def test_acted_rate_calculated(self, db, test_user):
        # 2 viewed, 1 acted upon
        for i in range(2):
            rec = Recommendation(
                user_id=test_user.id,
                title=f"Nudge {i}",
                message="Test",
                recommendation_type="savings",
                urgency="normal",
                trigger_type="manual",
                is_viewed=True,
                is_acted_upon=(i == 0),
                is_active=True,
                valid_until=datetime.now() + timedelta(hours=1),
            )
            db.add(rec)
        db.commit()

        prefs = nudge_service._analyze_nudge_preferences(test_user.id, db)
        assert prefs["acted_rate"] == pytest.approx(0.5, abs=0.01)

    def test_preferred_tone_from_acted_nudges(self, db, test_user):
        # Seed 3 acted-upon "high" urgency nudges
        for _ in range(3):
            rec = Recommendation(
                user_id=test_user.id,
                title="High urgency nudge",
                message="Act now!",
                recommendation_type="savings",
                urgency="high",
                trigger_type="income",
                is_viewed=True,
                is_acted_upon=True,
                is_active=False,
                valid_until=datetime.now() - timedelta(hours=1),
            )
            db.add(rec)
        db.commit()

        prefs = nudge_service._analyze_nudge_preferences(test_user.id, db)
        assert prefs["preferred_tone"] == "high"

    def test_preferred_type_from_acted_nudges(self, db, test_user):
        for _ in range(4):
            rec = Recommendation(
                user_id=test_user.id,
                title="Investment nudge",
                message="Invest!",
                recommendation_type="investment",
                urgency="normal",
                trigger_type="weekly",
                is_viewed=True,
                is_acted_upon=True,
                is_active=False,
                valid_until=datetime.now() - timedelta(hours=1),
            )
            db.add(rec)
        db.commit()

        prefs = nudge_service._analyze_nudge_preferences(test_user.id, db)
        assert prefs["preferred_type"] == "investment"


# ──────────────────────────────────────────────────────────────────────────────
# generate_nudges
# ──────────────────────────────────────────────────────────────────────────────

class TestGenerateNudges:
    def test_no_api_key_returns_empty(self, db, test_user):
        with patch.object(nudge_service.settings, "ANTHROPIC_API_KEY", ""):
            result = nudge_service.generate_nudges(test_user.id, db, "manual")
        assert result == []

    @patch("app.core.nudge_service._get_client")
    def test_creates_recommendations_in_db(self, mock_get_client, db, test_user):
        mock_client = MagicMock()
        mock_client.messages.create.return_value = _make_anthropic_response(SAMPLE_NUDGES)
        mock_get_client.return_value = mock_client

        with patch.object(nudge_service.settings, "ANTHROPIC_API_KEY", "sk-test-key"):
            result = nudge_service.generate_nudges(
                test_user.id, db, trigger_type="income",
                income_amount=50000.0, income_source="Test Employer"
            )

        assert len(result) == 1
        assert result[0].title == "Save 5,000 RWF now!"
        assert result[0].trigger_type == "income"

    @patch("app.core.nudge_service._get_client")
    def test_trigger_type_stored(self, mock_get_client, db, test_user):
        mock_client = MagicMock()
        mock_client.messages.create.return_value = _make_anthropic_response(SAMPLE_NUDGES)
        mock_get_client.return_value = mock_client

        with patch.object(nudge_service.settings, "ANTHROPIC_API_KEY", "sk-test-key"):
            result = nudge_service.generate_nudges(test_user.id, db, trigger_type="daily")

        assert result[0].trigger_type == "daily"

    @patch("app.core.nudge_service._get_client")
    def test_nudge_metadata_stored(self, mock_get_client, db, test_user):
        mock_client = MagicMock()
        mock_client.messages.create.return_value = _make_anthropic_response(SAMPLE_NUDGES)
        mock_get_client.return_value = mock_client

        with patch.object(nudge_service.settings, "ANTHROPIC_API_KEY", "sk-test-key"):
            result = nudge_service.generate_nudges(test_user.id, db, trigger_type="income",
                                                    income_amount=25000.0)

        meta = result[0].nudge_metadata
        assert meta is not None
        assert meta["tone"] == "motivational"
        assert meta["income_trigger_amount"] == 25000.0

    @patch("app.core.nudge_service._get_client")
    def test_caps_at_two_nudges(self, mock_get_client, db, test_user):
        many_nudges = SAMPLE_NUDGES * 5  # Return 5, should be capped at 2
        mock_client = MagicMock()
        mock_client.messages.create.return_value = _make_anthropic_response(many_nudges)
        mock_get_client.return_value = mock_client

        with patch.object(nudge_service.settings, "ANTHROPIC_API_KEY", "sk-test-key"):
            result = nudge_service.generate_nudges(test_user.id, db, trigger_type="manual")

        assert len(result) <= 2

    @patch("app.core.nudge_service._get_client")
    def test_stale_nudges_deactivated(self, mock_get_client, db, test_user):
        # Seed an old active daily nudge
        old_nudge = Recommendation(
            user_id=test_user.id,
            title="Old daily nudge",
            message="Old message",
            recommendation_type="savings",
            urgency="normal",
            trigger_type="daily",
            is_active=True,
            is_dismissed=False,
            valid_until=datetime.now() + timedelta(hours=1),
            created_at=datetime.now() - timedelta(hours=25),  # older than 24h
        )
        db.add(old_nudge)
        db.commit()

        mock_client = MagicMock()
        mock_client.messages.create.return_value = _make_anthropic_response(SAMPLE_NUDGES)
        mock_get_client.return_value = mock_client

        with patch.object(nudge_service.settings, "ANTHROPIC_API_KEY", "sk-test-key"):
            nudge_service.generate_nudges(test_user.id, db, trigger_type="daily")

        db.refresh(old_nudge)
        assert old_nudge.is_active is False

    @patch("app.core.nudge_service._get_client")
    def test_json_parse_error_returns_empty(self, mock_get_client, db, test_user):
        mock_client = MagicMock()
        bad_response = MagicMock()
        bad_response.content = [MagicMock(text="not valid json {{{{")]
        mock_client.messages.create.return_value = bad_response
        mock_get_client.return_value = mock_client

        with patch.object(nudge_service.settings, "ANTHROPIC_API_KEY", "sk-test-key"):
            result = nudge_service.generate_nudges(test_user.id, db, trigger_type="manual")

        assert result == []

    @patch("app.core.nudge_service._get_client")
    def test_markdown_fenced_json_handled(self, mock_get_client, db, test_user):
        fenced = "```json\n" + json.dumps(SAMPLE_NUDGES) + "\n```"
        mock_client = MagicMock()
        response = MagicMock()
        response.content = [MagicMock(text=fenced)]
        mock_client.messages.create.return_value = response
        mock_get_client.return_value = mock_client

        with patch.object(nudge_service.settings, "ANTHROPIC_API_KEY", "sk-test-key"):
            result = nudge_service.generate_nudges(test_user.id, db, trigger_type="manual")

        assert len(result) == 1

    @patch("app.core.nudge_service._get_client")
    def test_api_error_returns_empty(self, mock_get_client, db, test_user):
        import anthropic
        mock_client = MagicMock()
        mock_client.messages.create.side_effect = anthropic.APIError(
            message="rate limit", request=MagicMock(), body={}
        )
        mock_get_client.return_value = mock_client

        with patch.object(nudge_service.settings, "ANTHROPIC_API_KEY", "sk-test-key"):
            result = nudge_service.generate_nudges(test_user.id, db, trigger_type="manual")

        assert result == []
