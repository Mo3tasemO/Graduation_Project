"""The app stays signed in with a refresh token instead of asking for the password again."""

from datetime import datetime, timedelta, timezone

from sqlalchemy import select, update

from app.models import RefreshToken

from test_api import begin_registration, fake_email_delivery, make_client, verify_registration  # noqa: F401 - fixture

EMAIL = "sara@example.com"
PASSWORD = "StrongPass1!"


def register_and_login(client, sent):
    code = begin_registration(client, sent, email=EMAIL, password=PASSWORD)
    verified = verify_registration(client, EMAIL, code)
    assert verified.status_code == 201
    assert verified.json()["refresh_token"]
    login = client.post("/api/v1/auth/login", json={"email": EMAIL, "password": PASSWORD})
    assert login.status_code == 200
    return login.json()


def me(client, access_token):
    return client.get("/api/v1/me", headers={"Authorization": f"Bearer {access_token}"})


def test_login_returns_refresh_token_that_renews_access_without_password(tmp_path, fake_email_delivery):
    with make_client(tmp_path) as client:
        tokens = register_and_login(client, fake_email_delivery)
        refresh_token = tokens["refresh_token"]
        assert refresh_token and refresh_token != tokens["access_token"]

        renewed = client.post("/api/v1/auth/refresh", json={"refresh_token": refresh_token})
        assert renewed.status_code == 200
        body = renewed.json()
        assert body["token_type"] == "bearer"
        assert body["refresh_token"] != refresh_token
        assert me(client, body["access_token"]).json()["email"] == EMAIL

        # Only a hash is stored, never the token itself.
        with client.app.state.session_factory() as session:
            hashes = session.scalars(select(RefreshToken.token_hash)).all()
            assert refresh_token not in hashes
            assert body["refresh_token"] not in hashes


def test_refresh_token_rotates_and_reuse_ends_the_sign_in(tmp_path, fake_email_delivery):
    with make_client(tmp_path) as client:
        first = register_and_login(client, fake_email_delivery)["refresh_token"]
        second = client.post("/api/v1/auth/refresh", json={"refresh_token": first}).json()["refresh_token"]

        # Reusing a spent token is treated as a stolen copy: 401, and the newer token dies too.
        reused = client.post("/api/v1/auth/refresh", json={"refresh_token": first})
        assert reused.status_code == 401
        assert reused.json()["detail"]["code"] == "refresh_token_invalid"
        assert client.post("/api/v1/auth/refresh", json={"refresh_token": second}).status_code == 401


def test_logout_revokes_refresh_token_and_other_devices_stay_signed_in(tmp_path, fake_email_delivery):
    with make_client(tmp_path) as client:
        phone = register_and_login(client, fake_email_delivery)["refresh_token"]
        laptop = client.post(
            "/api/v1/auth/login", json={"email": EMAIL, "password": PASSWORD}
        ).json()["refresh_token"]

        assert client.post("/api/v1/auth/logout", json={"refresh_token": phone}).status_code == 200
        assert client.post("/api/v1/auth/refresh", json={"refresh_token": phone}).status_code == 401
        assert client.post("/api/v1/auth/refresh", json={"refresh_token": laptop}).status_code == 200
        # Logging out twice or with an unknown token is harmless.
        assert client.post("/api/v1/auth/logout", json={"refresh_token": phone}).status_code == 200
        assert client.post("/api/v1/auth/logout", json={"refresh_token": "x" * 40}).status_code == 200


def test_expired_and_unknown_refresh_tokens_are_rejected(tmp_path, fake_email_delivery):
    with make_client(tmp_path) as client:
        token = register_and_login(client, fake_email_delivery)["refresh_token"]
        assert client.post("/api/v1/auth/refresh", json={"refresh_token": "y" * 40}).status_code == 401
        assert client.post("/api/v1/auth/refresh", json={"refresh_token": "short"}).status_code == 422

        with client.app.state.session_factory() as session:
            session.execute(
                update(RefreshToken).values(
                    expires_at=datetime.now(timezone.utc) - timedelta(minutes=1)
                )
            )
            session.commit()
        assert client.post("/api/v1/auth/refresh", json={"refresh_token": token}).status_code == 401


def test_password_reset_signs_out_every_device(tmp_path, fake_email_delivery):
    with make_client(tmp_path) as client:
        token = register_and_login(client, fake_email_delivery)["refresh_token"]

        assert client.post("/api/v1/auth/forgot-password", json={"email": EMAIL}).status_code in (200, 202)
        reset_code = fake_email_delivery["reset"][-1][1]
        verified = client.post("/api/v1/auth/verify-reset-code", json={"email": EMAIL, "code": reset_code})
        assert verified.status_code == 200
        reset = client.post(
            "/api/v1/auth/reset-password",
            json={"email": EMAIL, "reset_token": verified.json()["reset_token"], "new_password": "NewPass2#"},
        )
        assert reset.status_code == 200
        assert client.post("/api/v1/auth/refresh", json={"refresh_token": token}).status_code == 401
