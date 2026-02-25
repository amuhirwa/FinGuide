"""
Authentication Endpoints
========================
User registration and login endpoints with Twilio SMS-OTP verification and
JWT token generation.

Flow
----
1. Client calls POST /auth/send-otp   → Twilio delivers a 6-digit OTP via SMS.
2. Client calls POST /auth/verify-otp → returns a short-lived ``otp_token``.
3. Client calls POST /auth/register   → requires valid ``otp_token``; verifies
   the caller owns the phone before creating the account.
4. Client calls POST /auth/login      → same: requires ``otp_token`` before
   issuing a JWT session token.
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from twilio.base.exceptions import TwilioRestException

from app.models.base import get_db
from app.models.user import User, UbudheCategory as ModelUbudehe, IncomeFrequency as ModelIncomeFreq
from app.schemas.user import UserCreate, UserLogin, Token, UserResponse
from app.schemas.otp import SendOtpRequest, SendOtpResponse, VerifyOtpRequest, VerifyOtpResponse
from app.core.security import get_password_hash, verify_password, create_access_token
from app.core.otp_service import create_and_send_otp, verify_otp_code, create_otp_token, verify_otp_token

router = APIRouter()


# ---------------------------------------------------------------------------
# OTP Endpoints
# ---------------------------------------------------------------------------

@router.post(
    "/send-otp",
    response_model=SendOtpResponse,
    status_code=status.HTTP_200_OK,
    summary="Send SMS OTP",
    description=(
        "Send a 6-digit one-time password via Twilio SMS to the supplied phone "
        "number. Call this before /auth/register or /auth/login."
    ),
)
async def send_otp(
    request: SendOtpRequest,
    db: Session = Depends(get_db),
) -> SendOtpResponse:
    """
    Generate and SMS-deliver an OTP to *phone_number*.

    Raises:
        HTTPException 503: If the Twilio SMS delivery fails.
    """
    try:
        create_and_send_otp(db, request.phone_number)
    except TwilioRestException as exc:
        print(f"Twilio error: {exc.msg}")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Could not send OTP SMS: {exc.msg}",
        )
    except Exception as exc:
        print(f"Unexpected error: {exc}")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"SMS delivery failed: {str(exc)}",
        )

    return SendOtpResponse(message="OTP sent to your phone. It expires in 5 minutes.")


@router.post(
    "/verify-otp",
    response_model=VerifyOtpResponse,
    status_code=status.HTTP_200_OK,
    summary="Verify SMS OTP",
    description=(
        "Verify the 6-digit OTP received via SMS. On success, returns a short-lived "
        "`otp_token` JWT that must be supplied to /auth/register or /auth/login."
    ),
)
async def verify_otp(
    request: VerifyOtpRequest,
    db: Session = Depends(get_db),
) -> VerifyOtpResponse:
    """
    Check *otp_code* for *phone_number*.

    Raises:
        HTTPException 400: If the code is wrong, expired, or already used.
    """
    valid = verify_otp_code(db, request.phone_number, request.otp_code)
    if not valid:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired OTP code. Request a new one.",
        )

    otp_token = create_otp_token(request.phone_number)
    return VerifyOtpResponse(
        otp_token=otp_token,
        message="Phone number verified successfully.",
    )


# ---------------------------------------------------------------------------
# Register
# ---------------------------------------------------------------------------

@router.post(
    "/register",
    response_model=Token,
    status_code=status.HTTP_201_CREATED,
    summary="Register a new user",
    description=(
        "Create a new FinGuide account. Requires a valid `otp_token` obtained "
        "from POST /auth/verify-otp, proving ownership of the phone number."
    ),
)
async def register(
    user_data: UserCreate,
    db: Session = Depends(get_db),
) -> Token:
    """
    Register a new user account.

    Args:
        user_data: Registration payload including phone, name, password,
                   ubudehe_category, income_frequency, and otp_token.
        db: Database session.

    Returns:
        Token: JWT access token and user data.

    Raises:
        HTTPException 400: If the otp_token is invalid/expired, phone mismatch,
                           or phone is already registered.
    """
    # Verify OTP token – proves the caller received the SMS on this number
    try:
        verified_phone = verify_otp_token(user_data.otp_token)
    except ValueError as exc:
        print(f"[register] otp_token decode FAILED: {exc}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        )

    print(f"[register] verified_phone={repr(verified_phone)} | user_data.phone_number={repr(user_data.phone_number)}")

    if verified_phone != user_data.phone_number:
        detail = "OTP token phone number does not match registration phone number."
        print(f"[register] MISMATCH → {detail}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=detail,
        )

    # Check uniqueness
    existing_user = db.query(User).filter(
        User.phone_number == user_data.phone_number
    ).first()
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Phone number already registered.",
        )

    # Create user
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

    access_token = create_access_token(subject=new_user.id)
    return Token(
        access_token=access_token,
        token_type="bearer",
        user=UserResponse.model_validate(new_user),
    )


# ---------------------------------------------------------------------------
# Login
# ---------------------------------------------------------------------------

@router.post(
    "/login",
    response_model=Token,
    summary="User login",
    description=(
        "Authenticate with phone number, password, and a valid `otp_token` "
        "from /auth/verify-otp. Returns a JWT session token."
    ),
)
async def login(
    credentials: UserLogin,
    db: Session = Depends(get_db),
) -> Token:
    """
    Authenticate user and return JWT token.

    Args:
        credentials: Login payload (phone_number, password, otp_token).
        db: Database session.

    Returns:
        Token: JWT access token and user data.

    Raises:
        HTTPException 400: If otp_token is invalid/expired or phone mismatch.
        HTTPException 401: If credentials are wrong.
        HTTPException 403: If account is deactivated.
    """
    # Verify OTP token
    try:
        verified_phone = verify_otp_token(credentials.otp_token)
    except ValueError as exc:
        print(f"[login] otp_token decode FAILED: {exc}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        )

    print(f"[login] verified_phone={repr(verified_phone)} | credentials.phone_number={repr(credentials.phone_number)}")

    if verified_phone != credentials.phone_number:
        detail = "OTP token phone number does not match login phone number."
        print(f"[login] MISMATCH → {detail}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=detail,
        )

    # Find user
    user = db.query(User).filter(
        User.phone_number == credentials.phone_number
    ).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid phone number or password.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Verify password
    if not verify_password(credentials.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid phone number or password.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Check active
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is deactivated.",
        )

    access_token = create_access_token(subject=user.id)
    return Token(
        access_token=access_token,
        token_type="bearer",
        user=UserResponse.model_validate(user),
    )
