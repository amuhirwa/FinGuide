"""
API v1 Router
=============
Main router aggregating all v1 API endpoints.
"""

from fastapi import APIRouter

from app.api.v1.endpoints import auth, users, transactions, savings_goals, predictions, investments, reports

api_router = APIRouter()

# Authentication endpoints
api_router.include_router(
    auth.router,
    prefix="/auth",
    tags=["Authentication"]
)

# User management endpoints
api_router.include_router(
    users.router,
    prefix="/users",
    tags=["Users"]
)

# Transaction endpoints
api_router.include_router(
    transactions.router,
    prefix="/transactions",
    tags=["Transactions"]
)

# Savings goals endpoints
api_router.include_router(
    savings_goals.router,
    prefix="/goals",
    tags=["Savings Goals"]
)

# Predictions & insights endpoints
api_router.include_router(
    predictions.router,
    prefix="/insights",
    tags=["Predictions & Insights"]
)

# Investments endpoints
api_router.include_router(
    investments.router,
    prefix="/investments",
    tags=["Investments"]
)

# Reports / Export endpoints
api_router.include_router(
    reports.router,
    prefix="/reports",
    tags=["Reports"]
)
