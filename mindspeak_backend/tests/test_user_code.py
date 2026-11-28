"""Every account has a 7-digit User ID that is shown in the app and never changes."""

import secrets

from fastapi.testclient import TestClient
from sqlalchemy import create_engine, select

from app.config import Settings
from app.main import create_app
from app.models import USER_CODE_MAX, USER_CODE_MIN, User
from app.security import hash_password

from test_admin import admin_headers, make_admin_client, seed_admin, seed_users
from test_api import begin_registration, fake_email_delivery, make_client, verify_registration  # noqa: F401 - fixture


def is_seven_digits(value) -> bool:
    return isinstance(value, int) and USER_CODE_MIN <= value <= USER_CODE_MAX and len(str(value)) == 7


def test_new_accounts_get_a_unique_seven_digit_user_id_that_never_changes(tmp_path, fake_email_delivery):
    with make_client(tmp_path) as client:
        codes = []
        for email in ("sara@example.com", "omar@example.com"):
            code = begin_registration(client, fake_email_delivery, email=email)
            verified = verify_registration(client, email, code)
            assert verified.status_code == 201
            user = verified.json()["user"]
            assert is_seven_digits(user["user_code"])
            codes.append(user["user_code"])

            token = verified.json()["access_token"]
            headers = {"Authorization": f"Bearer {token}"}
            assert client.get("/api/v1/me", headers=headers).json()["user_code"] == user["user_code"]
            # Editing the profile cannot change it, even if a client tries.
            updated = client.put(
                "/api/v1/me", headers=headers, json={"name": "New Name", "user_code": 1234567}
            )
            assert updated.status_code == 200
            assert updated.json()["user_code"] == user["user_code"]

        assert codes[0] != codes[1]


def test_existing_accounts_get_a_user_id_on_startup_and_keep_it(tmp_path):
    database_path = tmp_path / "legacy.db"
    engine = create_engine(f"sqlite:///{database_path}")
    with engine.begin() as connection:
        connection.exec_driver_sql(
            "CREATE TABLE users (id INTEGER PRIMARY KEY, name VARCHAR(80) NOT NULL, "
            "email VARCHAR(254) NOT NULL UNIQUE, password_hash VARCHAR(255) NOT NULL, created_at DATETIME NOT NULL)"
        )
        for internal_id, email in ((1, "first@example.com"), (2, "second@example.com")):
            connection.exec_driver_sql(
                "INSERT INTO users (id, name, email, password_hash, created_at) VALUES (?, ?, ?, ?, ?)",
                (internal_id, "Legacy User", email, hash_password("LegacyPass1!"), "2025-01-01 00:00:00"),
            )
    engine.dispose()

    settings = Settings(
        _env_file=None,
        jwt_secret_key=secrets.token_urlsafe(48),
        database_url=f"sqlite:///{database_path}",
    )

    def codes_by_internal_id():
        with TestClient(create_app(settings)) as client:
            with client.app.state.session_factory() as session:
                return {user.id: user.user_code for user in session.scalars(select(User))}

    first_start = codes_by_internal_id()
    assert set(first_start) == {1, 2}  # internal ids untouched
    assert all(is_seven_digits(code) for code in first_start.values())
    assert first_start[1] != first_start[2]
    # Restarting the server does not hand out new IDs.
    assert codes_by_internal_id() == first_start


def test_admin_dashboard_lists_and_finds_users_by_user_id(tmp_path):
    _settings, client = make_admin_client(tmp_path)
    with client:
        seed_admin(client)
        seed_users(client)
        headers = admin_headers(client)
        listed = client.get("/api/v1/admin/users", headers=headers).json()["users"]
        assert all(is_seven_digits(user["user_code"]) for user in listed)

        target = listed[0]
        found = client.get(f"/api/v1/admin/users?q=%23{target['user_code']}", headers=headers).json()
        assert [user["user_code"] for user in found["users"]] == [target["user_code"]]
