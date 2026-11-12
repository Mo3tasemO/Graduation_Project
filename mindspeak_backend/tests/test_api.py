from datetime import datetime, timedelta, timezone
import os
import secrets
import smtplib

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, select

# The module-level ASGI app validates configuration when imported. Use a throwaway
# key during tests; each test uses a separate temporary SQLite database.
os.environ.setdefault("JWT_SECRET_KEY", secrets.token_urlsafe(48))

from app import routes
from app.config import Settings
from app.main import create_app
from app.models import PendingEmailVerification, User
from app.security import hash_password


@pytest.fixture(autouse=True)
def fake_email_delivery(monkeypatch):
    sent = {"verification": [], "reset": []}
    sequence = [110000]

    def deterministic_six_digit_code(_upper_bound):
        sequence[0] += 1
        return sequence[0]

    monkeypatch.setattr(routes.secrets, "randbelow", deterministic_six_digit_code)
    monkeypatch.setattr(
        routes,
        "send_email_verification_code",
        lambda email, code, settings: sent["verification"].append((email, code)),
    )
    monkeypatch.setattr(
        routes,
        "send_password_reset_code",
        lambda email, code, settings: sent["reset"].append((email, code)),
    )
    return sent


def make_client(tmp_path, *, email_enabled=True):
    tmp_path.mkdir(parents=True, exist_ok=True)
    settings = Settings(
        _env_file=None,
        jwt_secret_key=secrets.token_urlsafe(48),
        database_url=f"sqlite:///{tmp_path / 'test.db'}",
        access_token_expire_minutes=30,
        smtp_host="smtp.test" if email_enabled else None,
        smtp_username="test@example.com" if email_enabled else None,
        smtp_password="test-app-password" if email_enabled else None,
        smtp_from_email="noreply@example.com" if email_enabled else None,
    )
    return TestClient(create_app(settings))


def begin_registration(
    client,
    sent,
    email="sara@example.com",
    password="StrongPass1!",
    first_name="Sara",
    last_name="Ahmed",
):
    response = client.post(
        "/api/v1/auth/register",
        json={
            "first_name": first_name,
            "last_name": last_name,
            "email": email,
            "password": password,
        },
    )
    assert response.status_code == 202
    assert email.lower() == sent["verification"][-1][0]
    assert sent["verification"][-1][1] not in response.text
    return sent["verification"][-1][1]


def verify_registration(client, email, code):
    return client.post("/api/v1/auth/verify-email", json={"email": email, "code": code})


def test_registration_requires_email_verification_and_protects_profile(tmp_path, fake_email_delivery):
    with make_client(tmp_path) as client:
        assert client.get("/health").json() == {"status": "ok"}
        code = begin_registration(client, fake_email_delivery, email="Sara@example.com")

        # The pending record contains a password hash, but no account exists yet.
        with client.app.state.session_factory() as session:
            pending = session.scalar(select(PendingEmailVerification))
            assert pending is not None
            assert pending.email == "sara@example.com"
            assert pending.password_hash.startswith("$argon2id$")
            assert pending.password_hash != "StrongPass1!"
            assert pending.code_hash != code
            assert session.scalar(select(User)) is None

        login_before_verification = client.post(
            "/api/v1/auth/login",
            json={"email": "sara@example.com", "password": "StrongPass1!"},
        )
        assert login_before_verification.status_code == 401
        assert client.get("/api/v1/me").status_code == 401

        invalid_code = verify_registration(client, "sara@example.com", "000000" if code != "000000" else "000001")
        assert invalid_code.status_code == 400

        verified = verify_registration(client, "sara@example.com", code)
        assert verified.status_code == 201
        user_json = verified.json()["user"]
        assert user_json["email"] == "sara@example.com"
        assert user_json["name"] == "Sara Ahmed"
        assert "password_hash" not in verified.text
        assert "StrongPass1!" not in verified.text
        assert "access_token" in verified.json()

        with client.app.state.session_factory() as session:
            user = session.scalar(select(User).where(User.email == "sara@example.com"))
            assert user is not None
            assert user.email_verified_at is not None
            assert user.password_hash.startswith("$argon2id$")
            assert user.password_hash != "StrongPass1!"
            assert session.scalar(select(PendingEmailVerification)) is None

        # Verified email cannot be used to register a second time.
        duplicate = client.post(
            "/api/v1/auth/register",
            json={"first_name": "Sara", "last_name": "Ahmed", "email": "SARA@example.com", "password": "StrongPass1!"},
        )
        assert duplicate.status_code == 409

        login = client.post(
            "/api/v1/auth/login",
            json={"email": "sara@example.com", "password": "StrongPass1!"},
        )
        assert login.status_code == 200
        token = login.json()["access_token"]
        assert login.json()["token_type"] == "bearer"
        assert client.get("/api/v1/me").status_code == 401
        profile = client.get("/api/v1/me", headers={"Authorization": f"Bearer {token}"})
        assert profile.status_code == 200
        assert profile.json()["email"] == "sara@example.com"
        assert "password_hash" not in profile.text
        assert client.get("/api/v1/me", headers={"Authorization": "Bearer invalid"}).status_code == 401


