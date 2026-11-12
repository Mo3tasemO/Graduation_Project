from datetime import datetime, timedelta, timezone
import secrets
import smtplib
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import delete, func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .config import Settings
from .mailer import (
    EmailNotConfiguredError,
    ensure_email_configured,
    send_email_verification_code,
    send_password_reset_code,
)
from .models import PasswordResetChallenge, PendingEmailVerification, User
from .schemas import (
    ForgotPasswordRequest,
    LoginRequest,
    LoginResponse,
    MessageResponse,
    PendingRegisterResponse,
    RegisterRequest,
    RegisterResponse,
    ResetPasswordRequest,
    UserResponse,
    VerifyEmailRequest,
    VerifyResetCodeRequest,
    VerifyResetCodeResponse,
)
from .security import (
    create_access_token,
    hash_password,
    hash_reset_secret,
    read_access_token,
    verify_password,
)

router = APIRouter(prefix="/api/v1", tags=["API v1"])
bearer_scheme = HTTPBearer(auto_error=False)
RESET_CODE_TTL = timedelta(minutes=5)
RESET_TOKEN_TTL = timedelta(minutes=10)
CODE_REQUEST_COOLDOWN = timedelta(seconds=60)
CODE_REQUESTS_PER_HOUR = 3
CODE_MAX_ATTEMPTS = 5
EMAIL_VERIFICATION_TTL = timedelta(minutes=5)
PENDING_REGISTRATION_TTL = timedelta(hours=24)


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _as_utc(value: datetime) -> datetime:
    # SQLite returns timezone-aware columns as naive datetimes.
    return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value.astimezone(timezone.utc)


def _check_email_configuration(settings: Settings) -> None:
    try:
        ensure_email_configured(settings)
    except EmailNotConfiguredError:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={"code": "email_not_configured", "message": "Email delivery is not configured on this server."},
        ) from None


def _deliver_code(send_code, email: str, code: str, settings: Settings, purpose: str) -> None:
    try:
        send_code(email, code, settings)
    except EmailNotConfiguredError:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={"code": "email_not_configured", "message": "Email delivery is not configured on this server."},
        ) from None
    except (OSError, smtplib.SMTPException):
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={"code": "email_delivery_failed", "message": f"The {purpose} email could not be sent. Try again later."},
        ) from None


def _registration_request_window(
    pending: PendingEmailVerification | None,
    now: datetime,
) -> tuple[datetime, int]:
    if pending is None:
        return now, 1
    last_requested = _as_utc(pending.requested_at)
    if now - last_requested < CODE_REQUEST_COOLDOWN:
        raise HTTPException(
            status_code=429,
            detail={"code": "verification_cooldown", "message": "Wait 60 seconds before requesting another verification code."},
        )
    window_started = _as_utc(pending.window_started_at)
    if now - window_started >= timedelta(hours=1):
        return now, 1
    if pending.request_count >= CODE_REQUESTS_PER_HOUR:
        raise HTTPException(
            status_code=429,
            detail={"code": "verification_rate_limited", "message": "Too many verification requests. Try again later."},
        )
    return window_started, pending.request_count + 1


def _clean_stale_registrations(session: Session, now: datetime) -> None:
    session.execute(
        delete(PendingEmailVerification).where(
            PendingEmailVerification.created_at < now - PENDING_REGISTRATION_TTL
        )
    )


def get_session(request: Request):
    session_factory = request.app.state.session_factory
    with session_factory() as session:
        yield session


def get_current_user(
    request: Request,
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer_scheme)],
    session: Annotated[Session, Depends(get_session)],
) -> User:
    unauthorized = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail={"code": "not_authenticated", "message": "A valid bearer token is required."},
        headers={"WWW-Authenticate": "Bearer"},
    )
    if credentials is None:
        raise unauthorized

    settings: Settings = request.app.state.settings
    user_id = read_access_token(credentials.credentials, settings)
    if user_id is None:
        raise unauthorized

    user = session.get(User, user_id)
    if user is None or user.email_verified_at is None:
        raise unauthorized
    return user


