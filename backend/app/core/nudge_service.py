"""
Nudge Service
=============
Claude-powered personalized financial nudge generation.

Analyzes the user's financial context and past nudge response patterns to
generate adaptive, personalized notifications via the Anthropic API.
"""

import json
import logging
from collections import Counter
from datetime import datetime, timedelta
from typing import Optional

import anthropic
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.investment import Investment, InvestmentStatus
from app.models.prediction import FinancialHealthScore, Recommendation
from app.models.savings_goal import SavingsGoal, GoalStatus
from app.models.transaction import Transaction, TransactionType

logger = logging.getLogger(__name__)

_anthropic_client: Optional[anthropic.Anthropic] = None


def _get_client() -> anthropic.Anthropic:
    global _anthropic_client
    if _anthropic_client is None:
        _anthropic_client = anthropic.Anthropic(api_key=settings.ANTHROPIC_API_KEY)
    return _anthropic_client


# ─── Context gathering ────────────────────────────────────────────────────────

def _get_user_context(user_id: int, db: Session) -> dict:
    """Gather the user's current financial context for the Claude prompt."""
    now = datetime.now()
    month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    thirty_days_ago = now - timedelta(days=30)

    # Last 30 days transactions
    transactions = db.query(Transaction).filter(
        Transaction.user_id == user_id,
        Transaction.transaction_date >= thirty_days_ago,
    ).all()

    income_total = sum(t.amount for t in transactions if t.transaction_type == TransactionType.INCOME)
    expense_total = sum(t.amount for t in transactions if t.transaction_type == TransactionType.EXPENSE)

    # Top spending categories
    expense_by_category: Counter = Counter()
    for t in transactions:
        if t.transaction_type == TransactionType.EXPENSE and t.category:
            expense_by_category[t.category.value] += t.amount
    top_categories = [
        {"category": cat, "amount": round(amt, 0)}
        for cat, amt in expense_by_category.most_common(5)
    ]

    # This month's savings transactions
    savings_this_month = sum(
        t.amount for t in transactions
        if t.transaction_type == TransactionType.INCOME
        and t.transaction_date >= month_start
    )

    # Active savings goals
    goals = db.query(SavingsGoal).filter(
        SavingsGoal.user_id == user_id,
        SavingsGoal.status == GoalStatus.ACTIVE,
    ).all()
    goals_summary = []
    for g in goals:
        progress_pct = (g.current_amount / g.target_amount * 100) if g.target_amount > 0 else 0
        days_left = (g.deadline - now).days if g.deadline else None
        goals_summary.append({
            "name": g.name,
            "target": g.target_amount,
            "saved": g.current_amount,
            "progress_pct": round(progress_pct, 1),
            "daily_target": g.daily_target,
            "weekly_target": g.weekly_target,
            "days_left": days_left,
        })

    # Active investments
    investments = db.query(Investment).filter(
        Investment.user_id == user_id,
        Investment.status == InvestmentStatus.ACTIVE,
    ).all()
    investments_summary = [
        {
            "name": i.name,
            "type": i.investment_type.value if i.investment_type else "other",
            "current_value": i.current_value,
            "monthly_contribution": i.monthly_contribution,
        }
        for i in investments
    ]

    # Latest health score
    health = db.query(FinancialHealthScore).filter(
        FinancialHealthScore.user_id == user_id
    ).order_by(FinancialHealthScore.created_at.desc()).first()

    health_summary = None
    if health:
        health_summary = {
            "overall_score": health.overall_score,
            "savings_rate": health.savings_rate,
            "emergency_buffer_days": health.emergency_buffer_days,
            "goal_progress_score": health.goal_progress_score,
            "spending_discipline_score": health.spending_discipline_score,
        }

    estimated_balance = max(0, income_total - expense_total)

    return {
        "income_30d": round(income_total, 0),
        "expenses_30d": round(expense_total, 0),
        "estimated_balance": round(estimated_balance, 0),
        "top_expense_categories": top_categories,
        "savings_this_month": round(savings_this_month, 0),
        "active_goals": goals_summary,
        "investments": investments_summary,
        "health_score": health_summary,
    }


