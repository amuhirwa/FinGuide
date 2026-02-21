"""
User Endpoints
==============
User profile management endpoints.
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.models.base import get_db
from app.models.user import User
from app.schemas.user import UserResponse, UserUpdate, TokenPayload
from app.core.deps import get_current_active_user

router = APIRouter()


@router.get(
    "/me",
    response_model=UserResponse,
    summary="Get current user profile",
    description="Retrieve the authenticated user's profile information."
)
async def get_current_user_profile(
    current_user: TokenPayload = Depends(get_current_active_user),
    db: Session = Depends(get_db)
) -> UserResponse:
    """
    Get the current authenticated user's profile.
    
    Args:
        current_user: Token payload with user ID
        db: Database session
        
    Returns:
        UserResponse: User profile data
        
    Raises:
        HTTPException: If user not found
    """
    user = db.query(User).filter(User.id == int(current_user.sub)).first()
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    return UserResponse.model_validate(user)


@router.patch(
    "/me",
    response_model=UserResponse,
    summary="Update current user profile",
    description="Update the authenticated user's profile information."
)
async def update_current_user_profile(
    user_update: UserUpdate,
    current_user: TokenPayload = Depends(get_current_active_user),
    db: Session = Depends(get_db)
) -> UserResponse:
    """
    Update the current authenticated user's profile.
    
    Args:
        user_update: Fields to update (all optional)
        current_user: Token payload with user ID
        db: Database session
        
    Returns:
        UserResponse: Updated user profile data
        
    Raises:
        HTTPException: If user not found
    """
    user = db.query(User).filter(User.id == int(current_user.sub)).first()
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    # Update only provided fields
    update_data = user_update.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(user, field, value)
    
    db.commit()
    db.refresh(user)
    
    return UserResponse.model_validate(user)
