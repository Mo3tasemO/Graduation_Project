from sqlalchemy import Engine, create_engine, event, inspect
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker


class Base(DeclarativeBase):
    """Base class used by SQLAlchemy database models."""


def create_database_engine(database_url: str) -> Engine:
    options = {"check_same_thread": False} if database_url.startswith("sqlite") else {}
    engine = create_engine(database_url, connect_args=options)

    if database_url.startswith("sqlite"):
        @event.listens_for(engine, "connect")
        def enable_foreign_keys(dbapi_connection, _connection_record) -> None:
            cursor = dbapi_connection.cursor()
            cursor.execute("PRAGMA foreign_keys=ON")
            cursor.close()

    return engine


def create_session_factory(engine: Engine) -> sessionmaker[Session]:
    return sessionmaker(bind=engine, autoflush=False, autocommit=False)


def initialize_database(engine: Engine) -> None:
    """Create new tables and apply non-destructive additions for existing users."""
    from . import models  # noqa: F401 - register all model tables before create_all

    Base.metadata.create_all(bind=engine)
    if "email_verified_at" not in {column["name"] for column in inspect(engine).get_columns("users")}:
        with engine.begin() as connection:
            connection.exec_driver_sql("ALTER TABLE users ADD COLUMN email_verified_at DATETIME")
            # Existing accounts predate mandatory verification. Preserve them as legacy verified users.
            connection.exec_driver_sql(
                "UPDATE users SET email_verified_at = created_at WHERE email_verified_at IS NULL"
            )


