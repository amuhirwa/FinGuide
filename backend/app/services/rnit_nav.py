"""
RNIT NAV Scraper Service
========================
Scrapes Net Asset Value history from https://rnit.rw/net-asset-value/
and caches it in the database.

The page contains an HTML table with rows like:
  <tr><td>17-02-2026</td><td>RWF 265.61</td></tr>
"""

import re
import logging
from datetime import datetime, timedelta
from typing import List, Optional, Dict

import httpx
from sqlalchemy.orm import Session
from sqlalchemy.dialects.sqlite import insert as sqlite_insert

from app.models.rnit import RnitNavCache

logger = logging.getLogger(__name__)

RNIT_NAV_URL = "https://rnit.rw/net-asset-value/"
RNIT_ANNUAL_GROWTH_PCT = 11.0   # historical ~11% annual growth
CACHE_MAX_AGE_HOURS = 12        # re-scrape if cache is older than this


def scrape_nav_history() -> List[Dict]:
    """
    Fetch and parse NAV history from rnit.rw.
    Returns list of {"nav_date": datetime, "nav_rwf": float}.
    """
    try:
        with httpx.Client(timeout=15, follow_redirects=True,
                          headers={"User-Agent": "FinGuide/1.0"}) as client:
            resp = client.get(RNIT_NAV_URL)
            resp.raise_for_status()
            html = resp.text
    except Exception as exc:
        logger.warning("RNIT scrape failed: %s", exc)
        return []

    results = []
    # Match <tr><td>DD-MM-YYYY</td><td>RWF NNN.NN</td></tr>
    pattern = re.compile(
        r'<td>(\d{2}-\d{2}-\d{4})</td>\s*<td>[^<]*?(\d+\.\d+)</td>',
        re.IGNORECASE
    )
    for m in pattern.finditer(html):
        try:
            nav_date = datetime.strptime(m.group(1), "%d-%m-%Y")
            nav_rwf = float(m.group(2))
            results.append({"nav_date": nav_date, "nav_rwf": nav_rwf})
        except ValueError:
            continue
    return results


def refresh_nav_cache(db: Session) -> int:
    """
    Scrape RNIT NAV and upsert into rnit_nav_cache.
    Returns the number of rows inserted/updated.
    """
    rows = scrape_nav_history()
    if not rows:
        return 0

    for row in rows:
        stmt = sqlite_insert(RnitNavCache).values(
            nav_date=row["nav_date"],
            nav_rwf=row["nav_rwf"],
        )
        stmt = stmt.on_conflict_do_update(
            index_elements=["nav_date"],
            set_={"nav_rwf": stmt.excluded.nav_rwf, "scraped_at": datetime.utcnow()},
        )
        db.execute(stmt)
    db.commit()
    return len(rows)


def get_nav_on_date(db: Session, target_date: datetime) -> Optional[float]:
    """
    Return the NAV closest to (but not after) the given date.
    Triggers a refresh if the cache is empty or stale.
    """
    _ensure_fresh(db)

    # Look for the most recent NAV <= target_date
    record = (
        db.query(RnitNavCache)
        .filter(RnitNavCache.nav_date <= target_date)
        .order_by(RnitNavCache.nav_date.desc())
        .first()
    )
    return record.nav_rwf if record else None


def get_latest_nav(db: Session) -> Optional[float]:
    """Return the most recent cached NAV, refreshing the cache if stale."""
    _ensure_fresh(db)
    record = db.query(RnitNavCache).order_by(RnitNavCache.nav_date.desc()).first()
    return record.nav_rwf if record else None


def get_nav_history(db: Session, limit: int = 90) -> List[Dict]:
    """Return recent NAV history as list of {date, nav} dicts."""
    _ensure_fresh(db)
    records = (
        db.query(RnitNavCache)
        .order_by(RnitNavCache.nav_date.desc())
        .limit(limit)
        .all()
    )
    return [
        {"date": r.nav_date.strftime("%Y-%m-%d"), "nav": r.nav_rwf}
        for r in records
    ]


def project_future_value(units: float, nav_now: float, years: float) -> float:
    """
    Project future RNIT value assuming compound annual growth of ~11%.
    """
    return units * nav_now * ((1 + RNIT_ANNUAL_GROWTH_PCT / 100) ** years)


# ── internal ────────────────────────────────────────────────────────────────

def _ensure_fresh(db: Session) -> None:
    """Re-scrape if cache is empty or the newest scraped_at is > CACHE_MAX_AGE_HOURS old."""
    newest = db.query(RnitNavCache).order_by(RnitNavCache.scraped_at.desc()).first()
    if newest is None:
        refresh_nav_cache(db)
        return
    age = datetime.utcnow() - newest.scraped_at.replace(tzinfo=None)
    if age > timedelta(hours=CACHE_MAX_AGE_HOURS):
        refresh_nav_cache(db)