def test_registration_validation_and_wrong_login(tmp_path, fake_email_delivery):
    with make_client(tmp_path) as client:
        invalid_email = client.post(
            "/api/v1/auth/register",
            json={"first_name": "Sara", "last_name": "Ahmed", "email": "not-an-email", "password": "StrongPass1!"},
        )
        assert invalid_email.status_code == 422

        invalid_name_data = (
            {"first_name": "", "last_name": "Ahmed"},
            {"first_name": "Sara", "last_name": "   "},
            {"first_name": "Sara"},
            {"last_name": "Ahmed"},
        )
        for name_data in invalid_name_data:
            invalid_name = client.post(
                "/api/v1/auth/register",
                json={**name_data, "email": "sara@example.com", "password": "StrongPass1!"},
            )
            assert invalid_name.status_code == 422

        for password in ("weak", "alllowercase1!", "NoDigits!!", "NoSymbol123"):
            invalid_password = client.post(
                "/api/v1/auth/register",
                json={"first_name": "Sara", "last_name": "Ahmed", "email": "sara@example.com", "password": password},
            )
            assert invalid_password.status_code == 422

        code = begin_registration(client, fake_email_delivery)
        assert verify_registration(client, "sara@example.com", code).status_code == 201
        bad_login = client.post(
            "/api/v1/auth/login",
            json={"email": "sara@example.com", "password": "WrongPass2!"},
        )
        assert bad_login.status_code == 401


def test_registration_accepts_arabic_first_and_last_names(tmp_path, fake_email_delivery):
    with make_client(tmp_path) as client:
        code = begin_registration(
            client,
            fake_email_delivery,
            email="layla@example.com",
            first_name="ليلى",
            last_name="محمد",
        )
        verified = verify_registration(client, "layla@example.com", code)
        assert verified.status_code == 201
        assert verified.json()["user"]["name"] == "ليلى محمد"


def test_registration_accepts_legacy_full_name_payload(tmp_path, fake_email_delivery):
    with make_client(tmp_path) as client:
        response = client.post(
            "/api/v1/auth/register",
            json={
                "name": "Maya Noor Hassan Ali",
                "email": "maya@example.com",
                "password": "StrongPass1!",
            },
        )
        assert response.status_code == 202
        code = fake_email_delivery["verification"][-1][1]
        verified = verify_registration(client, "maya@example.com", code)
        assert verified.status_code == 201
        assert verified.json()["user"]["name"] == "Maya Noor Hassan Ali"


def test_expired_registration_code_resend_and_attempt_limit(tmp_path, fake_email_delivery):
    with make_client(tmp_path) as client:
        old_code = begin_registration(client, fake_email_delivery)
        with client.app.state.session_factory() as session:
            pending = session.scalar(select(PendingEmailVerification))
            pending.expires_at = datetime.now(timezone.utc) - timedelta(seconds=1)
            session.commit()

        expired = verify_registration(client, "sara@example.com", old_code)
        assert expired.status_code == 410
        cooldown = client.post("/api/v1/auth/resend-verification-code", json={"email": "sara@example.com"})
        assert cooldown.status_code == 429

        with client.app.state.session_factory() as session:
            pending = session.scalar(select(PendingEmailVerification))
            pending.requested_at = datetime.now(timezone.utc) - timedelta(seconds=61)
            session.commit()
        resent = client.post("/api/v1/auth/resend-verification-code", json={"email": "sara@example.com"})
        assert resent.status_code == 202
        new_code = fake_email_delivery["verification"][-1][1]
        assert old_code != new_code
        assert verify_registration(client, "sara@example.com", old_code).status_code == 400
        assert verify_registration(client, "sara@example.com", new_code).status_code == 201

    with make_client(tmp_path / "attempts",) as client:
        code = begin_registration(client, fake_email_delivery, email="attempts@example.com")
        wrong = "000000" if code != "000000" else "000001"
        for _ in range(5):
            assert verify_registration(client, "attempts@example.com", wrong).status_code == 400
        assert verify_registration(client, "attempts@example.com", code).status_code == 429
        assert client.post(
            "/api/v1/auth/login",
            json={"email": "attempts@example.com", "password": "StrongPass1!"},
        ).status_code == 401


