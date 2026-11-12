from datetime import datetime, timedelta, timezone
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from .admin_schemas import (
    AdminIdentity,
    AdminLoginRequest,
    AdminLoginResponse,
    AdminUserItem,
    AdminUserListResponse,
    DashboardStatsResponse,
)
from .admin_security import create_admin_access_token, read_admin_access_token
from .config import Settings
from .models import AdminAccount, User
from .routes import get_session
from .security import verify_password

auth_router = APIRouter(prefix="/api/v1/admin/auth", tags=["Admin authentication"])
admin_router = APIRouter(prefix="/api/v1/admin", tags=["Admin dashboard"])
bearer_scheme = HTTPBearer(auto_error=False)
unauthorized = HTTPException(
    status_code=status.HTTP_401_UNAUTHORIZED,
    detail={"code": "admin_unauthorized", "message": "Administrator authentication is required."},
    headers={"WWW-Authenticate": "Bearer"},
)


def require_current_admin(
    request: Request,
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer_scheme)],
    session: Annotated[Session, Depends(get_session)],
) -> AdminAccount:
    if credentials is None:
        raise unauthorized
    settings: Settings = request.app.state.settings
    admin_id = read_admin_access_token(credentials.credentials, settings)
    if admin_id is None:
        raise unauthorized
    admin = session.get(AdminAccount, admin_id)
    if admin is None or not admin.is_active:
        raise unauthorized
    return admin


@auth_router.post(
    "/login",
    response_model=AdminLoginResponse,
    summary="Authenticate an administrator",
)
def admin_login(
    payload: AdminLoginRequest,
    request: Request,
    session: Annotated[Session, Depends(get_session)],
) -> AdminLoginResponse:
    client_host = request.client.host if request.client is not None else "unknown"
    limiter = request.app.state.admin_login_limiter
    if limiter.is_limited(client_host):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail={"code": "admin_login_rate_limited", "message": "Too many sign-in attempts. Try again in 15 minutes."},
            headers={"Retry-After": "900"},
        )

    admin = session.scalar(
        select(AdminAccount).where(func.lower(AdminAccount.email) == payload.email)
    )
    try:
        password_matches = (
            admin is not None
            and admin.is_active
            and verify_password(payload.password, admin.password_hash)
        )
    except Exception:
        # A malformed stored hash must fail closed without exposing database details.
        password_matches = False
    if not password_matches or admin is None:
        limiter.record_failure(client_host)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"code": "invalid_admin_credentials", "message": "Email or password is incorrect."},
            headers={"WWW-Authenticate": "Bearer"},
        )

    limiter.clear(client_host)
    settings: Settings = request.app.state.settings
    return AdminLoginResponse(
        access_token=create_admin_access_token(admin.id, settings),
        expires_in=settings.access_token_expire_minutes * 60,
        admin=AdminIdentity(id=admin.id, email=admin.email),
    )


@auth_router.get("/me", response_model=AdminIdentity)
def current_admin(
    admin: Annotated[AdminAccount, Depends(require_current_admin)],
) -> AdminIdentity:
    return AdminIdentity(id=admin.id, email=admin.email)


@admin_router.get("/dashboard/stats", response_model=DashboardStatsResponse)
def dashboard_stats(
    _admin: Annotated[AdminAccount, Depends(require_current_admin)],
    session: Annotated[Session, Depends(get_session)],
) -> DashboardStatsResponse:
    now = datetime.now(timezone.utc)
    seven_days_ago = now - timedelta(days=7)
    total = session.scalar(select(func.count(User.id))) or 0
    verified = session.scalar(
        select(func.count(User.id)).where(User.email_verified_at.is_not(None))
    ) or 0
    new_registrations = session.scalar(
        select(func.count(User.id)).where(User.created_at >= seven_days_ago)
    ) or 0
    rate = round((verified / total) * 100, 1) if total else 0.0
    return DashboardStatsResponse(
        total_users=total,
        verified_users=verified,
        new_registrations_7d=new_registrations,
        email_verification_rate=rate,
    )


@admin_router.get("/users", response_model=AdminUserListResponse)
def list_users(
    _admin: Annotated[AdminAccount, Depends(require_current_admin)],
    session: Annotated[Session, Depends(get_session)],
    q: Annotated[str | None, Query(max_length=100)] = None,
    page: Annotated[int, Query(ge=1)] = 1,
    page_size: Annotated[int, Query(ge=1, le=100)] = 20,
    sort: Literal["asc", "desc"] = "desc",
) -> AdminUserListResponse:
    statement = select(User)
    count_statement = select(func.count(User.id))
    search = (q or "").strip()
    if search:
        escaped = search.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
        pattern = f"%{escaped}%"
        search_filter = or_(
            User.name.ilike(pattern, escape="\\"),
            User.email.ilike(pattern, escape="\\"),
        )
        statement = statement.where(search_filter)
        count_statement = count_statement.where(search_filter)

    total = session.scalar(count_statement) or 0
    order = User.created_at.asc() if sort == "asc" else User.created_at.desc()
    users = session.scalars(
        statement.order_by(order, User.id.asc() if sort == "asc" else User.id.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    ).all()
    return AdminUserListResponse(
        total=total,
        page=page,
        page_size=page_size,
        users=[
            AdminUserItem(
                id=user.id,
                name=user.name,
                email=user.email,
                email_verified=user.email_verified_at is not None,
                created_at=user.created_at,
            )
            for user in users
        ],
    )
