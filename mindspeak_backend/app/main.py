from contextlib import asynccontextmanager
from pathlib import Path
from typing import Annotated

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqlalchemy import text

from . import models  # noqa: F401 - make sure the User table is registered with SQLAlchemy
from .admin_routes import admin_router, auth_router as admin_auth_router
from .admin_security import AdminLoginRateLimiter
from .config import Settings, get_settings
from .database import create_database_engine, create_session_factory, initialize_database
from .home_routes import router as home_router
from .routes import router


def create_app(settings: Settings | None = None) -> FastAPI:
    app_settings = settings or get_settings()
    engine = create_database_engine(app_settings.database_url)
    session_factory = create_session_factory(engine)

    @asynccontextmanager
    async def lifespan(_app: FastAPI):
        initialize_database(engine)
        yield
        engine.dispose()

    app = FastAPI(
        title="MindSpeak Backend API",
        description="Independent API for the MindSpeak Flutter application.",
        version="0.1.0",
        lifespan=lifespan,
    )
    app.state.settings = app_settings
    app.state.session_factory = session_factory
    app.state.engine = engine
    app.state.admin_login_limiter = AdminLoginRateLimiter()
    # Local Flutter web development typically uses a random localhost port.
    # Keep cross-origin access restricted to local development hosts.
    app.add_middleware(
        CORSMiddleware,
        allow_origin_regex=r"https?://(localhost|127\.0\.0\.1)(:\d+)?",
        allow_credentials=False,
        allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        allow_headers=["Authorization", "Content-Type"],
    )

    @app.middleware("http")
    async def security_headers(request: Request, call_next):
        response = await call_next(request)
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["Referrer-Policy"] = "no-referrer"
        if request.url.path.startswith(("/admin", "/api/v1/admin", "/api/v1/home", "/api/v1/me")):
            response.headers["Cache-Control"] = "no-store"
        return response

    app.include_router(router)
    app.include_router(home_router)
    app.include_router(admin_auth_router)
    app.include_router(admin_router)

    @app.get("/health", tags=["Health"], summary="Check that the API and database are available")
    def health(request: Request) -> dict[str, str]:
        try:
            with request.app.state.engine.connect() as connection:
                connection.execute(text("SELECT 1"))
        except Exception:
            raise HTTPException(
                status_code=503,
                detail={"code": "database_unavailable", "message": "The database is unavailable."},
            ) from None
        return {"status": "ok"}

    dashboard_directory = Path(__file__).resolve().parent.parent.parent / "mindspeak_admin"
    app.mount(
        "/admin",
        StaticFiles(directory=dashboard_directory, html=True),
        name="admin-dashboard",
    )

    return app


app = create_app()
