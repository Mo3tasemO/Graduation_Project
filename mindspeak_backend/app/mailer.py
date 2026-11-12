from email.message import EmailMessage
from html import escape
import smtplib
import ssl

from .config import Settings


class EmailNotConfiguredError(RuntimeError):
    pass


def ensure_email_configured(settings: Settings) -> None:
    if not settings.smtp_is_configured:
        raise EmailNotConfiguredError


def _send_code_email(
    email: str,
    code: str,
    settings: Settings,
    *,
    subject: str,
    title: str,
    explanation: str,
) -> None:
    ensure_email_configured(settings)
    message = EmailMessage()
    message["Subject"] = subject
    message["From"] = settings.smtp_from_email
    message["To"] = email
    message.set_content(
        f"{title}\n\n{explanation}\n\n"
        f"Your verification code is: {code}\n"
        "This code expires in 5 minutes. If you did not request this, you can ignore this message."
    )
    message.add_alternative(
        "<!doctype html><html><body style='font-family:Arial,sans-serif;color:#173f5f'>"
        f"<h2>{escape(title)}</h2><p>{escape(explanation)}</p>"
        f"<p style='font-size:28px;font-weight:bold;letter-spacing:6px'>{escape(code)}</p>"
        "<p>This code expires in 5 minutes. If you did not request this, you can ignore this message.</p>"
        "</body></html>",
        subtype="html",
    )

    context = ssl.create_default_context()
    with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=15) as smtp:
        smtp.ehlo()
        if settings.smtp_use_starttls:
            smtp.starttls(context=context)
            smtp.ehlo()
        if settings.smtp_username:
            # ensure_email_configured guarantees both credential values exist.
            # Gmail displays App Passwords in groups separated by spaces; remove
            # whitespace so either copied form authenticates consistently.
            smtp_password = "".join(settings.smtp_password.get_secret_value().split())
            smtp.login(settings.smtp_username, smtp_password)
        smtp.send_message(message)


def send_email_verification_code(email: str, code: str, settings: Settings) -> None:
    """Deliver the registration code without logging or returning it."""
    _send_code_email(
        email,
        code,
        settings,
        subject="Verify your MindSpeak email",
        title="Welcome to MindSpeak",
        explanation="Use this code to verify your email address and finish creating your account.",
    )


def send_password_reset_code(email: str, code: str, settings: Settings) -> None:
    """Deliver the password-reset code without logging or returning it."""
    _send_code_email(
        email,
        code,
        settings,
        subject="Your MindSpeak password reset code",
        title="Reset your MindSpeak password",
        explanation="Use this code to verify your request to reset your password.",
    )
