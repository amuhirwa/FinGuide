"""
Database Base Model
===================
SQLAlchemy declarative base and database session management.
"""

from sqlalchemy import create_engine, text as _text
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

from app.core.config import settings

# Create database engine
engine = create_engine(
    settings.DATABASE_URL,
    connect_args={"check_same_thread": False}  # SQLite specific
)

# Session factory
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Declarative base for models
Base = declarative_base()


def get_db():
    """
    Database session dependency.
    
    Yields:
        Session: SQLAlchemy database session
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db():
    """
    Initialize database tables.
    
    Creates all tables defined in the models.
    Also applies any incremental column migrations for SQLite.
    """
    Base.metadata.create_all(bind=engine)
    # ── SQLite column migrations ──────────────────────────────────────
    # Add columns that were introduced after initial table creation.
    _apply_column_migrations()


def _apply_column_migrations():
    """Run safe ALTER TABLE ADD COLUMN statements for new columns."""
    migrations = [
        "ALTER TABLE transactions ADD COLUMN linked_investment_id INTEGER REFERENCES investments(id)",
        "ALTER TABLE recommendations ADD COLUMN trigger_type VARCHAR(20)",
        "ALTER TABLE recommendations ADD COLUMN nudge_metadata JSON",
    ]
    with engine.connect() as conn:
        for sql in migrations:
            try:
                conn.execute(_text(sql))
                conn.commit()
            except Exception:
                # Column already exists — expected after first run
                pass
