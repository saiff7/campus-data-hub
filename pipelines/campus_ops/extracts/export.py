"""Write a stored extract run to a CSV file and a JSON manifest.

Specified in docs/specifications/extract-controls.md.

The file content is the run's lines joined with LF plus a final LF, encoded UTF-8 without a
byte-order mark. The database stored the SHA-256 of exactly those bytes; nothing is written
unless the bytes here hash to the same value and the header equals the type's contract.
"""

import csv
import hashlib
import io
import json
import re
from dataclasses import dataclass
from datetime import date, datetime
from decimal import Decimal, InvalidOperation
from pathlib import Path

import pyodbc

from campus_ops.extracts.contracts import CONTRACTS, Column

SUPPRESSED = "<5"
SUPPRESSION_NOTE = "counts 1-4 shown as <5"
SIMULATION_NOTICE = (
    "Educational simulation built on synthetic data; not an IPEDS submission"
    " and not real student data."
)
_DECIMAL = re.compile(r"^-?\d+(\.\d+)?$")
_INT = re.compile(r"^-?\d+$")


class ExtractError(RuntimeError):
    """A stored run cannot be delivered as it stands."""


@dataclass(frozen=True, slots=True)
class ControlTotal:
    code: str
    kind: str
    expected: Decimal | None
    actual: Decimal
    prior: Decimal | None
    outcome: str
    note: str | None


@dataclass(frozen=True, slots=True)
class StoredRun:
    run_id: int
    extract_type: str
    reporting_period: str
    source_batch_id: int
    census_snapshot_id: int | None
    generator_version: str
    generated_at_utc: datetime
    data_row_count: int
    validation_status: str
    approval_status: str
    description: str
    security_class: str
    is_public_safe: bool
    sha256: str
    controls: tuple[ControlTotal, ...]
    lines: tuple[str, ...]


def file_stem(extract_type: str, reporting_period: str, run_id: int) -> str:
    """`<type, lower case>_<period>_run<6-digit id>`, for example ipeds_fe_2026FA_run000042."""
    if not re.fullmatch(r"[A-Za-z0-9-]+", reporting_period):
        raise ExtractError(f"reporting period {reporting_period!r} is not safe in a file name")
    return f"{extract_type.lower()}_{reporting_period}_run{run_id:06d}"


def render(lines: tuple[str, ...] | list[str]) -> bytes:
    """The exact file bytes the database hashed."""
    return ("\n".join(lines) + "\n").encode("utf-8")


def sha256_hex(content: bytes) -> str:
    return hashlib.sha256(content).hexdigest()


def parse_rows(lines: tuple[str, ...] | list[str]) -> list[list[str]]:
    """Parse the lines as RFC 4180 CSV (quoted fields may contain commas, quotes and newlines)."""
    return list(csv.reader(io.StringIO("\n".join(lines) + "\n", newline="")))


def check_value(column: Column, value: str) -> None:
    """Raise ExtractError when a field does not match its contract type. Empty means NULL."""
    if value == "":
        return
    valid = True
    if column.type in ("int", "count"):
        valid = bool(_INT.match(value))
    elif column.type == "decimal":
        valid = bool(_DECIMAL.match(value))
        if valid:
            try:
                Decimal(value)
            except InvalidOperation:
                valid = False
    elif column.type == "bool":
        valid = value in ("0", "1")
    elif column.type == "date":
        try:
            date.fromisoformat(value)
        except ValueError:
            valid = False
    if not valid:
        raise ExtractError(f"column {column.name} ({column.type}) has invalid value {value!r}")


def verify(run: StoredRun) -> list[list[str]]:
    """Check checksum, header, row count and every value against the contract; return the rows."""
    if run.extract_type not in CONTRACTS:
        raise ExtractError(f"no contract for extract type {run.extract_type}")
    actual = sha256_hex(render(run.lines))
    if actual != run.sha256:
        raise ExtractError(
            f"run {run.run_id}: content SHA-256 {actual} does not equal the stored {run.sha256}"
        )
    rows = parse_rows(run.lines)
    contract = CONTRACTS[run.extract_type]
    if rows[0] != [c.name for c in contract]:
        raise ExtractError(f"run {run.run_id}: header {rows[0]} does not match the contract")
    if len(rows) - 1 != run.data_row_count:
        raise ExtractError(
            f"run {run.run_id}: {len(rows) - 1} data rows, stored {run.data_row_count}"
        )
    for row in rows[1:]:
        if len(row) != len(contract):
            raise ExtractError(
                f"run {run.run_id}: a row has {len(row)} fields, expected {len(contract)}"
            )
        for column, value in zip(contract, row, strict=True):
            check_value(column, value)
    return rows