@router.post(
    "/auth/register",
    response_model=PendingRegisterResponse,
    status_code=status.HTTP_202_ACCEPTED,
    summary="Begin email-verified account registration",
)
def register(
    payload: RegisterRequest,
    request: Request,
    session: Annotated[Session, Depends(get_session)],
) -> PendingRegisterResponse:
    existing_user = session.scalar(select(User).where(func.lower(User.email) == payload.email))
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={"code": "email_already_registered", "message": "An account with this email already exists."},
        )

    settings: Settings = request.app.state.settings
    _check_email_configuration(settings)
    now = _utcnow()
    _clean_stale_registrations(session, now)
    pending = session.scalar(
        select(PendingEmailVerification).where(PendingEmailVerification.email == payload.email)
    )
    window_started, request_count = _registration_request_window(pending, now)
    code = f"{secrets.randbelow(1_000_000):06d}"
    _deliver_code(send_email_verification_code, payload.email, code, settings, "verification")

    if pending is None:
        pending = PendingEmailVerification(
            name=payload.name,
            email=payload.email,
            password_hash=hash_password(payload.password),
            code_hash=hash_reset_secret(code, settings),
            requested_at=now,
            window_started_at=window_started,
            request_count=request_count,
            expires_at=now + EMAIL_VERIFICATION_TTL,
            attempts=0,
        )
        session.add(pending)
    else:
        pending.name = payload.name
        pending.password_hash = hash_password(payload.password)
        pending.code_hash = hash_reset_secret(code, settings)
        pending.requested_at = now
        pending.window_started_at = window_started
        pending.request_count = request_count
        pending.expires_at = now + EMAIL_VERIFICATION_TTL
        pending.attempts = 0
    try:
        session.commit()
    except IntegrityError:
        session.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={"code": "email_already_registered", "message": "An account with this email already exists."},
        ) from None
    return PendingRegisterResponse(
        email=payload.email,
        message="We've sent a verification code to your email address. It expires in 5 minutes.",
    )


@router.post(
    "/auth/verify-email",
    response_model=RegisterResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Verify an email and finish account creation",
)
def verify_email(
    payload: VerifyEmailRequest,
    request: Request,
    session: Annotated[Session, Depends(get_session)],
) -> RegisterResponse:
    pending = session.scalar(
        select(PendingEmailVerification).where(PendingEmailVerification.email == payload.email)
    )
    if pending is None:
        raise HTTPException(
            status_code=400,
            detail={"code": "verification_not_found", "message": "No pending registration was found. Start again."},
        )
    now = _utcnow()
    if _as_utc(pending.created_at) < now - PENDING_REGISTRATION_TTL:
        session.delete(pending)
        session.commit()
        raise HTTPException(
            status_code=410,
            detail={"code": "verification_registration_expired", "message": "This pending registration expired. Start again."},
        )
    if _as_utc(pending.expires_at) <= now:
        raise HTTPException(
            status_code=410,
            detail={"code": "verification_code_expired", "message": "The code has expired. Request a new one."},
        )
    if pending.attempts >= CODE_MAX_ATTEMPTS:
        raise HTTPException(
            status_code=429,
            detail={"code": "verification_attempts_exhausted", "message": "Too many incorrect codes. Request a new code later."},
        )

    settings: Settings = request.app.state.settings
    pending.attempts += 1
    expected = hash_reset_secret(payload.code, settings)
    if not secrets.compare_digest(pending.code_hash, expected):
        session.commit()
        raise HTTPException(
            status_code=400,
            detail={"code": "verification_code_invalid", "message": "That verification code is incorrect."},
        )

    existing_user = session.scalar(select(User).where(func.lower(User.email) == payload.email))
    if existing_user is not None:
        session.delete(pending)
        session.commit()
        raise HTTPException(
            status_code=409,
            detail={"code": "email_already_registered", "message": "An account with this email already exists."},
        )

    user = User(
        name=pending.name,
        email=pending.email,
        password_hash=pending.password_hash,
        email_verified_at=now,
    )
    session.add(user)
    session.delete(pending)
    try:
        session.commit()
    except IntegrityError:
        session.rollback()
        raise HTTPException(
            status_code=409,
            detail={"code": "email_already_registered", "message": "An account with this email already exists."},
        ) from None
    session.refresh(user)
    return RegisterResponse(
        user=UserResponse.model_validate(user),
        access_token=create_access_token(user.id, settings),
    )


