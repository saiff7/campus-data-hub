"""Generate docs/DATA-DICTIONARY.md from the deployed CampusDataOps catalog.

    make data-dictionary

Columns and types come from the database; each object's description is the leading comment of
its SQL file, so the dictionary cannot disagree with the code.
"""

import re
from pathlib import Path

from campus_ops.config import get_settings
from campus_ops.db import connect

REPO = Path(__file__).resolve().parents[2]
PROJECT = REPO / "database" / "CampusDataOps.Database"
OUTPUT = REPO / "docs" / "DATA-DICTIONARY.md"

SCHEMAS = {
    "reference": "Governed codes and calendars, seeded on every deploy.",
    "audit": "Batches, steps, errors, privileged access and permission changes.",
    "landing": "Append-only source rows as received (ADR-002). Denied to every role.",
    "staging": "Current standardized rows. Denied to every role.",
    "core": "Conformed views over staging (decision D3). Denied to every role.",
    "integration": "Matching, exceptions, the outbound queue and reconciliation.",
    "dq": "Data-quality rules, runs, results and dispositions.",
    "reporting": "The six report datasets and their procedures.",
    "compliance": "Census snapshots, measures, extract runs and IPEDS-aligned views.",
    "security": "Supporting tables for roles, masking and row-level security.",
    "bi": "Masked star schema for Power BI.",
}
KINDS = {"USER_TABLE": "table", "VIEW": "view", "SQL_INLINE_TABLE_VALUED_FUNCTION": "function"}
CATALOG = """
SELECT s.name, o.name, o.type_desc, c.name, TYPE_NAME(c.user_type_id), c.max_length,
       c.precision, c.scale, c.is_nullable
FROM sys.objects AS o
JOIN sys.schemas AS s ON s.schema_id = o.schema_id
JOIN sys.columns AS c ON c.object_id = o.object_id
WHERE o.type IN ('U', 'V', 'IF')
ORDER BY s.name, o.name, c.column_id;
"""
HEADER = """# Data dictionary

Every table and view in CampusDataOps, by schema, generated from the deployed database catalog
by `make data-dictionary`. Descriptions are the leading comment of each object's SQL file.
Business definitions are in the [business glossary](specifications/business-glossary.md) and
the [report catalog](specifications/report-catalog.md); who may read what is in the
[security model](architecture/security-model.md).
"""


def descriptions() -> dict[tuple[str, str], str]:
    found = {}
    for path in PROJECT.rglob("*.sql"):
        text = path.read_text(encoding="utf-8")
        match = re.search(r"CREATE (?:TABLE|VIEW|FUNCTION) \[(\w+)\]\.\[(\w+)\]", text)
        if match:
            comment = []
            for line in text.splitlines():
                if not line.startswith("--"):
                    break
                comment.append(line[2:].strip())
            found[(match.group(1), match.group(2))] = " ".join(comment)
    return found


def type_name(name: str, max_length: int, precision: int, scale: int) -> str:
    if name in ("varchar", "char", "varbinary", "binary"):
        return f"{name}({'max' if max_length == -1 else max_length})"
    if name in ("nvarchar", "nchar"):
        return f"{name}({'max' if max_length == -1 else max_length // 2})"
    if name in ("decimal", "numeric"):
        return f"{name}({precision},{scale})"
    if name == "datetime2":
        return f"datetime2({scale})"
    return name


def main() -> None:
    settings = get_settings()
    with connect(settings, settings.ops_database, autocommit=True) as connection:
        rows = connection.cursor().execute(CATALOG).fetchall()
    objects: dict[tuple[str, str, str], list[str]] = {}
    for schema, name, kind, column, data_type, max_length, precision, scale, nullable in rows:
        if schema in SCHEMAS:
            objects.setdefault((schema, name, kind), []).append(
                f"| `{column}` | {type_name(data_type, max_length, precision, scale)}"
                f" | {'yes' if nullable else 'no'} |"
            )
    notes = descriptions()
    out = [HEADER]
    for schema, purpose in SCHEMAS.items():
        keys = sorted((k for k in objects if k[0] == schema), key=lambda k: k[1])
        if not keys:
            continue
        out += [f"## {schema}", "", purpose, ""]
        for _, name, kind in keys:
            out += [f"### `{schema}.{name}` ({KINDS[kind]})", ""]
            if notes.get((schema, name)):
                out += [notes[(schema, name)], ""]
            out += [
                "| Column | Type | Nullable |",
                "|---|---|---|",
                *objects[(schema, name, kind)],
                "",
            ]
    OUTPUT.write_text("\n".join(out).rstrip() + "\n", encoding="utf-8")
    print(f"wrote {len(objects)} objects to {OUTPUT.relative_to(REPO)}")


if __name__ == "__main__":
    main()