def test_registration_resend_is_limited_to_three_codes_per_hour(tmp_path, fake_email_delivery):
    with make_client(tmp_path) as client:
        begin_registration(client, fake_email_delivery)
        for expected_count in (2, 3):
            with client.app.state.session_factory() as session:
                pending = session.scalar(select(PendingEmailVerification))
                pending.requested_at = datetime.now(timezone.utc) - timedelta(seconds=61)
                session.commit()
            response = client.post(
                "/api/v1/auth/resend-verification-code", json={"email": "sara@example.com"}
            )
            assert response.status_code == 202
            assert len(fake_email_delivery["verification"]) == expected_count

        with client.app.state.session_factory() as session:
            pending = session.scalar(select(PendingEmailVerification))
            pending.requested_at = datetime.now(timezone.utc) - timedelta(seconds=61)
            session.commit()
        limited = client.post(
            "/api/v1/auth/resend-verification-code", json={"email": "sara@example.com"}
        )
        assert limited.status_code == 429
        assert len(fake_email_delivery["verification"]) == 3


def test_abandoned_pending_registration_expires_after_24_hours(tmp_path, fake_email_delivery):
    with make_client(tmp_path) as client:
        code = begin_registration(client, fake_email_delivery)
        with client.app.state.session_factory() as session:
            pending = session.scalar(select(PendingEmailVerification))
            pending.created_at = datetime.now(timezone.utc) - timedelta(hours=25)
            pending.expires_at = datetime.now(timezone.utc) + timedelta(minutes=5)
            session.commit()

        expired = verify_registration(client, "sara@example.com", code)
        assert expired.status_code == 410
        assert expired.json()["detail"]["code"] == "verification_registration_expired"
        with client.app.state.session_factory() as session:
            assert session.scalar(select(PendingEmailVerification)) is None


def test_registration_requires_smtp_and_does_not_store_pending_user(tmp_path):
    with make_client(tmp_path, email_enabled=False) as client:
        response = client.post(
            "/api/v1/auth/register",
            json={"first_name": "Sara", "last_name": "Ahmed", "email": "sara@example.com", "password": "StrongPass1!"},
        )
        assert response.status_code == 503
        with client.app.state.session_factory() as session:
            assert session.scalar(select(PendingEmailVerification)) is None
            assert session.scalar(select(User)) is None


def test_failed_registration_email_does_not_create_pending_record(tmp_path, monkeypatch):
    def fail_delivery(email, code, settings):
        raise smtplib.SMTPConnectError(421, b"temporary mail failure")

    monkeypatch.setattr(routes, "send_email_verification_code", fail_delivery)
    with make_client(tmp_path) as client:
        response = client.post(
            "/api/v1/auth/register",
            json={"first_name": "Sara", "last_name": "Ahmed", "email": "sara@example.com", "password": "StrongPass1!"},
        )
        assert response.status_code == 503
        assert response.json()["detail"]["code"] == "email_delivery_failed"
        with client.app.state.session_factory() as session:
            assert session.scalar(select(PendingEmailVerification)) is None
            assert session.scalar(select(User)) is None


def test_password_reset_full_flow_after_verified_registration(tmp_path, fake_email_delivery):
    with make_client(tmp_path) as client:
        registration_code = begin_registration(client, fake_email_delivery)
        assert verify_registration(client, "sara@example.com", registration_code).status_code == 201

        forgot = client.post("/api/v1/auth/forgot-password", json={"email": "sara@example.com"})
        assert forgot.status_code == 202
        reset_code = fake_email_delivery["reset"][-1][1]
        assert reset_code not in forgot.text

        wrong_code = "000000" if reset_code != "000000" else "000001"
        assert client.post(
            "/api/v1/auth/verify-reset-code",
            json={"email": "sara@example.com", "code": wrong_code},
        ).status_code == 400
        verified = client.post(
            "/api/v1/auth/verify-reset-code",
            json={"email": "sara@example.com", "code": reset_code},
        )
        assert verified.status_code == 200
        assert reset_code not in verified.text
        reset_token = verified.json()["reset_token"]

        reset = client.post(
            "/api/v1/auth/reset-password",
            json={"email": "sara@example.com", "reset_token": reset_token, "new_password": "NewPass2#"},
        )
        assert reset.status_code == 200
        assert client.post(
            "/api/v1/auth/reset-password",
            json={"email": "sara@example.com", "reset_token": reset_token, "new_password": "NewPass2#"},
        ).status_code == 400
        assert client.post(
            "/api/v1/auth/login",
            json={"email": "sara@example.com", "password": "NewPass2#"},
        ).status_code == 200
        assert client.post(
            "/api/v1/auth/login",
            json={"email": "sara@example.com", "password": "StrongPass1!"},
        ).status_code == 401


