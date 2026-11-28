from datetime import datetime, timezone
import secrets

from fastapi.testclient import TestClient

from app.config import Settings
from app.main import create_app
from app.models import User
from app.security import create_access_token, hash_password


def make_client(tmp_path):
    settings = Settings(
        _env_file=None,
        jwt_secret_key=secrets.token_urlsafe(48),
        database_url=f"sqlite:///{tmp_path / 'home-test.db'}",
    )
    return settings, TestClient(create_app(settings))


def create_user(client, settings, email):
    with client.app.state.session_factory() as session:
        user = User(
            name=email.split("@")[0],
            email=email,
            password_hash=hash_password("StrongPass1!"),
            email_verified_at=datetime.now(timezone.utc),
        )
        session.add(user)
        session.commit()
        session.refresh(user)
        token = create_access_token(user.id, settings)
    return {"Authorization": f"Bearer {token}"}


def test_home_apis_require_auth_and_keep_user_data_isolated(tmp_path):
    settings, client = make_client(tmp_path)
    with client:
        assert client.get("/api/v1/home/phrases").status_code == 401
        assert client.get("/api/v1/home/history").status_code == 401
        assert client.get("/api/v1/home/preferences").status_code == 401

        first = create_user(client, settings, "first@example.com")
        second = create_user(client, settings, "second@example.com")

        phrase = client.post("/api/v1/home/phrases", headers=first, json={"text": "  Need help  "})
        assert phrase.status_code == 201
        phrase_id = phrase.json()["id"]
        assert phrase.json()["text"] == "Need help"
        assert client.get("/api/v1/home/phrases", headers=second).json() == []
        assert client.put(
            f"/api/v1/home/phrases/{phrase_id}", headers=second, json={"text": "Read another user"}
        ).status_code == 404
        assert client.delete(f"/api/v1/home/phrases/{phrase_id}", headers=second).status_code == 404

        invalid = client.post("/api/v1/home/phrases", headers=first, json={"text": "   "})
        assert invalid.status_code == 422
        duplicate = client.post("/api/v1/home/phrases", headers=first, json={"text": "need HELP"})
        assert duplicate.status_code == 409

        entry = client.post(
            "/api/v1/home/history", headers=first, json={"text": "I need water"}
        )
        assert entry.status_code == 201
        assert client.get("/api/v1/home/history", headers=first).json()[0]["text"] == "I need water"
        assert client.get("/api/v1/home/history", headers=second).json() == []
        assert client.delete(
            f"/api/v1/home/history/{entry.json()['id']}", headers=second
        ).status_code == 404

        cleared = client.delete("/api/v1/home/history", headers=first)
        assert cleared.status_code == 200
        assert client.get("/api/v1/home/history", headers=first).json() == []


def test_speech_preferences_validate_and_round_trip_per_user(tmp_path):
    settings, client = make_client(tmp_path)
    with client:
        first = create_user(client, settings, "first@example.com")
        second = create_user(client, settings, "second@example.com")
        defaults = client.get("/api/v1/home/preferences", headers=first)
        assert defaults.status_code == 200
        assert defaults.json() == {
            "language": "en-US",
            "voice_name": None,
            "voice_locale": None,
            "rate": 0.45,
            "volume": 1.0,
        }
        saved = client.put(
            "/api/v1/home/preferences",
            headers=first,
            json={"language": "ar", "voice_name": "Arabic voice", "voice_locale": "ar-SA", "rate": 0.6, "volume": 0.8},
        )
        assert saved.status_code == 200
        assert client.get("/api/v1/home/preferences", headers=first).json()["language"] == "ar"
        assert client.get("/api/v1/home/preferences", headers=second).json()["language"] == "en-US"
        invalid = client.put(
            "/api/v1/home/preferences",
            headers=first,
            json={"language": "en-US", "rate": 2, "volume": 0.5},
        )
        assert invalid.status_code == 422


def test_history_rejects_empty_and_long_messages(tmp_path):
    settings, client = make_client(tmp_path)
    with client:
        headers = create_user(client, settings, "first@example.com")
        assert client.post("/api/v1/home/history", headers=headers, json={"text": " "}).status_code == 422
        assert client.post(
            "/api/v1/home/history", headers=headers, json={"text": "x" * 501}
        ).status_code == 422
