from datetime import datetime
import base64
import binascii
import re

from pydantic import (
    BaseModel,
    ConfigDict,
    EmailStr,
    Field,
    field_validator,
    model_validator,
)


class RegisterRequest(BaseModel):
    first_name: str = Field(min_length=1, max_length=80)
    last_name: str = Field(min_length=1, max_length=80)
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)

    @model_validator(mode="before")
    @classmethod
    def split_legacy_name(cls, value: object) -> object:
        # Accept older app builds that still submit a single full-name field.
        if isinstance(value, dict) and "name" in value:
            data = dict(value)
            if "first_name" not in data and "last_name" not in data:
                parts = str(data.get("name") or "").split()
                if len(parts) >= 2:
                    data["first_name"] = parts[0]
                    data["last_name"] = " ".join(parts[1:])
            return data
        return value

    @field_validator("first_name", "last_name")
    @classmethod
    def name_parts_must_not_be_blank(cls, value: str) -> str:
        cleaned = " ".join(value.split())
        if not cleaned:
            raise ValueError("First and last name must not be empty.")
        return cleaned

    @model_validator(mode="after")
    def combined_name_fits_database_field(self) -> "RegisterRequest":
        if len(self.first_name) + len(self.last_name) + 1 > 80:
            raise ValueError("First and last name together must be 80 characters or fewer.")
        return self

    @property
    def name(self) -> str:
        return f"{self.first_name} {self.last_name}"

    @field_validator("password")
    @classmethod
    def password_must_be_strong(cls, value: str) -> str:
        if not re.fullmatch(r"(?=.*[A-Z])(?=.*[a-z])(?=.*[0-9])(?=.*[^A-Za-z0-9\s]).{8,128}", value):
            raise ValueError("Password must be at least 8 characters and include uppercase, lowercase, number, and special character.")
        return value

    @field_validator("email")
    @classmethod
    def normalize_email(cls, value: EmailStr) -> str:
        return str(value).strip().lower()


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=128)

    @field_validator("email")
    @classmethod
    def normalize_email(cls, value: EmailStr) -> str:
        return str(value).strip().lower()


class ForgotPasswordRequest(BaseModel):
    email: EmailStr

    @field_validator("email")
    @classmethod
    def normalize_email(cls, value: EmailStr) -> str:
        return str(value).strip().lower()


class VerifyResetCodeRequest(ForgotPasswordRequest):
    code: str = Field(pattern=r"^[0-9]{6}$")


class VerifyResetCodeResponse(BaseModel):
    reset_token: str
    token_type: str = "bearer"
    expires_in: int


class ResetPasswordRequest(BaseModel):
    email: EmailStr
    reset_token: str = Field(min_length=32, max_length=128)
    new_password: str = Field(min_length=8, max_length=128)

    @field_validator("email")
    @classmethod
    def normalize_email(cls, value: EmailStr) -> str:
        return str(value).strip().lower()

    @field_validator("new_password")
    @classmethod
    def password_must_be_strong(cls, value: str) -> str:
        if not re.fullmatch(r"(?=.*[A-Z])(?=.*[a-z])(?=.*[0-9])(?=.*[^A-Za-z0-9\s]).{8,128}", value):
            raise ValueError("Password must be at least 8 characters and include uppercase, lowercase, number, and special character.")
        return value


class MessageResponse(BaseModel):
    message: str


class UserResponse(BaseModel):
    id: int
    # The 7-digit User ID shown in the app. `id` is internal.
    user_code: int | None = None
    name: str
    email: EmailStr
    created_at: datetime
    email_verified_at: datetime | None = None
    age: int | None = None
    medical_information: str | None = None
    avatar_data: str | None = None

    model_config = ConfigDict(from_attributes=True)


class ProfileUpdateRequest(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=80)
    age: int | None = Field(default=None, ge=1, le=120)
    medical_information: str | None = Field(default=None, max_length=5000)
    avatar_data: str | None = Field(default=None, max_length=1_500_000)

    @field_validator("name")
    @classmethod
    def clean_name(cls, value: str | None) -> str | None:
        # Only runs when the client sends "name". Omit the field to keep the current
        # name; an explicit null would violate the NOT NULL column and return a 500.
        if value is None:
            raise ValueError("Name cannot be removed. Omit the field to keep the current name.")
        cleaned = " ".join(value.split())
        if not cleaned:
            raise ValueError("Name must not be empty.")
        return cleaned

    @field_validator("medical_information")
    @classmethod
    def clean_medical_information(cls, value: str | None) -> str | None:
        if value is None:
            return None
        cleaned = value.strip()
        return cleaned or None

    @field_validator("avatar_data")
    @classmethod
    def validate_avatar(cls, value: str | None) -> str | None:
        if value is None:
            return None
        try:
            header, encoded = value.split(",", 1)
            image = base64.b64decode(encoded, validate=True)
        except (ValueError, binascii.Error):
            raise ValueError("Profile image must be a valid PNG, JPEG, or WebP image.") from None
        valid = (
            header == "data:image/png;base64" and image.startswith(b"\x89PNG\r\n\x1a\n")
        ) or (
            header == "data:image/jpeg;base64" and image.startswith(b"\xff\xd8\xff")
        ) or (
            header == "data:image/webp;base64"
            and len(image) >= 12
            and image[:4] == b"RIFF"
            and image[8:12] == b"WEBP"
        )
        if not valid or len(image) > 1_000_000:
            raise ValueError("Profile image must be PNG, JPEG, or WebP and under 1 MB.")
        return value


class RegisterResponse(BaseModel):
    user: UserResponse
    access_token: str
    token_type: str = "bearer"
    refresh_token: str | None = None


class PendingRegisterResponse(BaseModel):
    email: EmailStr
    message: str


class VerifyEmailRequest(ForgotPasswordRequest):
    code: str = Field(pattern=r"^[0-9]{6}$")


class LoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserResponse
    refresh_token: str | None = None


class RefreshRequest(BaseModel):
    refresh_token: str = Field(min_length=20, max_length=200)


class RefreshResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    refresh_token: str
