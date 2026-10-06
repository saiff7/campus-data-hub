"""Extract file contracts without a database: naming, exact bytes and checksum, header and type
checks, public suppression and manifests (docs/specifications/extract-controls.md)."""

import csv
import io
import json
from datetime import datetime
from decimal import Decimal
from pathlib import Path

import pytest

from campus_ops.extracts import export
from campus_ops.extracts.contracts import CONTRACTS


def _run(extract_type: str, data: list[list[str]], **overrides: object) -> export.StoredRun:
    header = ",".join(c.name for c in CONTRACTS[extract_type])
    out = io.StringIO(newline="")
    csv.writer(out, lineterminator="\n").writerows(data)
    lines = (header, *out.getvalue().splitlines())
    values: dict[str, object] = {
        "run_id": 42,
        "extract_type": extract_type,
        "reporting_period": "2025FA",
        "source_batch_id": 7,
        "census_snapshot_id": 3,
        "generator_version": "1.0",
        "generated_at_utc": datetime(2026, 10, 5, 6, 0, 0),
        "data_row_count": len(data),
        "validation_status": "PASSED",
        "approval_status": "PENDING",
        "description": "test",
        "security_class": "INTERNAL_AGGREGATE",
        "is_public_safe": True,
        "sha256": export.sha256_hex(export.render(lines)),
        "controls": (
            export.ControlTotal(
                "TOTAL_HEADCOUNT", "RECONCILIATION", Decimal(7), Decimal(7), None, "PASS", None
            ),
        ),
        "lines": lines,
    }
    values.update(overrides)
    return export.StoredRun(**values)  # type: ignore[arg-type]


MANIFEST_KEYS = {
    "extract_run_id",
    "extract_type",
    "reporting_period",
    "source_batch_id",
    "census_snapshot_id",
    "generated_at_utc",
    "generator_version",
    "row_count",
    "columns",
    "sha256",
    "validation_status",
    "approval_status",
    "control_totals",
    "security_class",
    "notice",
}

FE_ROWS = [
    ["2025FA", "PART_A", "FULL_TIME", "ENTERING", "DOMESTIC", "ALL", "3"],
    ["2025FA", "PART_A", "PART_TIME", "CONTINUING", "INTERNATIONAL", "ALL", "4"],
    ["2025FA", "PART_B", "FULL_TIME", "ALL", "ALL", "18-19", "5"],
    ["2025FA", "TOTAL", "ALL", "ALL", "ALL", "ALL", "7"],
]


def test_file_names_follow_the_convention() -> None:
    assert export.file_stem("IPEDS_FE", "2026FA", 42) == "ipeds_fe_2026FA_run000042"
    assert export.file_stem("AID_PACKAGING", "2025-2026", 7) == "aid_packaging_2025-2026_run000007"
    with pytest.raises(export.ExtractError):
        export.file_stem("IPEDS_FE", "../etc", 1)


def test_render_is_lf_joined_utf8_with_a_final_newline_and_no_bom() -> None:
    content = export.render(["a,b", 'Zoë,"x"'])
    assert content == 'a,b\nZoë,"x"\n'.encode()
    assert not content.startswith(b"\xef\xbb\xbf")


def test_every_contract_has_unique_named_columns() -> None:
    assert set(CONTRACTS) == {
        "ENROLLMENT_CENSUS", "AID_PACKAGING", "ACCOUNT_AGING", "ACADEMIC_PROGRESS",
        "EXCEPTION_WORKLIST", "LEADERSHIP_KPI", "DQ_SCORECARD",
        "IPEDS_FE", "IPEDS_E12", "IPEDS_C", "IPEDS_SFA",
    }  # fmt: skip
    for columns in CONTRACTS.values():
        names = [c.name for c in columns]
        assert len(names) == len(set(names))
        assert all(n and n[0].isupper() and n.isalnum() for n in names)


def test_only_ipeds_aggregates_have_suppressible_counts() -> None:
    for extract_type, columns in CONTRACTS.items():
        has_count = any(c.type == "count" for c in columns)
        assert has_count == extract_type.startswith("IPEDS_"), extract_type


def test_a_checksum_mismatch_is_refused(tmp_path: Path) -> None:
    run = _run("IPEDS_FE", FE_ROWS, sha256="0" * 64)
    with pytest.raises(export.ExtractError, match="SHA-256"):
        export.write(run, tmp_path)
    assert not list(tmp_path.iterdir())


def test_a_header_that_differs_from_the_contract_is_refused(tmp_path: Path) -> None:
    lines = ("ReportingPeriod,Section,Headcount", "2025FA,TOTAL,7")
    run = _run(
        "IPEDS_FE",
        [],
        lines=lines,
        data_row_count=1,
        sha256=export.sha256_hex(export.render(lines)),
    )
    with pytest.raises(export.ExtractError, match="header"):
        export.write(run, tmp_path)


@pytest.mark.parametrize(
    ("value", "column_type"),
    [
        ("12.5x", "decimal"),
        ("1.0", "int"),
        ("2", "bool"),
        ("2026-13-01", "date"),
        ("seven", "count"),
    ],
)
def test_values_must_match_their_column_type(value: str, column_type: str) -> None:
    column = export.Column("Probe", column_type)  # type: ignore[arg-type]
    with pytest.raises(export.ExtractError):
        export.check_value(column, value)
    export.check_value(column, "")  # empty means NULL in every type


def test_quoted_fields_with_commas_and_quotes_round_trip() -> None:
    rows = [["1", "5", "RULE", "ENTITY", "LOW", 'Registrar, "Records"', "10", "0", "1.000000"]]
    run = _run("DQ_SCORECARD", rows)
    assert export.verify(run)[1] == rows[0]


def test_a_stored_run_writes_exact_bytes_and_a_complete_manifest(tmp_path: Path) -> None:
    run = _run("IPEDS_FE", FE_ROWS)
    csv_path, manifest_path = export.write(run, tmp_path)

    assert csv_path.name == "ipeds_fe_2025FA_run000042.csv"
    assert csv_path.read_bytes() == export.render(run.lines)
    document = json.loads(manifest_path.read_text())
    assert document["sha256"] == run.sha256 == export.sha256_hex(csv_path.read_bytes())
    assert document.keys() >= MANIFEST_KEYS
    assert document["row_count"] == len(FE_ROWS)
    assert document["control_totals"][0]["outcome"] == "PASS"
    assert "suppression" not in document


def test_a_public_copy_suppresses_small_counts_and_says_so(tmp_path: Path) -> None:
    run = _run("IPEDS_FE", FE_ROWS)
    csv_path, manifest_path = export.write(run, tmp_path, public=True)

    counts = [row[-1] for row in csv.reader(io.StringIO(csv_path.read_text()))][1:]
    assert counts == ["<5", "<5", "5", "7"]
    document = json.loads(manifest_path.read_text())
    assert document["suppression"] == export.SUPPRESSION_NOTE
    assert document["source_sha256"] == run.sha256
    assert document["sha256"] == export.sha256_hex(csv_path.read_bytes())


def test_a_student_level_extract_can_never_be_copied_publicly(tmp_path: Path) -> None:
    data = [["42", "2025-2026", "PELL", "FEDERAL", "GRANT", "1"] + ["100.00"] * 6]
    run = _run(
        "AID_PACKAGING",
        data,
        reporting_period="2025-2026",
        security_class="CONFIDENTIAL_STUDENT",
        is_public_safe=False,
    )
    with pytest.raises(export.ExtractError, match="public-safe"):
        export.write(run, tmp_path, public=True)
    assert not list(tmp_path.iterdir())
