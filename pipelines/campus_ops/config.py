"""Runtime settings, read from environment variables and the local .env file."""

from functools import lru_cache

from pydantic import AliasChoices, Field, SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_prefix="CAMPUS_", env_file=".env", env_file_encoding="utf-8", extra="ignore"
    )

    db_server: str = "localhost,1433"
    db_user: str = "sa"
    # Falls back to the container's SA password so local setup needs a single secret.
    db_password: SecretStr | None = Field(
        default=None, validation_alias=AliasChoices("CAMPUS_DB_PASSWORD", "MSSQL_SA_PASSWORD")
    )
    db_driver: str = "ODBC Driver 18 for SQL Server"
    # Only for the local container's self-signed certificate; keep false elsewhere.
    db_trust_server_certificate: bool = False
    db_login_timeout_seconds: int = Field(default=15, gt=0)
    source_database: str = "SourceSystems"
    ops_database: str = "CampusDataOps"
    seed: int = 20260901
    scale: float = Field(default=1.0, gt=0, le=20)
    log_level: str = "INFO"


@lru_cache
def get_settings() -> Settings:
    return Settings()
