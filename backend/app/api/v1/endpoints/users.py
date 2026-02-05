"""
User Endpoints
==============
User profile management endpoints.
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.models.base import get_db
from app.models.user import User
from app.schemas.user import UserResponse, TokenPayload
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
