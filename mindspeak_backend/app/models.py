from datetime import datetime, timezone
import secrets

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from .database import Base


USER_CODE_MIN = 1_000_000
USER_CODE_MAX = 9_999_999


def random_user_code() -> int:
    """A random 7-digit number (1000000-9999999) shown to users as their User ID."""
    return USER_CODE_MIN + secrets.randbelow(USER_CODE_MAX - USER_CODE_MIN + 1)


class User(Base):
    """A registered MindSpeak account. The password column stores only a hash."""

    __tablename__ = "users"

    # Internal key used by every other table. Never shown to users.
    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    # The User ID people see: 7 random digits, unique, and never changes.
    user_code: Mapped[int] = mapped_column(
        Integer, unique=True, index=True, nullable=False, default=random_user_code
    )
    name: Mapped[str] = mapped_column(String(80), nullable=False)
    email: Mapped[str] = mapped_column(String(254), unique=True, index=True, nullable=False)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    email_verified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    age: Mapped[int | None] = mapped_column(Integer)
    medical_information: Mapped[str | None] = mapped_column(Text)
    avatar_data: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )


class AdminAccount(Base):
    """A separately provisioned administrator, never a normal app user."""

    __tablename__ = "admin_accounts"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    email: Mapped[str] = mapped_column(String(254), unique=True, index=True, nullable=False)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )


class PendingEmailVerification(Base):
    """Registration state that is promoted to User only after code verification."""

    __tablename__ = "pending_email_verifications"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String(80), nullable=False)
    email: Mapped[str] = mapped_column(String(254), unique=True, index=True, nullable=False)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    code_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
    requested_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    window_started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    request_count: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    attempts: Mapped[int] = mapped_column(Integer, default=0, nullable=False)


class PasswordResetChallenge(Base):
    """Short-lived reset-code state. Only keyed hashes of secrets are stored."""

    __tablename__ = "password_reset_challenges"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    email: Mapped[str] = mapped_column(String(254), index=True, nullable=False)
    code_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    requested_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    attempts: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    verified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    reset_token_hash: Mapped[str | None] = mapped_column(String(64))
    reset_token_expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    used_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class CustomPhrase(Base):
    """A phrase owned by one user; phrase text is never shared across accounts."""

    __tablename__ = "custom_phrases"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    text: Mapped[str] = mapped_column(String(100), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False
    )


class MessageHistory(Base):
    """A short, private history of messages successfully sent to speech."""

    __tablename__ = "message_history"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    text: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False
    )


class SpeechPreference(Base):
    """The user's speech options; voice choices are supplied by the client device."""

    __tablename__ = "speech_preferences"

    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    language: Mapped[str] = mapped_column(String(64), nullable=False, default="en-US")
    voice_name: Mapped[str | None] = mapped_column(String(160))
    voice_locale: Mapped[str | None] = mapped_column(String(64))
    rate: Mapped[float] = mapped_column(Float, nullable=False, default=0.45)
    volume: Mapped[float] = mapped_column(Float, nullable=False, default=1.0)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False
    )


class RefreshToken(Base):
    """A long-lived sign-in that lets the app get new access tokens without the password.

    Only a keyed hash of the token is stored. Each use rotates the token: the old row is
    revoked and a new one is issued in the same family. Presenting an already-revoked
    token means it was copied, so the whole family is revoked and the user must sign in.
    """

    __tablename__ = "refresh_tokens"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    token_hash: Mapped[str] = mapped_column(String(64), unique=True, index=True, nullable=False)
    family_id: Mapped[str] = mapped_column(String(64), index=True, nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False
    )
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


def new_unique_user_code(session) -> int:
    """Pick a 7-digit User ID that no other account has."""
    from sqlalchemy import select

    while True:
        code = random_user_code()
        if session.scalar(select(User.id).where(User.user_code == code)) is None:
            return code