@router.post(
    "/auth/resend-verification-code",
    response_model=MessageResponse,
    status_code=status.HTTP_202_ACCEPTED,
    summary="Resend a pending registration verification code",
)
def resend_verification_code(
    payload: ForgotPasswordRequest,
    request: Request,
    session: Annotated[Session, Depends(get_session)],
) -> MessageResponse:
    if session.scalar(select(User).where(func.lower(User.email) == payload.email)) is not None:
        raise HTTPException(
            status_code=409,
            detail={"code": "email_already_registered", "message": "An account with this email already exists."},
        )
    pending = session.scalar(
        select(PendingEmailVerification).where(PendingEmailVerification.email == payload.email)
    )
    if pending is not None and _as_utc(pending.created_at) < _utcnow() - PENDING_REGISTRATION_TTL:
        session.delete(pending)
        session.commit()
        pending = None
    if pending is None:
        raise HTTPException(
            status_code=404,
            detail={"code": "verification_not_found", "message": "No pending registration was found. Start again."},
        )

    settings: Settings = request.app.state.settings
    _check_email_configuration(settings)
    now = _utcnow()
    window_started, request_count = _registration_request_window(pending, now)
    code = f"{secrets.randbelow(1_000_000):06d}"
    _deliver_code(send_email_verification_code, payload.email, code, settings, "verification")
    pending.code_hash = hash_reset_secret(code, settings)
    pending.requested_at = now
    pending.window_started_at = window_started
    pending.request_count = request_count
    pending.expires_at = now + EMAIL_VERIFICATION_TTL
    pending.attempts = 0
    session.commit()
    return MessageResponse(message="If this registration is still pending, a new verification code has been sent.")


@router.post(
    "/auth/login",
    response_model=LoginResponse,
    summary="Log in and receive an access token",
)
def login(
    payload: LoginRequest,
    request: Request,
    session: Annotated[Session, Depends(get_session)],
) -> LoginResponse:
    user = session.scalar(
        select(User).where(
            func.lower(User.email) == payload.email,
            User.email_verified_at.is_not(None),
        )
    )
    if user is None or not verify_password(payload.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"code": "invalid_credentials", "message": "Email or password is incorrect."},
            headers={"WWW-Authenticate": "Bearer"},
        )

    settings: Settings = request.app.state.settings
    token = create_access_token(user.id, settings)
    return LoginResponse(access_token=token, user=UserResponse.model_validate(user))


@router.get(
    "/me",
    response_model=UserResponse,
    summary="Get the signed-in user's basic profile",
)
def get_me(
    current_user: Annotated[User, Depends(get_current_user)],
) -> UserResponse:
    return UserResponse.model_validate(current_user)


@router.post(
    "/auth/forgot-password",
    response_model=MessageResponse,
    status_code=status.HTTP_202_ACCEPTED,
    summary="Request a password reset email",
)
def forgot_password(
    payload: ForgotPasswordRequest,
    request: Request,
    session: Annotated[Session, Depends(get_session)],
) -> MessageResponse:
    generic = MessageResponse(
        message="If an account exists for that email, a verification code has been sent."
    )
    settings: Settings = request.app.state.settings
    _check_email_configuration(settings)
    user = session.scalar(
        select(User).where(
            func.lower(User.email) == payload.email,
            User.email_verified_at.is_not(None),
        )
    )
    if user is None:
        return generic

    now = _utcnow()
    recent = list(
        session.scalars(
            select(PasswordResetChallenge)
            .where(
                PasswordResetChallenge.email == payload.email,
                PasswordResetChallenge.requested_at >= now - timedelta(hours=1),
            )
            .order_by(PasswordResetChallenge.requested_at.desc())
        )
    )
    if recent and now - _as_utc(recent[0].requested_at) < CODE_REQUEST_COOLDOWN:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail={"code": "reset_cooldown", "message": "Wait 60 seconds before requesting another code."},
        )
    if len(recent) >= CODE_REQUESTS_PER_HOUR:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail={"code": "reset_rate_limited", "message": "Too many reset requests. Try again later."},
        )

    code = f"{secrets.randbelow(1_000_000):06d}"
    challenge = PasswordResetChallenge(
        email=payload.email,
        code_hash=hash_reset_secret(code, settings),
        requested_at=now,
        expires_at=now + RESET_CODE_TTL,
    )
    session.add(challenge)
    session.commit()
    try:
        send_password_reset_code(payload.email, code, settings)
    except EmailNotConfiguredError:
        session.delete(challenge)
        session.commit()
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={"code": "email_not_configured", "message": "Password reset email is not configured on this server."},
        ) from None
    except (OSError, smtplib.SMTPException):
        session.delete(challenge)
        session.commit()
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={"code": "email_delivery_failed", "message": "The reset email could not be sent. Try again later."},
        ) from None
    return generic