# ─── Preference learning ──────────────────────────────────────────────────────

def _analyze_nudge_preferences(user_id: int, db: Session) -> dict:
    """
    Infer what type/tone of nudge this user actually responds to,
    based on their past nudge interaction history.
    """
    all_seen = db.query(Recommendation).filter(
        Recommendation.user_id == user_id,
        Recommendation.is_viewed == True,
    ).order_by(Recommendation.created_at.desc()).limit(40).all()

    if not all_seen:
        return {
            "acted_rate": 0.0,
            "preferred_tone": "normal",
            "preferred_type": "savings",
            "acted_on_examples": [],
            "dismissed_examples": [],
            "note": "No history yet — use friendly, encouraging tone",
        }

    acted = [r for r in all_seen if r.is_acted_upon]
    dismissed = [r for r in all_seen if r.is_dismissed]

    acted_rate = len(acted) / len(all_seen) if all_seen else 0.0

    # Which urgency levels led to action?
    acted_urgencies = Counter(r.urgency for r in acted if r.urgency)
    preferred_tone = acted_urgencies.most_common(1)[0][0] if acted_urgencies else "normal"

    # Which recommendation types led to action?
    acted_types = Counter(r.recommendation_type for r in acted if r.recommendation_type)
    preferred_type = acted_types.most_common(1)[0][0] if acted_types else "savings"

    # Which trigger types they responded to
    acted_triggers = Counter(r.trigger_type for r in acted if r.trigger_type)

    # What gets dismissed most
    dismissed_types = Counter(r.recommendation_type for r in dismissed if r.recommendation_type)

    acted_on_examples = [
        {"type": r.recommendation_type, "urgency": r.urgency, "trigger": r.trigger_type}
        for r in acted[:5]
    ]
    dismissed_examples = [
        {"type": r.recommendation_type, "urgency": r.urgency}
        for r in dismissed[:5]
    ]

    return {
        "acted_rate": round(acted_rate, 2),
        "preferred_tone": preferred_tone,
        "preferred_type": preferred_type,
        "preferred_trigger": acted_triggers.most_common(1)[0][0] if acted_triggers else None,
        "types_to_avoid": [t for t, _ in dismissed_types.most_common(2)],
        "acted_on_examples": acted_on_examples,
        "dismissed_examples": dismissed_examples,
    }


# ─── Main generation function ─────────────────────────────────────────────────

