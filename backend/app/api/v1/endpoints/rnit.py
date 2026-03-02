"""
RNIT Endpoints
==============
Rwanda National Investment Trust fund tracking and portfolio insights.
"""

from typing import List, Optional
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.models.base import get_db
from app.models.rnit import RnitPurchase, RnitNavCache
from app.schemas.user import TokenPayload
from app.core.deps import get_current_active_user
from app.services.rnit_nav import (
    get_nav_on_date, get_latest_nav, get_nav_history,
    project_future_value, refresh_nav_cache, RNIT_ANNUAL_GROWTH_PCT
)

router = APIRouter()

# ── Pydantic Schemas ─────────────────────────────────────────────────────────

class RnitPurchaseOut(BaseModel):
    id: int
    purchase_date: datetime
    amount_rwf: float
    nav_at_purchase: Optional[float]
    units: Optional[float]
    current_value: Optional[float]
    gain_rwf: Optional[float]
    gain_pct: Optional[float]
    raw_sms: Optional[str]

    model_config = {"from_attributes": True}


class RnitNavPoint(BaseModel):
    date: str
    nav: float


class RnitProjection(BaseModel):
    years: float
    projected_value: float


class RnitPortfolio(BaseModel):
    total_units: float
    total_invested_rwf: float
    current_nav: Optional[float]
    current_value: Optional[float]
    total_gain_rwf: Optional[float]
    total_gain_pct: Optional[float]
    first_purchase_date: Optional[datetime]
    purchase_count: int
    annual_growth_pct: float
    projections: List[RnitProjection]
    purchases: List[RnitPurchaseOut]


# ── Helpers ──────────────────────────────────────────────────────────────────

def _enrich_purchase(p: RnitPurchase, current_nav: Optional[float]) -> RnitPurchaseOut:
    current_value = (p.units * current_nav) if (p.units and current_nav) else None
    gain_rwf = (current_value - p.amount_rwf) if current_value is not None else None
    gain_pct = (gain_rwf / p.amount_rwf * 100) if (gain_rwf is not None and p.amount_rwf > 0) else None
    return RnitPurchaseOut(
        id=p.id,
        purchase_date=p.purchase_date,
        amount_rwf=p.amount_rwf,
        nav_at_purchase=p.nav_at_purchase,
        units=p.units,
        current_value=current_value,
        gain_rwf=gain_rwf,
        gain_pct=gain_pct,
        raw_sms=p.raw_sms,
    )


# ── Endpoints ────────────────────────────────────────────────────────────────

@router.get("/portfolio", response_model=RnitPortfolio)
async def get_rnit_portfolio(
    current_user: TokenPayload = Depends(get_current_active_user),
    db: Session = Depends(get_db),
):
    """Full RNIT portfolio summary with projections."""
    user_id = int(current_user.sub)
    purchases = (
        db.query(RnitPurchase)
        .filter(RnitPurchase.user_id == user_id)
        .order_by(RnitPurchase.purchase_date.desc())
        .all()
    )

    current_nav = get_latest_nav(db)

    # Backfill any purchases that are missing nav/units
    for p in purchases:
        if p.nav_at_purchase is None and p.purchase_date:
            nav = get_nav_on_date(db, p.purchase_date)
            if nav:
                p.nav_at_purchase = nav
                p.units = p.amount_rwf / nav
                db.commit()

    total_units = sum(p.units or 0 for p in purchases)
    total_invested = sum(p.amount_rwf for p in purchases)
    current_value = (total_units * current_nav) if (total_units and current_nav) else None
    gain_rwf = (current_value - total_invested) if current_value is not None else None
    gain_pct = (gain_rwf / total_invested * 100) if (gain_rwf is not None and total_invested > 0) else None
    first_date = min((p.purchase_date for p in purchases), default=None)

    projections = []
    if total_units and current_nav:
        for yr in [1, 3, 5, 10]:
            projections.append(RnitProjection(
                years=float(yr),
                projected_value=project_future_value(total_units, current_nav, yr),
            ))

    return RnitPortfolio(
        total_units=total_units,
        total_invested_rwf=total_invested,
        current_nav=current_nav,
        current_value=current_value,
        total_gain_rwf=gain_rwf,
        total_gain_pct=gain_pct,
        first_purchase_date=first_date,
        purchase_count=len(purchases),
        annual_growth_pct=RNIT_ANNUAL_GROWTH_PCT,
        projections=projections,
        purchases=[_enrich_purchase(p, current_nav) for p in purchases],
    )


@router.get("/nav-history", response_model=List[RnitNavPoint])
async def get_nav_history_endpoint(
    limit: int = 90,
    current_user: TokenPayload = Depends(get_current_active_user),
    db: Session = Depends(get_db),
):
    """Return NAV history for charting."""
    history = get_nav_history(db, limit=limit)
    # Return oldest-first for charts
    return list(reversed(history))


@router.post("/refresh-nav")
async def refresh_nav(
    current_user: TokenPayload = Depends(get_current_active_user),
    db: Session = Depends(get_db),
):
    """Force-refresh the NAV cache from rnit.rw."""
    count = refresh_nav_cache(db)
    latest = get_latest_nav(db)
    return {"inserted": count, "latest_nav": latest}
