"""Long-lived app sign-ins (refresh tokens) so users are not asked for the password every time.

The app keeps a short-lived JWT access token for API calls and a refresh token in secure
storage. When the access token expires, the app trades the refresh token for a new pair.
Tokens are random, stored only as keyed hashes, rotated on every use, and revoked on
logout and password reset.
"""

from datetime import datetime, timedelta, timezone
import hashlib
import hmac
import secrets

from fastapi import HTTPException, status
from sqlalchemy import select, update
from sqlalchemy.orm import Session

from .config import Settings
from .models import RefreshToken, User

_INVALID = {
    "code": "refresh_token_invalid",
    "message": "Your session has ended. Please log in again.",
}


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _as_utc(value: datetime) -> datetime:
    return value if value.tzinfo else value.replace(tzinfo=timezone.utc)


def hash_refresh_token(token: str, settings: Settings) -> str:
    # Domain-separated from reset-code hashes so the two can never be swapped.
    return hmac.new(
        settings.jwt_secret_key.get_secret_value().encode("utf-8"),
        b"mindspeak-refresh-token:" + token.encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()


def issue_refresh_token(
    session: Session, user_id: int, settings: Settings, family_id: str | None = None
) -> str:
    """Add a new refresh token row (the caller commits) and return the raw token once."""
    raw = secrets.token_urlsafe(48)
    session.add(
        RefreshToken(
            user_id=user_id,
            token_hash=hash_refresh_token(raw, settings),
            family_id=family_id or secrets.token_hex(16),
            expires_at=_utcnow() + timedelta(days=settings.refresh_token_expire_days),
        )
    )
    return raw


def _revoke_family(session: Session, family_id: str, now: datetime) -> None:
    session.execute(
        update(RefreshToken)
        .where(RefreshToken.family_id == family_id, RefreshToken.revoked_at.is_(None))
        .values(revoked_at=now)
    )


def rotate_refresh_token(session: Session, raw: str, settings: Settings) -> tuple[int, str]:
    """Spend a refresh token and return (user_id, new raw token). Commits."""
    now = _utcnow()
    record = session.scalar(
        select(RefreshToken).where(RefreshToken.token_hash == hash_refresh_token(raw, settings))
    )
    if record is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=_INVALID)
    if record.revoked_at is not None:
        # A spent token came back: someone else may hold a copy. End the whole sign-in.
        _revoke_family(session, record.family_id, now)
        session.commit()
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=_INVALID)
    if _as_utc(record.expires_at) <= now or session.get(User, record.user_id) is None:
        record.revoked_at = now
        session.commit()
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=_INVALID)

    record.revoked_at = now
    new_raw = issue_refresh_token(session, record.user_id, settings, family_id=record.family_id)
    session.commit()
    return record.user_id, new_raw


def revoke_refresh_token(session: Session, raw: str, settings: Settings) -> None:
    """Log out this device. Unknown or already-revoked tokens are ignored. Commits."""
    record = session.scalar(
        select(RefreshToken).where(RefreshToken.token_hash == hash_refresh_token(raw, settings))
    )
    if record is not None:
        _revoke_family(session, record.family_id, _utcnow())
        session.commit()


def revoke_all_for_user(session: Session, user_id: int) -> None:
    """End every app sign-in for a user, for example after a password reset. Caller commits."""
    session.execute(
        update(RefreshToken)
        .where(RefreshToken.user_id == user_id, RefreshToken.revoked_at.is_(None))
        .values(revoked_at=_utcnow())
    )
