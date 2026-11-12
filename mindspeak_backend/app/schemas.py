from datetime import datetime
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
    name: str
    email: EmailStr
    created_at: datetime
    email_verified_at: datetime | None = None

    model_config = ConfigDict(from_attributes=True)


class RegisterResponse(BaseModel):
    user: UserResponse
    access_token: str
    token_type: str = "bearer"


class PendingRegisterResponse(BaseModel):
    email: EmailStr
    message: str


class VerifyEmailRequest(ForgotPasswordRequest):
    code: str = Field(pattern=r"^[0-9]{6}$")


class LoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserResponse
