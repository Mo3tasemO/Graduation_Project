"""Local-only provisioning for the first MindSpeak administrator."""

import argparse
from getpass import getpass
from pathlib import Path
import re
import secrets

from pydantic import EmailStr, TypeAdapter, ValidationError
from sqlalchemy import inspect, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.engine import make_url
from sqlalchemy.orm import Session

from . import models  # noqa: F401 - register AdminAccount with SQLAlchemy
from .config import get_settings
from .database import create_database_engine
from .models import AdminAccount
from .security import hash_password


def _read_credentials() -> tuple[str, str] | None:
    raw_email = input("Administrator email: ").strip()
    try:
        email = str(TypeAdapter(EmailStr).validate_python(raw_email)).lower()
    except ValidationError:
        print("Enter a valid email address.")
        return None

    password = getpass("Create administrator password (input hidden): ")
    confirmation = getpass("Confirm administrator password (input hidden): ")
    if not secrets.compare_digest(password.encode("utf-8"), confirmation.encode("utf-8")):
        print("Passwords did not match. No administrator was created.")
        return None
    if (
        len(password) < 12
        or len(password) > 128
        or not re.search(r"[A-Z]", password)
        or not re.search(r"[a-z]", password)
        or not re.search(r"[0-9]", password)
        or not re.search(r"[^A-Za-z0-9\s]", password)
    ):
        print(
            "Use 12–128 characters with uppercase, lowercase, a number, and a symbol. "
            "No administrator was created."
        )
        return None
    return email, password


def create_first_admin() -> int:
    settings = get_settings()
    database_url = make_url(settings.database_url)
    if database_url.get_backend_name() == "sqlite":
        database_path = database_url.database or ""
        if database_path and database_path != ":memory:":
            resolved_database = Path(database_path)
            if not resolved_database.is_absolute():
                resolved_database = Path.cwd() / resolved_database
            if not resolved_database.is_file():
                print(
                    "The configured SQLite database file was not found. "
                    "Check DATABASE_URL and run this command from mindspeak_backend."
                )
                return 1
    engine = create_database_engine(settings.database_url)
    try:
        if not inspect(engine).has_table("users"):
            print(
                "The configured database does not contain the existing users table. "
                "Check DATABASE_URL and run this command from mindspeak_backend."
            )
            return 1

        # Create only this new table. Existing user/auth tables and rows are untouched.
        AdminAccount.__table__.create(engine, checkfirst=True)
        with Session(engine) as session:
            if session.scalar(select(AdminAccount.id).limit(1)) is not None:
                print("An administrator already exists. No new account was created.")
                return 1

            credentials = _read_credentials()
            if credentials is None:
                return 1
            email, password = credentials
            session.add(
                AdminAccount(
                    email=email,
                    password_hash=hash_password(password),
                    is_active=True,
                )
            )
            try:
                session.commit()
            except IntegrityError:
                session.rollback()
                print("Administrator setup could not be completed. No account was created.")
                return 1
        print("First administrator created. The password was not displayed or logged.")
        return 0
    finally:
        engine.dispose()


def main() -> None:
    parser = argparse.ArgumentParser(description="Provision the first MindSpeak administrator locally.")
    parser.add_argument(
        "command",
        choices=("create-first-admin",),
        help="Create one administrator using hidden password prompts; there is no public signup.",
    )
    args = parser.parse_args()
    if args.command == "create-first-admin":
        raise SystemExit(create_first_admin())


if __name__ == "__main__":
    main()
