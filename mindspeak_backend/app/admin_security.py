from collections import defaultdict, deque
from datetime import datetime, timedelta, timezone
import hashlib
import hmac
import threading
import time

import jwt

from .config import Settings

ADMIN_AUDIENCE = "mindspeak-admin"
ADMIN_TOKEN_TYPE = "admin_access"
ADMIN_TOKEN_KEY_LABEL = b"MindSpeak admin access token v1"


def _admin_signing_key(settings: Settings) -> bytes:
    """Derive a distinct signing key so normal-user JWTs cannot be admin tokens."""
    base_key = settings.jwt_secret_key.get_secret_value().encode("utf-8")
    return hmac.new(base_key, ADMIN_TOKEN_KEY_LABEL, hashlib.sha256).digest()


def create_admin_access_token(admin_id: int, settings: Settings) -> str:
    now = datetime.now(timezone.utc)
    expires_at = now + timedelta(minutes=settings.access_token_expire_minutes)
    return jwt.encode(
        {
            "sub": str(admin_id),
            "aud": ADMIN_AUDIENCE,
            "typ": ADMIN_TOKEN_TYPE,
            "iat": now,
            "exp": expires_at,
        },
        _admin_signing_key(settings),
        algorithm=settings.jwt_algorithm,
    )


def read_admin_access_token(token: str, settings: Settings) -> int | None:
    try:
        payload = jwt.decode(
            token,
            _admin_signing_key(settings),
            algorithms=[settings.jwt_algorithm],
            audience=ADMIN_AUDIENCE,
            options={"require": ["exp", "iat", "sub", "aud", "typ"]},
        )
        if payload.get("typ") != ADMIN_TOKEN_TYPE:
            return None
        return int(payload["sub"])
    except (jwt.InvalidTokenError, KeyError, TypeError, ValueError):
        return None


class AdminLoginRateLimiter:
    """Small per-process IP limit for the local administrator login endpoint."""

    def __init__(self, *, max_attempts: int = 5, window_seconds: int = 900) -> None:
        self.max_attempts = max_attempts
        self.window_seconds = window_seconds
        self._attempts: dict[str, deque[float]] = defaultdict(deque)
        self._lock = threading.Lock()

    def _recent(self, key: str, now: float) -> deque[float]:
        attempts = self._attempts[key]
        while attempts and now - attempts[0] >= self.window_seconds:
            attempts.popleft()
        return attempts

    def is_limited(self, key: str) -> bool:
        now = time.monotonic()
        with self._lock:
            return len(self._recent(key, now)) >= self.max_attempts

    def record_failure(self, key: str) -> None:
        now = time.monotonic()
        with self._lock:
            attempts = self._recent(key, now)
            attempts.append(now)
            if len(self._attempts) > 4096:
                expired_keys = [
                    item_key
                    for item_key, item_attempts in self._attempts.items()
                    if not self._recent(item_key, now)
                ]
                for item_key in expired_keys:
                    self._attempts.pop(item_key, None)

    def clear(self, key: str) -> None:
        with self._lock:
            self._attempts.pop(key, None)