@router.post(
    "/auth/verify-reset-code",
    response_model=VerifyResetCodeResponse,
    summary="Verify the password reset code",
)
def verify_reset_code(
    payload: VerifyResetCodeRequest,
    request: Request,
    session: Annotated[Session, Depends(get_session)],
) -> VerifyResetCodeResponse:
    challenge = session.scalar(
        select(PasswordResetChallenge)
        .where(
            PasswordResetChallenge.email == payload.email,
            PasswordResetChallenge.used_at.is_(None),
        )
        .order_by(PasswordResetChallenge.requested_at.desc())
    )
    now = _utcnow()
    if challenge is None or challenge.verified_at is not None:
        raise HTTPException(
            status_code=400,
            detail={"code": "reset_code_invalid", "message": "The code is invalid or has expired. Request a new one."},
        )
    if _as_utc(challenge.expires_at) <= now:
        raise HTTPException(
            status_code=400,
            detail={"code": "reset_code_expired", "message": "The code has expired. Request a new one."},
        )
    if challenge.attempts >= CODE_MAX_ATTEMPTS:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail={"code": "reset_attempts_exhausted", "message": "Too many incorrect codes. Request a new code later."},
        )

    challenge.attempts += 1
    expected_hash = hash_reset_secret(payload.code, request.app.state.settings)
    if not secrets.compare_digest(challenge.code_hash, expected_hash):
        session.commit()
        raise HTTPException(
            status_code=400,
            detail={"code": "reset_code_invalid", "message": "That verification code is incorrect."},
        )

    challenge.verified_at = now
    reset_token = secrets.token_urlsafe(32)
    challenge.reset_token_hash = hash_reset_secret(reset_token, request.app.state.settings)
    challenge.reset_token_expires_at = now + RESET_TOKEN_TTL
    session.commit()
    return VerifyResetCodeResponse(reset_token=reset_token, expires_in=int(RESET_TOKEN_TTL.total_seconds()))


@router.post(
    "/auth/reset-password",
    response_model=MessageResponse,
    summary="Save a new password after code verification",
)
def reset_password(
    payload: ResetPasswordRequest,
    request: Request,
    session: Annotated[Session, Depends(get_session)],
) -> MessageResponse:
    challenge = session.scalar(
        select(PasswordResetChallenge)
        .where(
            PasswordResetChallenge.email == payload.email,
            PasswordResetChallenge.used_at.is_(None),
            PasswordResetChallenge.verified_at.is_not(None),
        )
        .order_by(PasswordResetChallenge.requested_at.desc())
    )
    now = _utcnow()
    if (
        challenge is None
        or challenge.reset_token_hash is None
        or challenge.reset_token_expires_at is None
        or _as_utc(challenge.reset_token_expires_at) <= now
        or not secrets.compare_digest(
            challenge.reset_token_hash,
            hash_reset_secret(payload.reset_token, request.app.state.settings),
        )
    ):
        raise HTTPException(
            status_code=400,
            detail={"code": "reset_token_invalid", "message": "Password reset verification has expired. Start again."},
        )

    user = session.scalar(select(User).where(func.lower(User.email) == payload.email))
    if user is None:
        raise HTTPException(status_code=400, detail={"code": "reset_token_invalid", "message": "Password reset verification has expired. Start again."})
    user.password_hash = hash_password(payload.new_password)
    challenge.used_at = now
    # Any older pending codes for this email become unusable after the reset.
    older = session.scalars(
        select(PasswordResetChallenge).where(
            PasswordResetChallenge.email == payload.email,
            PasswordResetChallenge.id != challenge.id,
            PasswordResetChallenge.used_at.is_(None),
        )
    )
    for item in older:
        item.used_at = now
    session.commit()
    return MessageResponse(message="Password updated. You can now log in with your new password.")
