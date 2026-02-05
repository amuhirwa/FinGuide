"""
Authentication Endpoints
========================
User registration and login endpoints with JWT token generation.
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.models.base import get_db
from app.models.user import User, UbudheCategory as ModelUbudehe, IncomeFrequency as ModelIncomeFreq
from app.schemas.user import UserCreate, UserLogin, Token, UserResponse
from app.core.security import get_password_hash, verify_password, create_access_token

router = APIRouter()


@router.post(
    "/register",
    response_model=Token,
    status_code=status.HTTP_201_CREATED,
    summary="Register a new user",
    description="Create a new FinGuide account with phone number and financial profile."
)
async def register(
    user_data: UserCreate,
    db: Session = Depends(get_db)
) -> Token:
    """
    Register a new user account.
    
    Args:
        user_data: User registration data including phone, name, password,
                   ubudehe_category, and income_frequency
        db: Database session
        
    Returns:
        Token: JWT access token and user data
        
    Raises:
        HTTPException: If phone number is already registered
    """
    # Check if user already exists
    existing_user = db.query(User).filter(
        User.phone_number == user_data.phone_number
    ).first()
    
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Phone number already registered"
        )
    
    # Create new user
    new_user = User(
        phone_number=user_data.phone_number,
        full_name=user_data.full_name,
        hashed_password=get_password_hash(user_data.password),
        ubudehe_category=ModelUbudehe(user_data.ubudehe_category.value),
        income_frequency=ModelIncomeFreq(user_data.income_frequency.value),
    )
    
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    
    # Generate access token
    access_token = create_access_token(subject=new_user.id)
    
    return Token(
        access_token=access_token,
        token_type="bearer",
        user=UserResponse.model_validate(new_user)
    )


@router.post(
    "/login",
    response_model=Token,
    summary="User login",
    description="Authenticate with phone number and password to receive JWT token."
)
async def login(
    credentials: UserLogin,
    db: Session = Depends(get_db)
) -> Token:
    """
    Authenticate user and return JWT token.
    
    Args:
        credentials: Login credentials (phone_number and password)
        db: Database session
        
    Returns:
        Token: JWT access token and user data
        
    Raises:
        HTTPException: If credentials are invalid
    """
    # Find user by phone number
    user = db.query(User).filter(
        User.phone_number == credentials.phone_number
    ).first()
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid phone number or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # Verify password
    if not verify_password(credentials.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid phone number or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # Check if user is active
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is deactivated"
        )
    
    # Generate access token
    access_token = create_access_token(subject=user.id)
    
    return Token(
        access_token=access_token,
        token_type="bearer",
        user=UserResponse.model_validate(user)
    )
