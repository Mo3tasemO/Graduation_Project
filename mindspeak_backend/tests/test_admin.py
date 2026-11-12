from datetime import datetime, timedelta, timezone
import secrets

from fastapi.testclient import TestClient
from sqlalchemy import select

from app.admin_security import AdminLoginRateLimiter
from app.config import Settings
from app.main import create_app
from app.models import AdminAccount, User
from app.security import create_access_token, hash_password


def make_admin_client(tmp_path):
    settings = Settings(
        _env_file=None,
        jwt_secret_key=secrets.token_urlsafe(48),
        database_url=f"sqlite:///{tmp_path / 'admin-test.db'}",
    )
    return settings, TestClient(create_app(settings))


def seed_admin(client, email="administrator@example.com", password="SecureAdmin9!Pass"):
    with client.app.state.session_factory() as session:
        admin = AdminAccount(email=email, password_hash=hash_password(password))
        session.add(admin)
        session.commit()
        session.refresh(admin)
        return admin.id


def seed_users(client):
    now = datetime.now(timezone.utc)
    users = [
        User(
            name="Ann Smith",
            email="ann@example.com",
            password_hash=hash_password("NormalPass9!"),
            email_verified_at=now - timedelta(days=2),
            created_at=now - timedelta(days=3),
        ),
        User(
            name="Alice Jones",
            email="alice@example.com",
            password_hash=hash_password("NormalPass9!"),
            email_verified_at=None,
            created_at=now - timedelta(days=1),
        ),
        User(
            name="Bob Ali",
            email="bob@example.com",
            password_hash=hash_password("NormalPass9!"),
            email_verified_at=now - timedelta(days=9),
            created_at=now - timedelta(days=10),
        ),
    ]
    with client.app.state.session_factory() as session:
        session.add_all(users)
        session.commit()
        return [user.id for user in session.scalars(select(User).order_by(User.id)).all()]


def admin_headers(client):
    response = client.post(
        "/api/v1/admin/auth/login",
        json={"email": "ADMINISTRATOR@example.com", "password": "SecureAdmin9!Pass"},
    )
    assert response.status_code == 200
    assert "password" not in response.text
    token = response.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def test_admin_auth_stats_search_pagination_and_sort(tmp_path):
    _settings, client = make_admin_client(tmp_path)
    with client:
        seed_admin(client)
        ids = seed_users(client)

        assert client.get("/api/v1/admin/dashboard/stats").status_code == 401
        assert client.get("/api/v1/admin/users").status_code == 401
        assert client.get("/api/v1/admin/auth/me").status_code == 401

        headers = admin_headers(client)
        identity = client.get("/api/v1/admin/auth/me", headers=headers)
        assert identity.status_code == 200
        assert identity.json()["email"] == "administrator@example.com"

        stats = client.get("/api/v1/admin/dashboard/stats", headers=headers)
        assert stats.status_code == 200
        assert stats.json() == {
            "total_users": 3,
            "verified_users": 2,
            "new_registrations_7d": 2,
            "email_verification_rate": 66.7,
        }

        all_users = client.get(
            "/api/v1/admin/users?page=1&page_size=2&sort=desc", headers=headers
        )
        assert all_users.status_code == 200
        page_one = all_users.json()
        assert page_one["total"] == 3
        assert [user["name"] for user in page_one["users"]] == ["Alice Jones", "Ann Smith"]
        assert set(page_one["users"][0]) == {
            "id",
            "name",
            "email",
            "email_verified",
            "created_at",
        }
        assert "password_hash" not in all_users.text
        assert "NormalPass9!" not in all_users.text

        second_page = client.get(
            "/api/v1/admin/users?page=2&page_size=2&sort=desc", headers=headers
        ).json()
        assert [user["id"] for user in second_page["users"]] == [ids[2]]

        searched = client.get(
            "/api/v1/admin/users?q=alice&page=1&page_size=10", headers=headers
        )
        assert searched.status_code == 200
        assert [user["email"] for user in searched.json()["users"]] == ["alice@example.com"]

        searched_email = client.get(
            "/api/v1/admin/users?q=bob%40example.com", headers=headers
        )
        assert [user["name"] for user in searched_email.json()["users"]] == ["Bob Ali"]

        oldest_first = client.get(
            "/api/v1/admin/users?page=1&page_size=1&sort=asc", headers=headers
        )
        assert [user["id"] for user in oldest_first.json()["users"]] == [ids[2]]

        # A normal MindSpeak user JWT is signed differently and cannot access admin APIs.
        normal_token = create_access_token(12345, client.app.state.settings)
        normal_headers = {"Authorization": f"Bearer {normal_token}"}
        assert client.get("/api/v1/admin/dashboard/stats", headers=normal_headers).status_code == 401
        assert client.get("/api/v1/admin/users", headers=normal_headers).status_code == 401


def test_admin_login_is_generic_and_rate_limited(tmp_path):
    _settings, client = make_admin_client(tmp_path)
    with client:
        seed_admin(client)
        for _ in range(5):
            failed = client.post(
                "/api/v1/admin/auth/login",
                json={"email": "administrator@example.com", "password": "wrong"},
            )
            assert failed.status_code == 401
            assert failed.json()["detail"]["message"] == "Email or password is incorrect."
        limited = client.post(
            "/api/v1/admin/auth/login",
            json={"email": "administrator@example.com", "password": "wrong"},
        )
        assert limited.status_code == 429


def test_admin_routes_are_mounted_but_no_public_signup_exists(tmp_path):
    _settings, client = make_admin_client(tmp_path)
    with client:
        paths = client.get("/openapi.json").json()["paths"]
        assert "/api/v1/admin/auth/login" in paths
        assert "/api/v1/admin/dashboard/stats" in paths
        assert "/api/v1/admin/users" in paths
        assert not any("signup" in path for path in paths if "/admin/" in path)


def test_admin_login_rate_limiter_clears_successful_key():
    limiter = AdminLoginRateLimiter(max_attempts=2, window_seconds=60)
    limiter.record_failure("local-client")
    limiter.record_failure("local-client")
    assert limiter.is_limited("local-client")
    limiter.clear("local-client")
    assert not limiter.is_limited("local-client")
