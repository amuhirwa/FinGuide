"""
Application Configuration
=========================
Centralized configuration management using Pydantic Settings.
"""

from typing import List
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """
    Application settings loaded from environment variables.
    
    Attributes:
        PROJECT_NAME: Name of the application
        VERSION: Current API version
        DESCRIPTION: API description for documentation
        API_V1_STR: API version prefix
        SECRET_KEY: JWT secret key for token signing
        ALGORITHM: JWT signing algorithm
        ACCESS_TOKEN_EXPIRE_MINUTES: Token expiration time
        BACKEND_CORS_ORIGINS: Allowed CORS origins
        DATABASE_URL: Database connection string
        ENVIRONMENT: Current environment (development/staging/production)
    """
    
    # Project Information
    PROJECT_NAME: str = "FinGuide API"
    VERSION: str = "1.0.0"
    DESCRIPTION: str = "AI-Driven Financial Advisor for Rwandan Youth"
    API_V1_STR: str = "/api/v1"
    
    # Security
    SECRET_KEY: str = "finguide-secret-key-change-in-production-2026"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 days
    
    # CORS - Allow all origins in development
    BACKEND_CORS_ORIGINS: List[str] = [
        "http://localhost",
        "http://localhost:3000",
        "http://localhost:8080",
        "http://localhost:56163",
        "http://127.0.0.1",
        "http://127.0.0.1:3000",
        "http://127.0.0.1:8080",
        "http://10.0.2.2:8000",
        "*",  # Allow all origins in development
    ]
    
    # Database
    DATABASE_URL: str = "sqlite:///./finguide.db"
    
    # Environment
    ENVIRONMENT: str = "development"
    
    class Config:
        env_file = ".env"
        case_sensitive = True


settings = Settings()
