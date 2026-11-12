from functools import lru_cache
from pathlib import Path

from pydantic import Field, SecretStr, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Read backend configuration from environment variables or a local .env file."""

    jwt_secret_key: SecretStr = Field(min_length=32)
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = Field(default=30, gt=0, le=1440)
    database_url: str = "sqlite:///./mindspeak.db"
    smtp_host: str | None = None
    smtp_port: int = Field(default=587, gt=0, le=65535)
    smtp_username: str | None = None
    smtp_password: SecretStr | None = None
    smtp_from_email: str | None = None
    smtp_use_starttls: bool = True

    model_config = SettingsConfigDict(
        # Resolve the backend's own .env regardless of the shell's working folder.
        env_file=Path(__file__).resolve().parent.parent / ".env",
        env_file_encoding="utf-8",
        env_ignore_empty=True,
        extra="ignore",
    )

    @model_validator(mode="after")
    def check_jwt_algorithm(self) -> "Settings":
        if self.jwt_algorithm != "HS256":
            raise ValueError("JWT_ALGORITHM must be HS256")
        if "replace-this" in self.jwt_secret_key.get_secret_value().lower():
            raise ValueError("Replace the example JWT_SECRET_KEY with a generated private value.")
        return self

    @model_validator(mode="after")
    def check_smtp_configuration(self) -> "Settings":
        smtp_fields = {
            "SMTP_HOST": self.smtp_host,
            "SMTP_USERNAME": self.smtp_username,
            "SMTP_PASSWORD": self.smtp_password,
            "SMTP_FROM_EMAIL": self.smtp_from_email,
        }
        # Email is optional for local development, but a partial SMTP setup should
        # fail early instead of failing later as an opaque mail-server error.
        if not any(value is not None for value in smtp_fields.values()):
            return self

        missing = []
        for name, value in smtp_fields.items():
            if isinstance(value, SecretStr):
                present = bool(value.get_secret_value().strip())
            else:
                present = value is not None and bool(str(value).strip())
            if not present:
                missing.append(name)
        if missing:
            raise ValueError("Incomplete SMTP configuration; set: " + ", ".join(missing))
        if not self.smtp_use_starttls:
            raise ValueError("SMTP_USE_STARTTLS must be true for secure SMTP delivery.")
        password = self.smtp_password.get_secret_value()
        if password.lower() == "replace-with-google-app-password":
            raise ValueError("Replace the SMTP_PASSWORD example value with your provider's app password.")
        return self

    @property
    def smtp_is_configured(self) -> bool:
        return bool(
            self.smtp_host
            and self.smtp_username
            and self.smtp_password
            and self.smtp_password.get_secret_value().strip()
            and self.smtp_from_email
        )


@lru_cache
def get_settings() -> Settings:
    return Settings()
