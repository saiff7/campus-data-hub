"""SQL Server connections over ODBC Driver 18. Connections always request encryption."""

from collections.abc import Iterator
from contextlib import contextmanager

import pyodbc

from campus_ops.config import Settings


class ConfigurationError(RuntimeError):
    """Raised when required connection settings are missing."""


def _odbc_value(value: str) -> str:
    # Brace-quote so passwords containing ';' or '}' cannot break the connection string.
    return "{" + value.replace("}", "}}") + "}"


def connection_string(settings: Settings, database: str) -> str:
    if settings.db_password is None:
        raise ConfigurationError(
            "No database password configured: set MSSQL_SA_PASSWORD or CAMPUS_DB_PASSWORD in .env"
        )
    parts = {
        "DRIVER": _odbc_value(settings.db_driver),
        "SERVER": settings.db_server,
        "DATABASE": _odbc_value(database),
        "UID": _odbc_value(settings.db_user),
        "PWD": _odbc_value(settings.db_password.get_secret_value()),
        "Encrypt": "yes",
        "TrustServerCertificate": "yes" if settings.db_trust_server_certificate else "no",
        "APP": "campus-data-hub",
    }
    return ";".join(f"{key}={value}" for key, value in parts.items())


@contextmanager
def connect(
    settings: Settings, database: str, *, autocommit: bool = False
) -> Iterator[pyodbc.Connection]:
    """Open a connection. Autocommit is off unless requested: callers that only invoke stored
    procedures which manage their own transactions (the pipeline) pass autocommit=True."""
    connection = pyodbc.connect(
        connection_string(settings, database),
        autocommit=autocommit,
        timeout=settings.db_login_timeout_seconds,
    )
    try:
        yield connection
    finally:
        connection.close()
