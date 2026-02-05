"""
Dependencies Module
===================
FastAPI dependency injection utilities.
"""

from typing import Generator, Optional
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError

from app.core.security import decode_token
from app.schemas.user import TokenPayload

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")


async def get_current_user(token: str = Depends(oauth2_scheme)) -> TokenPayload:
    """
    Dependency to get the current authenticated user from JWT token.
    
    Args:
        token: JWT token from Authorization header
        
    Returns:
        TokenPayload: Decoded token payload with user information
        
    Raises:
        HTTPException: If token is invalid or expired
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    payload = decode_token(token)
    
    if payload is None:
        raise credentials_exception
    
    user_id: str = payload.get("sub")
    
    if user_id is None:
        raise credentials_exception
    
    return TokenPayload(sub=user_id, exp=payload.get("exp"))


async def get_current_active_user(
    current_user: TokenPayload = Depends(get_current_user)
) -> TokenPayload:
    """
    Dependency to ensure the current user is active.
    
    Args:
        current_user: Token payload from get_current_user
        
    Returns:
        TokenPayload: The current user's token payload
    """
    # In a full implementation, we would check if the user is active in the database
    return current_user
