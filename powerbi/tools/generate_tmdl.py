"""Generate the PBIP semantic model (TMDL) for the bi star schema from the deployed views.

    DYLD_LIBRARY_PATH=... uv run python powerbi/tools/generate_tmdl.py

Table and column definitions come from the database's own metadata for schema bi, so names and
types cannot drift from SQL. Relationships, measures and roles are declared below and in
powerbi/dax/Measures.dax. tests/python/test_powerbi_model.py checks the result. The output has
NOT been opened in Power BI Desktop (see docs/powerbi/WINDOWS-BUILD-STEPS.md).
"""

import re
import uuid
from pathlib import Path

from campus_ops.config import get_settings
from campus_ops.db import connect

ROOT = Path(__file__).resolve().parents[1]
MODEL = ROOT / "CampusDataOps.SemanticModel" / "definition"
NAMESPACE = uuid.UUID("6f2b2f0e-6b3c-4f5e-9b1a-2c7c1d0e5a10")

TYPES = {
    "int": "int64", "bigint": "int64", "smallint": "int64", "tinyint": "int64",
    "decimal": "decimal", "numeric": "decimal", "float": "double",
    "date": "dateTime", "datetime2": "dateTime", "datetime": "dateTime",
    "bit": "boolean", "char": "string", "varchar": "string", "nvarchar": "string",
    "nchar": "string",
}  # fmt: skip
FORMATS = {"dateTime": "yyyy-mm-dd", "decimal": "#,0.00", "int64": "0"}
HIDDEN_KEYS = {"StudentKey", "CensusSnapshotId", "AwardId", "BatchStepId", "DateKey"}

# (from table, from column, to table, to column, active)
RELATIONSHIPS = [
    ("FactCensusEnrollment", "TermCode", "DimTerm", "TermCode", True),
    ("FactCensusEnrollment", "ProgramCode", "DimProgram", "ProgramCode", True),
    ("FactCensusEnrollment", "StudentKey", "DimStudent", "StudentKey", True),
    ("FactApplicationFunnel", "TermCode", "DimTerm", "TermCode", True),
    ("FactApplicationFunnel", "ProgramCode", "DimProgram", "ProgramCode", True),
    ("FactAidAward", "TermCode", "DimTerm", "TermCode", True),
    ("FactAidAward", "StudentKey", "DimStudent", "StudentKey", True),
    ("FactAccountBalance", "StudentKey", "DimStudent", "StudentKey", True),
    ("FactCourseOutcome", "TermCode", "DimTerm", "TermCode", True),
    ("FactCourseOutcome", "ProgramCode", "DimProgram", "ProgramCode", True),
    ("FactIntegrationRun", "RunDate", "DimDate", "Date", True),
    (
        "FactIntegrationException",
        "ExceptionReasonCode",
        "DimExceptionReason",
        "ExceptionReasonCode",
        True,
    ),
    ("FactIntegrationException", "CreatedDate", "DimDate", "Date", True),
    ("FactDataQualityResult", "RuleCode", "DimDataQualityRule", "RuleCode", True),
    ("FactDataQualityResult", "RunDate", "DimDate", "Date", True),
    ("DimDate", "TermCode", "DimTerm", "TermCode", True),
    ("DimExceptionReason", "OwnerDepartment", "DimDepartment", "DepartmentName", True),
    ("DimDataQualityRule", "OwnerDepartment", "DimDepartment", "DepartmentName", True),
]

DIVISIONS = {
    "Business and Technology": "BUSINESS_TECHNOLOGY",
    "Health Sciences": "HEALTH_SCIENCES",
    "Human Services": "HUMAN_SERVICES",
    "Liberal Arts": "LIBERAL_ARTS",
    "Trades": "TRADES",
}


def tag(*parts: str) -> str:
    return str(uuid.uuid5(NAMESPACE, "/".join(parts)))


def quote(name: str) -> str:
    return (
        name
        if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", name)
        else "'" + name.replace("'", "''") + "'"
    )


def table_tmdl(table: str, columns: list[tuple[str, str]]) -> str:
    lines = [f"table {table}", f"\tlineageTag: {tag(table)}", ""]
    for name, sql_type in columns:
        data_type = TYPES[sql_type]
        lines += [f"\tcolumn {quote(name)}", f"\t\tdataType: {data_type}"]
        if data_type in FORMATS:
            lines.append(f"\t\tformatString: {FORMATS[data_type]}")
        if name in HIDDEN_KEYS:
            lines.append("\t\tisHidden")
        lines += [
            f"\t\tlineageTag: {tag(table, name)}",
            "\t\tsummarizeBy: none",
            f"\t\tsourceColumn: {name}",
            "",
        ]
    lines += [
        f"\tpartition {table} = m",
        "\t\tmode: import",
        "\t\tsource =",
        "\t\t\t\tlet",
        "\t\t\t\t    Source = Sql.Database(SqlServer, Database),",
        f'\t\t\t\t    Data = Source{{[Schema="bi", Item="{table}"]}}[Data]',
        "\t\t\t\tin",
        "\t\t\t\t    Data",
        "",
    ]
    return "\n".join(lines)


