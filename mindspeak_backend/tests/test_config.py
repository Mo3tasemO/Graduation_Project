import secrets

from app.config import BACKEND_DIRECTORY, Settings


def make_settings(database_url: str) -> Settings:
    return Settings(_env_file=None, jwt_secret_key=secrets.token_urlsafe(48), database_url=database_url)


def test_relative_sqlite_path_is_kept_inside_backend_folder(tmp_path, monkeypatch):
    # Starting the server from another folder must not create a second database there.
    monkeypatch.chdir(tmp_path)
    settings = make_settings("sqlite:///./mindspeak.db")
    expected = (BACKEND_DIRECTORY / "mindspeak.db").resolve().as_posix()
    assert settings.database_url == f"sqlite:///{expected}"
    assert str(tmp_path) not in settings.database_url


def test_absolute_and_memory_sqlite_urls_are_unchanged(tmp_path):
    absolute = f"sqlite:///{tmp_path / 'custom.db'}"
    assert make_settings(absolute).database_url == absolute
    assert make_settings("sqlite:///C:/data/mindspeak.db").database_url == "sqlite:///C:/data/mindspeak.db"
    assert make_settings("sqlite:///:memory:").database_url == "sqlite:///:memory:"
    assert make_settings("sqlite://").database_url == "sqlite://"


def test_sqlite_query_string_is_preserved():
    settings = make_settings("sqlite:///./mindspeak.db?timeout=10")
    assert settings.database_url.endswith("/mindspeak.db?timeout=10")