def generate_nudges(
    user_id: int,
    db: Session,
    trigger_type: str = "manual",
    income_amount: Optional[float] = None,
    income_source: Optional[str] = None,
) -> list[Recommendation]:
    """
    Generate personalized Claude-powered nudges for a user.

    Args:
        user_id: The user to generate nudges for.
        db: Database session.
        trigger_type: "income", "daily", "weekly", or "manual".
        income_amount: Amount of income received (for income trigger).
        income_source: Counterparty name for the income (for income trigger).

    Returns:
        List of newly created Recommendation records.
    """
    if not settings.ANTHROPIC_API_KEY:
        logger.warning("ANTHROPIC_API_KEY not set — skipping AI nudge generation")
        return []

    # Deactivate stale nudges of the same trigger type (older than 24h)
    stale_cutoff = datetime.now() - timedelta(hours=24)
    db.query(Recommendation).filter(
        Recommendation.user_id == user_id,
        Recommendation.trigger_type == trigger_type,
        Recommendation.is_dismissed == False,
        Recommendation.created_at <= stale_cutoff,
    ).update({"is_active": False})
    db.commit()

    # Gather context
    context = _get_user_context(user_id, db)
    preferences = _analyze_nudge_preferences(user_id, db)

    # Build trigger description
    trigger_desc = {
        "income": f"User just received income of RWF {income_amount:,.0f}"
                  + (f" from {income_source}" if income_source else ""),
        "daily": "Daily savings quota check — remind user of today's savings progress",
        "weekly": "Weekly financial review — broader savings + investment overview",
        "manual": "User opened the app — show relevant personalized recommendations",
    }.get(trigger_type, "General check-in")

    system_prompt = """You are FinGuide, a friendly and smart financial advisor built for Rwandan youth with irregular income.
Your job is to generate short, personalized nudge notifications to encourage saving and investing.

Guidelines:
- Write in clear, conversational English. You may sprinkle in Kinyarwanda words for warmth (e.g. "Murakoze", "Muraho", "Ego").
- Keep each message under 120 characters so it fits on a phone notification.
- Be specific — mention real amounts, goal names, or percentages from the context.
- Adapt your tone to what has worked for this user (their preference history is provided).
- Never be preachy or guilt-tripping. Be encouraging and action-oriented.
- For income triggers: create urgency — this is the perfect moment to save/invest NOW.
- For daily/weekly: celebrate progress if any, gently nudge if behind.
- Return ONLY a valid JSON array, no extra text."""

    user_prompt = f"""Trigger: {trigger_desc}

User financial context:
{json.dumps(context, indent=2)}

User nudge preference history (what has worked / not worked):
{json.dumps(preferences, indent=2)}

Generate 1-2 nudges appropriate for this trigger. Return a JSON array like:
[
  {{
    "title": "Short title (max 50 chars)",
    "message": "Notification body (max 120 chars)",
    "recommendation_type": "savings" | "investment" | "spending",
    "action_type": "save" | "invest" | "reduce_spending" | "view_goals",
    "action_amount": <number or null>,
    "urgency": "low" | "normal" | "high",
    "reason": "Brief internal reason (not shown to user)",
    "tone": "friendly" | "motivational" | "analytical" | "urgent"
  }}
]"""

    try:
        client = _get_client()
        response = client.messages.create(
            model="claude-haiku-4-5-20251001",
            max_tokens=512,
            messages=[{"role": "user", "content": user_prompt}],
            system=system_prompt,
        )

        raw = response.content[0].text.strip()
        # Strip markdown code fences if present
        if raw.startswith("```"):
            raw = raw.split("```")[1]
            if raw.startswith("json"):
                raw = raw[4:]
        nudge_data = json.loads(raw)

    except json.JSONDecodeError as e:
        logger.error("Failed to parse Claude nudge JSON: %s", e)
        return []
    except anthropic.APIError as e:
        logger.error("Anthropic API error during nudge generation: %s", e)
        return []
    except Exception as e:
        logger.error("Unexpected error during nudge generation: %s", e)
        return []

    # Persist nudges to DB
    created = []
    valid_until = datetime.now() + timedelta(hours=48)

    for item in nudge_data[:2]:  # Safety cap at 2
        try:
            rec = Recommendation(
                user_id=user_id,
                title=str(item.get("title", ""))[:100],
                message=str(item.get("message", ""))[:500],
                recommendation_type=item.get("recommendation_type", "savings"),
                action_type=item.get("action_type", "save"),
                action_amount=item.get("action_amount"),
                urgency=item.get("urgency", "normal"),
                reason=item.get("reason", "")[:255],
                trigger_type=trigger_type,
                nudge_metadata={
                    "tone": item.get("tone", "friendly"),
                    "generated_at": datetime.now().isoformat(),
                    "income_trigger_amount": income_amount,
                },
                valid_until=valid_until,
                is_active=True,
            )
            db.add(rec)
            created.append(rec)
        except Exception as e:
            logger.error("Failed to save nudge record: %s", e)

    db.commit()
    for r in created:
        db.refresh(r)

    logger.info(
        "Generated %d nudge(s) for user %d (trigger=%s)",
        len(created), user_id, trigger_type,
    )
    return created
