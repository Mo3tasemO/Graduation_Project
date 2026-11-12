from datetime import datetime

from pydantic import BaseModel, EmailStr, Field, field_validator


class AdminLoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=128)

    @field_validator("email")
    @classmethod
    def normalize_email(cls, value: EmailStr) -> str:
        return str(value).strip().lower()


class AdminIdentity(BaseModel):
    id: int
    email: EmailStr


class AdminLoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int
    admin: AdminIdentity


class DashboardStatsResponse(BaseModel):
    total_users: int
    verified_users: int
    new_registrations_7d: int
    email_verification_rate: float


class AdminUserItem(BaseModel):
    id: int
    name: str
    email: EmailStr
    email_verified: bool
    created_at: datetime


class AdminUserListResponse(BaseModel):
    total: int
    page: int
    page_size: int
    users: list[AdminUserItem]