def test_reset_request_cooldown_and_missing_mail_configuration(tmp_path, fake_email_delivery):
    with make_client(tmp_path) as client:
        code = begin_registration(client, fake_email_delivery)
        assert verify_registration(client, "sara@example.com", code).status_code == 201
        assert client.post("/api/v1/auth/forgot-password", json={"email": "sara@example.com"}).status_code == 202
        assert client.post("/api/v1/auth/forgot-password", json={"email": "sara@example.com"}).status_code == 429

    with make_client(tmp_path / "no-mail", email_enabled=False) as client:
        # Missing SMTP is reported consistently and never pretends an email was sent.
        known = client.post("/api/v1/auth/forgot-password", json={"email": "known@example.com"})
        unknown = client.post("/api/v1/auth/forgot-password", json={"email": "unknown@example.com"})
        assert known.status_code == unknown.status_code == 503
        assert known.json() == unknown.json()


def test_reset_code_expiration_and_verification_attempt_limit(tmp_path, fake_email_delivery):
    with make_client(tmp_path) as client:
        registration_code = begin_registration(client, fake_email_delivery)
        assert verify_registration(client, "sara@example.com", registration_code).status_code == 201
        assert client.post("/api/v1/auth/forgot-password", json={"email": "sara@example.com"}).status_code == 202
        code = fake_email_delivery["reset"][-1][1]

        with client.app.state.session_factory() as session:
            challenge = session.scalar(select(routes.PasswordResetChallenge))
            challenge.expires_at = datetime.now(timezone.utc) - timedelta(seconds=1)
            session.commit()
        expired = client.post(
            "/api/v1/auth/verify-reset-code", json={"email": "sara@example.com", "code": code}
        )
        assert expired.status_code == 400
        assert expired.json()["detail"]["code"] == "reset_code_expired"

        with client.app.state.session_factory() as session:
            challenge = session.scalar(select(routes.PasswordResetChallenge))
            challenge.expires_at = datetime.now(timezone.utc) + timedelta(minutes=5)
            session.commit()
        wrong = "000000" if code != "000000" else "000001"
        for _ in range(5):
            assert client.post(
                "/api/v1/auth/verify-reset-code", json={"email": "sara@example.com", "code": wrong}
            ).status_code == 400
        exhausted = client.post(
            "/api/v1/auth/verify-reset-code", json={"email": "sara@example.com", "code": code}
        )
        assert exhausted.status_code == 429


def test_reset_token_expiration_is_enforced(tmp_path, fake_email_delivery):
    with make_client(tmp_path) as client:
        registration_code = begin_registration(client, fake_email_delivery)
        assert verify_registration(client, "sara@example.com", registration_code).status_code == 201
        assert client.post("/api/v1/auth/forgot-password", json={"email": "sara@example.com"}).status_code == 202
        code = fake_email_delivery["reset"][-1][1]
        verified = client.post(
            "/api/v1/auth/verify-reset-code", json={"email": "sara@example.com", "code": code}
        )
        assert verified.status_code == 200
        reset_token = verified.json()["reset_token"]
        with client.app.state.session_factory() as session:
            challenge = session.scalar(select(routes.PasswordResetChallenge))
            challenge.reset_token_expires_at = datetime.now(timezone.utc) - timedelta(seconds=1)
            session.commit()
        response = client.post(
            "/api/v1/auth/reset-password",
            json={"email": "sara@example.com", "reset_token": reset_token, "new_password": "NewPass2#"},
        )
        assert response.status_code == 400
        assert response.json()["detail"]["code"] == "reset_token_invalid"


def test_existing_sqlite_users_are_preserved_and_migrated_as_verified(tmp_path):
    database_path = tmp_path / "legacy.db"
    engine = create_engine(f"sqlite:///{database_path}")
    with engine.begin() as connection:
        connection.exec_driver_sql(
            "CREATE TABLE users (id INTEGER PRIMARY KEY, name VARCHAR(80) NOT NULL, "
            "email VARCHAR(254) NOT NULL UNIQUE, password_hash VARCHAR(255) NOT NULL, created_at DATETIME NOT NULL)"
        )
        connection.exec_driver_sql(
            "INSERT INTO users (id, name, email, password_hash, created_at) VALUES (?, ?, ?, ?, ?)",
            (7, "Legacy User Account", "legacy@example.com", hash_password("LegacyPass1!"), "2025-01-01 00:00:00"),
        )
    engine.dispose()

    settings = Settings(
        _env_file=None,
        jwt_secret_key=secrets.token_urlsafe(48),
        database_url=f"sqlite:///{database_path}",
    )
    with TestClient(create_app(settings)) as client:
        login = client.post(
            "/api/v1/auth/login",
            json={"email": "legacy@example.com", "password": "LegacyPass1!"},
        )
        assert login.status_code == 200
        with client.app.state.session_factory() as session:
            user = session.get(User, 7)
            assert user is not None
            assert user.name == "Legacy User Account"
            assert user.email_verified_at is not None