def measures_tmdl(dax: str) -> str:
    """Build the Measures table from Measures.dax blocks (`// folder:`, then `Name = expr`)."""
    lines = ["table Measures", f"\tlineageTag: {tag('Measures')}", ""]
    folder = "General"
    for block in re.split(r"\n\s*\n", dax.strip()):
        for raw in block.splitlines():
            if raw.startswith("// folder:"):
                folder = raw.split(":", 1)[1].strip()
        body = [raw for raw in block.splitlines() if not raw.startswith("//")]
        if not body:
            continue
        head = re.match(r"^(.+?)\s*=\s*(.*)$", body[0])
        if head is None:
            raise ValueError(f"not a measure definition: {body[0]!r}")
        name, first = head.group(1).strip().strip("[]"), head.group(2)
        expression = [first.strip(), *[raw.rstrip() for raw in body[1:]]]
        fmt = re.search(r"//\s*format:\s*(.+)$", block, re.M)
        expression = [e for e in expression if e.strip()]
        if len(expression) == 1:
            lines.append(f"\tmeasure {quote(name)} = {expression[0]}")
        else:
            lines.append(f"\tmeasure {quote(name)} =")
            lines += [f"\t\t\t{e.strip()}" for e in expression if e.strip()]
        if fmt:
            lines.append(f"\t\tformatString: {fmt.group(1).strip()}")
        lines += [f"\t\tdisplayFolder: {folder}", f"\t\tlineageTag: {tag('Measures', name)}", ""]
    lines += [
        "\tcolumn Value",
        "\t\tdataType: string",
        "\t\tisHidden",
        f"\t\tlineageTag: {tag('Measures', 'Value')}",
        "\t\tsummarizeBy: none",
        "\t\tsourceColumn: [Value]",
        "",
        "\tpartition Measures = calculated",
        "\t\tmode: import",
        '\t\tsource = ROW("Value", BLANK())',
        "",
    ]
    return "\n".join(lines)


def main() -> None:
    settings = get_settings()
    with connect(settings, settings.ops_database, autocommit=True) as connection:
        rows = (
            connection.cursor()
            .execute(
                "SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS"
                " WHERE TABLE_SCHEMA = 'bi' ORDER BY TABLE_NAME, ORDINAL_POSITION;"
            )
            .fetchall()
        )
    tables: dict[str, list[tuple[str, str]]] = {}
    for table, column, data_type in rows:
        tables.setdefault(table, []).append((column, data_type))

    (MODEL / "tables").mkdir(parents=True, exist_ok=True)
    for old in (MODEL / "tables").glob("*.tmdl"):
        old.unlink()
    for table, columns in tables.items():
        (MODEL / "tables" / f"{table}.tmdl").write_text(table_tmdl(table, columns))
    dax = (ROOT / "dax" / "Measures.dax").read_text()
    (MODEL / "tables" / "Measures.tmdl").write_text(measures_tmdl(dax))

    rel = []
    for from_table, from_col, to_table, to_col, active in RELATIONSHIPS:
        rel += [f"relationship {tag('rel', from_table, from_col, to_table)}"]
        if not active:
            rel.append("\tisActive: false")
        rel += [f"\tfromColumn: {from_table}.{from_col}", f"\ttoColumn: {to_table}.{to_col}", ""]
    (MODEL / "relationships.tmdl").write_text("\n".join(rel))

    (MODEL / "roles").mkdir(exist_ok=True)
    for old in (MODEL / "roles").glob("*.tmdl"):
        old.unlink()
    (MODEL / "roles" / "Leadership.tmdl").write_text(
        f"role Leadership\n\tmodelPermission: read\n\tlineageTag: {tag('role', 'Leadership')}\n"
    )
    for label, code in DIVISIONS.items():
        name = f"Division - {label}"
        (MODEL / "roles" / f"Division {label}.tmdl").write_text(
            "\n".join(
                [
                    f"role '{name}'",
                    "\tmodelPermission: read",
                    f"\tlineageTag: {tag('role', name)}",
                    "",
                    f'\ttablePermission DimProgram = [DivisionCode] = "{code}"',
                    "",
                    "\ttablePermission FactAidAward = FALSE()",
                    "",
                    "\ttablePermission FactAccountBalance = FALSE()",
                    "",
                ]
            )
        )

    model = [
        "model Model",
        "\tculture: en-US",
        "\tdefaultPowerBIDataSourceVersion: powerBI_V3",
        "\tsourceQueryCulture: en-US",
        "\tdataAccessOptions",
        "\t\tlegacyRedirects",
        "\t\treturnErrorValuesAsNull",
        "",
        *[f"ref table {t}" for t in [*tables, "Measures"]],
        "",
        "ref role Leadership",
        *[f"ref role 'Division - {label}'" for label in DIVISIONS],
        "",
    ]
    (MODEL / "model.tmdl").write_text("\n".join(model))
    print(
        f"wrote {len(tables)} tables, {len(RELATIONSHIPS)} relationships,"
        f" {len(DIVISIONS) + 1} roles"
    )


if __name__ == "__main__":
    main()
