from email.message import EmailMessage
import secrets
import smtplib
import ssl

import pytest
from pydantic import SecretStr, ValidationError

from app.config import Settings
from app.mailer import (
    EmailNotConfiguredError,
    ensure_email_configured,
    send_email_verification_code,
    send_password_reset_code,
)


def test_smtp_values_load_from_env_file(tmp_path):
    env_file = tmp_path / ".env"
    env_file.write_text(
        "\n".join(
            [
                "SMTP_HOST=smtp.gmail.com",
                "SMTP_PORT=587",
                "SMTP_USE_STARTTLS=true",
                "SMTP_USERNAME=tester@gmail.com",
                "SMTP_PASSWORD=fake-test-app-password",
                "SMTP_FROM_EMAIL=tester@gmail.com",
            ]
        ),
        encoding="utf-8",
    )

    settings = Settings(
        _env_file=env_file,
        jwt_secret_key=secrets.token_urlsafe(48),
    )

    assert settings.smtp_host == "smtp.gmail.com"
    assert settings.smtp_port == 587
    assert settings.smtp_use_starttls is True
    assert settings.smtp_username == "tester@gmail.com"
    assert settings.smtp_password.get_secret_value() == "fake-test-app-password"
    assert settings.smtp_from_email == "tester@gmail.com"
    assert settings.smtp_is_configured is True


def test_partial_or_insecure_smtp_configuration_is_rejected():
    with pytest.raises(ValidationError, match="Incomplete SMTP configuration"):
        Settings(_env_file=None, jwt_secret_key=secrets.token_urlsafe(48), smtp_host="smtp.gmail.com")

    with pytest.raises(ValidationError, match="SMTP_USE_STARTTLS must be true"):
        Settings(
            _env_file=None,
            jwt_secret_key=secrets.token_urlsafe(48),
            smtp_host="smtp.gmail.com",
            smtp_username="tester@gmail.com",
            smtp_password="fake-test-app-password",
            smtp_from_email="tester@gmail.com",
            smtp_use_starttls=False,
        )

    with pytest.raises(ValidationError, match="Replace the SMTP_PASSWORD example value"):
        Settings(
            _env_file=None,
            jwt_secret_key=secrets.token_urlsafe(48),
            smtp_host="smtp.gmail.com",
            smtp_username="tester@gmail.com",
            smtp_password="replace-with-google-app-password",
            smtp_from_email="tester@gmail.com",
        )


def test_email_delivery_uses_starttls_auth_and_safe_templates(monkeypatch, caplog):
    settings = Settings(
        _env_file=None,
        jwt_secret_key=secrets.token_urlsafe(48),
        smtp_host="smtp.gmail.com",
        smtp_port=587,
        smtp_use_starttls=True,
        smtp_username="tester@gmail.com",
        smtp_password=SecretStr("fake-test-app-password"),
        smtp_from_email="tester@gmail.com",
    )
    captured = {}

    class FakeSMTP:
        def __init__(self, host, port, timeout):
            captured["connection"] = (host, port, timeout)
            captured["steps"] = []

        def __enter__(self):
            return self

        def __exit__(self, *_args):
            return False

        def ehlo(self):
            captured["steps"].append("ehlo")

        def starttls(self, *, context):
            assert isinstance(context, ssl.SSLContext)
            captured["steps"].append("starttls")

        def login(self, username, password):
            captured["login"] = (username, password)
            captured["steps"].append("login")

        def send_message(self, message):
            assert isinstance(message, EmailMessage)
            captured["message"] = message
            captured["steps"].append("send")

    monkeypatch.setattr("app.mailer.smtplib.SMTP", FakeSMTP)
    code = "381704"
    send_email_verification_code("recipient@example.com", code, settings)

    assert captured["connection"] == ("smtp.gmail.com", 587, 15)
    assert captured["steps"] == ["ehlo", "starttls", "ehlo", "login", "send"]
    assert captured["login"] == ("tester@gmail.com", "fake-test-app-password")
    assert captured["message"]["From"] == "tester@gmail.com"
    assert captured["message"]["To"] == "recipient@example.com"
    assert code in captured["message"].get_body(preferencelist=("plain",)).get_content()
    assert code in captured["message"].get_body(preferencelist=("html",)).get_content()
    assert code not in caplog.text


def test_reset_code_uses_same_secure_smtp_delivery(monkeypatch):
    settings = Settings(
        _env_file=None,
        jwt_secret_key=secrets.token_urlsafe(48),
        smtp_host="smtp.gmail.com",
        smtp_username="tester@gmail.com",
        smtp_password="fake-test-app-password",
        smtp_from_email="tester@gmail.com",
    )
    messages = []

    class FakeSMTP:
        def __init__(self, *_args, **_kwargs):
            pass

        def __enter__(self):
            return self

        def __exit__(self, *_args):
            return False

        def ehlo(self):
            pass

        def starttls(self, *, context):
            assert isinstance(context, ssl.SSLContext)

        def login(self, *_args):
            pass

        def send_message(self, message):
            messages.append(message)

    monkeypatch.setattr("app.mailer.smtplib.SMTP", FakeSMTP)
    send_password_reset_code("recipient@example.com", "492681", settings)
    assert messages[0]["Subject"] == "Your MindSpeak password reset code"


def test_unconfigured_mailer_fails_instead_of_claiming_delivery():
    settings = Settings(_env_file=None, jwt_secret_key=secrets.token_urlsafe(48))
    assert settings.smtp_is_configured is False
    with pytest.raises(EmailNotConfiguredError):
        ensure_email_configured(settings)


def test_smtp_delivery_errors_propagate_without_logging_code(monkeypatch, caplog):
    settings = Settings(
        _env_file=None,
        jwt_secret_key=secrets.token_urlsafe(48),
        smtp_host="smtp.gmail.com",
        smtp_username="tester@gmail.com",
        smtp_password="fake-test-app-password",
        smtp_from_email="tester@gmail.com",
    )
    code = "902117"

    class FailedSMTP:
        def __init__(self, *_args, **_kwargs):
            pass

        def __enter__(self):
            raise smtplib.SMTPConnectError(421, b"temporary test failure")

        def __exit__(self, *_args):
            return False

    monkeypatch.setattr("app.mailer.smtplib.SMTP", FailedSMTP)
    with pytest.raises(smtplib.SMTPConnectError):
        send_email_verification_code("recipient@example.com", code, settings)
    assert code not in caplog.text
