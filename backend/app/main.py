"""
FinGuide Backend API
=====================
AI-Driven Financial Management Tool for Irregular Income Earners

This FastAPI application provides the backend services for the FinGuide
mobile application, including authentication, financial forecasting,
and personalized recommendations.
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from app.core.config import settings
from app.api.v1.router import api_router
from app.models.base import init_db
# Import all models to register them with SQLAlchemy
from app.models.user import User
from app.models.transaction import Transaction, CounterpartyMapping
from app.models.savings_goal import SavingsGoal, GoalContribution
from app.models.prediction import IncomePrediction, ExpensePrediction, FinancialHealthScore, Recommendation


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Lifespan context manager for startup and shutdown events.
    """
    # Startup
    print(f"🚀 Starting {settings.PROJECT_NAME} v{settings.VERSION}")
    print("📊 Initializing database...")
    init_db()
    print("✅ Database initialized")
    yield
    # Shutdown
    print(f"👋 Shutting down {settings.PROJECT_NAME}")


app = FastAPI(
    title=settings.PROJECT_NAME,
    description=settings.DESCRIPTION,
    version=settings.VERSION,
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
    lifespan=lifespan,
)

# CORS Configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins in development
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include API router
app.include_router(api_router, prefix=settings.API_V1_STR)


@app.get("/", tags=["Root"])
async def root():
    """
    Root endpoint - Welcome message.
    """
    return {
        "message": f"Welcome to {settings.PROJECT_NAME}",
        "version": settings.VERSION,
        "docs": "/docs",
    }


@app.get("/health", tags=["Health"])
async def health_check():
    """
    Health check endpoint for monitoring and load balancers.
    
    Returns:
        dict: Status information including service health and version.
    """
    return {
        "status": "healthy",
        "service": settings.PROJECT_NAME,
        "version": settings.VERSION,
        "environment": settings.ENVIRONMENT,
    }
