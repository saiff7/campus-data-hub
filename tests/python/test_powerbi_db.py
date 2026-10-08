"""The generated TMDL tables must match the deployed bi views: run with `make test-db`.
Regenerate with powerbi/tools/generate_tmdl.py after changing a bi view."""

import re
from pathlib import Path

import pytest

from campus_ops.config import get_settings
from campus_ops.db import connect

pytestmark = pytest.mark.db

TABLES = (
    Path(__file__).resolve().parents[2] / "powerbi/CampusDataOps.SemanticModel/definition/tables"
)


def test_tmdl_tables_match_the_bi_views() -> None:
    settings = get_settings()
    with connect(settings, settings.ops_database, autocommit=True) as connection:
        rows = (
            connection.cursor()
            .execute(
                "SELECT TABLE_NAME, COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS"
                " WHERE TABLE_SCHEMA = 'bi' ORDER BY TABLE_NAME, ORDINAL_POSITION;"
            )
            .fetchall()
        )
    database: dict[str, list[str]] = {}
    for table, column in rows:
        database.setdefault(table, []).append(column)
    model = {
        path.stem: re.findall(r"^\tcolumn (\S+)", path.read_text(), re.M)
        for path in TABLES.glob("*.tmdl")
        if path.stem != "_Measures"
    }
    assert model == database
