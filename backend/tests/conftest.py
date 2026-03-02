"""
Shared pytest fixtures for the FinGuide test suite.

Provides:
  - An in-memory SQLite database session (isolated per test)
  - A FastAPI TestClient wired to that session
  - Factory helpers for users, transactions, recommendations
  - A pre-authenticated JWT token / auth header
"""

import os
import pytest
from datetime import datetime, timedelta
from typing import Generator

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session

# ── Override env vars BEFORE importing any app code ──────────────────────────
os.environ.setdefault("SMS_USERNAME", "test_user")
os.environ.setdefault("SMS_PASSWORD", "test_pass")
os.environ.setdefault("SMS_AUTH", "http://localhost/auth")
os.environ.setdefault("SMS_SEND", "http://localhost/send")
os.environ.setdefault("ANTHROPIC_API_KEY", "")
os.environ.setdefault("SECRET_KEY", "test-secret-key-for-pytest-only")

from app.main import app
from app.models.base import Base, get_db
from app.models.user import User, UbudheCategory, IncomeFrequency
from app.models.transaction import Transaction, TransactionType, TransactionCategory, NeedWantCategory
from app.models.savings_goal import SavingsGoal, GoalStatus
from app.models.prediction import Recommendation
from app.core.security import get_password_hash, create_access_token

# ── In-memory test database ───────────────────────────────────────────────────
TEST_DATABASE_URL = "sqlite:///:memory:"

test_engine = create_engine(
    TEST_DATABASE_URL,
    connect_args={"check_same_thread": False},
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=test_engine)


@pytest.fixture(scope="session", autouse=True)
def create_tables():
    """Create all tables once per test session."""
    Base.metadata.create_all(bind=test_engine)
    yield
    Base.metadata.drop_all(bind=test_engine)


@pytest.fixture
def db() -> Generator[Session, None, None]:
    """
    Yield a fresh database session for each test, then roll back.
    Keeps tests hermetic.
    """
    connection = test_engine.connect()
    transaction = connection.begin()
    session = TestingSessionLocal(bind=connection)

    yield session

    session.close()
    transaction.rollback()
    connection.close()


@pytest.fixture
def client(db: Session) -> TestClient:
    """FastAPI TestClient with the test DB injected."""
    def override_get_db():
        yield db

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()


# ── Data factories ────────────────────────────────────────────────────────────

@pytest.fixture
def test_user(db: Session) -> User:
    """Create and persist a test user."""
    user = User(
        phone_number="0781234567",
        full_name="Test User",
        hashed_password=get_password_hash("password123"),
        ubudehe_category=UbudheCategory.CATEGORY_2,
        income_frequency=IncomeFrequency.IRREGULAR,
        is_active=True,
        is_verified=True,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@pytest.fixture
def auth_token(test_user: User) -> str:
    """JWT access token for the test user."""
    return create_access_token(subject=str(test_user.id))


@pytest.fixture
def auth_headers(auth_token: str) -> dict:
    """Authorization header dict for authenticated requests."""
    return {"Authorization": f"Bearer {auth_token}"}


@pytest.fixture
def sample_income_transaction(db: Session, test_user: User) -> Transaction:
    tx = Transaction(
        user_id=test_user.id,
        transaction_type=TransactionType.INCOME,
        category=TransactionCategory.OTHER_INCOME,
        need_want=NeedWantCategory.UNCATEGORIZED,
        amount=50000.0,
        description="Test income",
        counterparty="John Doe",
        transaction_date=datetime.now() - timedelta(days=1),
        confidence_score=0.9,
        is_verified=False,
    )
    db.add(tx)
    db.commit()
    db.refresh(tx)
    return tx


@pytest.fixture
def sample_expense_transaction(db: Session, test_user: User) -> Transaction:
    tx = Transaction(
        user_id=test_user.id,
        transaction_type=TransactionType.EXPENSE,
        category=TransactionCategory.FOOD_GROCERIES,
        need_want=NeedWantCategory.NEED,
        amount=5000.0,
        description="Groceries",
        counterparty="Market",
        transaction_date=datetime.now() - timedelta(days=2),
        confidence_score=0.85,
        is_verified=False,
    )
    db.add(tx)
    db.commit()
    db.refresh(tx)
    return tx


@pytest.fixture
def sample_recommendation(db: Session, test_user: User) -> Recommendation:
    rec = Recommendation(
        user_id=test_user.id,
        title="Save 5000 RWF today",
        message="You received income. Save 10% now while you have it!",
        recommendation_type="savings",
        action_type="save",
        action_amount=5000.0,
        urgency="high",
        trigger_type="income",
        is_active=True,
        valid_until=datetime.now() + timedelta(days=1),
    )
    db.add(rec)
    db.commit()
    db.refresh(rec)
    return rec


@pytest.fixture
def sample_savings_goal(db: Session, test_user: User) -> SavingsGoal:
    goal = SavingsGoal(
        user_id=test_user.id,
        name="Emergency Fund",
        target_amount=100000.0,
        current_amount=20000.0,
        status=GoalStatus.ACTIVE,
        daily_target=500.0,
        weekly_target=3500.0,
        deadline=datetime.now() + timedelta(days=180),
    )
    db.add(goal)
    db.commit()
    db.refresh(goal)
    return goal