def suppress(run: StoredRun, rows: list[list[str]]) -> bytes:
    """Public copy: every count column value from 1 to 4 becomes <5. Only public-safe types."""
    if not run.is_public_safe:
        raise ExtractError(
            f"{run.extract_type} is {run.security_class}; only aggregate, public-safe extracts"
            " may be copied to sample-output"
        )
    contract = CONTRACTS[run.extract_type]
    out = io.StringIO(newline="")
    writer = csv.writer(out, lineterminator="\n")
    writer.writerow(rows[0])
    for row in rows[1:]:
        writer.writerow(
            SUPPRESSED if c.type == "count" and v.isdigit() and 1 <= int(v) <= 4 else v  # noqa: PLR2004
            for c, v in zip(contract, row, strict=True)
        )
    return out.getvalue().encode("utf-8")


def manifest(run: StoredRun, content: bytes, *, public: bool) -> dict[str, object]:
    document: dict[str, object] = {
        "extract_run_id": run.run_id,
        "extract_type": run.extract_type,
        "description": run.description,
        "reporting_period": run.reporting_period,
        "source_batch_id": run.source_batch_id,
        "census_snapshot_id": run.census_snapshot_id,
        "generated_at_utc": run.generated_at_utc.isoformat(timespec="milliseconds") + "Z",
        "generator_version": run.generator_version,
        "row_count": run.data_row_count,
        "columns": [{"name": c.name, "type": c.type} for c in CONTRACTS[run.extract_type]],
        "sha256": sha256_hex(content),
        "validation_status": run.validation_status,
        "approval_status": run.approval_status,
        "security_class": run.security_class,
        "control_totals": [
            {
                "code": c.code,
                "kind": c.kind,
                "expected": None if c.expected is None else str(c.expected),
                "actual": str(c.actual),
                "prior": None if c.prior is None else str(c.prior),
                "outcome": c.outcome,
                "note": c.note,
            }
            for c in run.controls
        ],
        "notice": SIMULATION_NOTICE,
    }
    if public:
        document["suppression"] = SUPPRESSION_NOTE
        document["source_sha256"] = run.sha256
    return document


def write(run: StoredRun, out_dir: Path, *, public: bool = False) -> tuple[Path, Path]:
    """Verify the run, then write `<stem>.csv` and `<stem>.manifest.json`. Returns both paths."""
    rows = verify(run)
    content = suppress(run, rows) if public else render(run.lines)
    out_dir.mkdir(parents=True, exist_ok=True)
    stem = file_stem(run.extract_type, run.reporting_period, run.run_id)
    csv_path = out_dir / f"{stem}.csv"
    manifest_path = out_dir / f"{stem}.manifest.json"
    csv_path.write_bytes(content)
    manifest_path.write_text(
        json.dumps(manifest(run, content, public=public), indent=2) + "\n", encoding="utf-8"
    )
    return csv_path, manifest_path


def fetch(connection: pyodbc.Connection, run_id: int) -> StoredRun:
    """Read a run through the audited export procedure (three result sets)."""
    cursor = connection.cursor()
    cursor.execute("EXEC [compliance].[usp_GetExtractForExport] @ExtractRunId = ?;", run_id)
    head = cursor.fetchone()
    cursor.nextset()
    controls = tuple(
        ControlTotal(r[0], r[1], r[3], r[4], r[6], r[9], r[10]) for r in cursor.fetchall()
    )
    cursor.nextset()
    lines = tuple(r[1] for r in cursor.fetchall())
    if head is None:
        raise ExtractError(f"run {run_id} returned no metadata")
    return StoredRun(
        run_id=head.ExtractRunId,
        extract_type=head.ExtractTypeCode,
        reporting_period=head.ReportingPeriod,
        source_batch_id=head.SourceBatchId,
        census_snapshot_id=head.CensusSnapshotId,
        generator_version=head.GeneratorVersion,
        generated_at_utc=head.GeneratedAtUtc,
        data_row_count=head.DataRowCount,
        validation_status=head.ValidationStatusCode,
        approval_status=head.ApprovalStatusCode,
        description=head.Description,
        security_class=head.SecurityClass,
        is_public_safe=bool(head.IsPublicSafe),
        sha256=head.ContentSha256,
        controls=controls,
        lines=lines,
    )


def generate(connection: pyodbc.Connection, extract_type: str, period: str | None) -> int:
    """Generate a run in the database (the same procedure the Agent jobs call); return its id."""
    row = (
        connection.cursor()
        .execute(
            "SET NOCOUNT ON; DECLARE @Id BIGINT;"
            " EXEC [compliance].[usp_GenerateExtract] @ExtractTypeCode = ?, @ReportingPeriod = ?,"
            " @ExtractRunId = @Id OUTPUT, @ReturnSummary = 0; SELECT @Id;",
            extract_type,
            period,
        )
        .fetchone()
    )
    if row is None or row[0] is None:
        raise ExtractError("the database returned no extract run id")
    return int(row[0])
