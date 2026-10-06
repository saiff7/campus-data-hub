"""Extract and census tests against the deployed databases: run with `make test-db`.

The module starts from the deterministic seed and an empty platform, runs the nightly pipeline
and the CENSUS schedule, then checks every extract type against its Python contract and proves
that census reporting is reproducible after the source changes. It leaves the databases reseeded
and empty of operational data, like test_pipeline_db.py.
"""

from collections.abc import Iterator
from pathlib import Path

import pyodbc
import pytest

from campus_ops.config import Settings, get_settings
from campus_ops.db import connect
from campus_ops.extracts import export
from campus_ops.extracts.contracts import CONTRACTS
from campus_ops.generators.dataset import generate_sources
from campus_ops.pipeline import reset_operational_data, run_nightly
from campus_ops.source_writer import replace_source_data

pytestmark = pytest.mark.db

# A period with data for every type in the default seed (generated as of 2026-09-01).
PERIODS: dict[str, str | None] = {
    "ENROLLMENT_CENSUS": "2025FA",
    "AID_PACKAGING": "2025-2026",
    "ACCOUNT_AGING": "2026-09-01",
    "ACADEMIC_PROGRESS": "2026SP",
    "EXCEPTION_WORKLIST": None,
    "LEADERSHIP_KPI": "2025-2026",
    "DQ_SCORECARD": None,
    "IPEDS_FE": "2025FA",
    "IPEDS_E12": "2025-2026",
    "IPEDS_C": "2025-2026",
    "IPEDS_SFA": "2025-2026",
}


def _fresh_platform(settings: Settings) -> None:
    with connect(settings, settings.source_database) as source:
        replace_source_data(source, generate_sources(settings.seed, settings.scale))
    with connect(settings, settings.ops_database, autocommit=True) as ops:
        reset_operational_data(ops)


@pytest.fixture(scope="module")
def settings() -> Settings:
    return get_settings()


@pytest.fixture(scope="module")
def ops(settings: Settings) -> Iterator[pyodbc.Connection]:
    _fresh_platform(settings)
    with connect(settings, settings.ops_database, autocommit=True) as connection:
        run_nightly(connection)
        cursor = connection.cursor()
        cursor.execute("EXEC [compliance].[usp_RunScheduledExtracts] @ScheduleCode = 'CENSUS';")
        while cursor.nextset():
            pass
        yield connection
    _fresh_platform(settings)


def _value(connection: pyodbc.Connection, sql: str, *params: object) -> object:
    row = connection.cursor().execute(sql, *params).fetchone()
    return None if row is None else row[0]


def test_the_contracts_cover_every_governed_extract_type(ops: pyodbc.Connection) -> None:
    types = {
        r[0] for r in ops.cursor().execute("SELECT ExtractTypeCode FROM reference.ExtractType")
    }
    assert types == set(CONTRACTS) == set(PERIODS)


@pytest.mark.parametrize("extract_type", sorted(PERIODS))
def test_every_extract_type_matches_its_contract_and_checksum(
    ops: pyodbc.Connection, extract_type: str, tmp_path: Path
) -> None:
    run_id = export.generate(ops, extract_type, PERIODS[extract_type])
    run = export.fetch(ops, run_id)

    rows = export.verify(run)  # checksum, header, row count and every value type
    assert run.data_row_count > 0, f"{extract_type} produced no rows from the default seed"
    assert run.validation_status in {"PASSED", "WARNING"}
    assert all(c.outcome != "FAIL" for c in run.controls)
    csv_path, manifest_path = export.write(run, tmp_path)
    assert export.sha256_hex(csv_path.read_bytes()) == run.sha256
    assert len(rows) == run.data_row_count + 1
    assert manifest_path.exists()

    exports = _value(
        ops,
        "SELECT COUNT(*) FROM audit.AccessEvent WHERE EventType = 'EXTRACT_EXPORT'"
        " AND ExtractRunId = ? AND IsAllowed = 1;",
        run_id,
    )
    assert exports == 1


def test_the_census_schedule_is_idempotent(ops: pyodbc.Connection) -> None:
    before = _value(ops, "SELECT COUNT(*) FROM compliance.ExtractRun;")
    cursor = ops.cursor()
    cursor.execute("EXEC [compliance].[usp_RunScheduledExtracts] @ScheduleCode = 'CENSUS';")
    while cursor.nextset():
        pass
    assert _value(ops, "SELECT COUNT(*) FROM compliance.ExtractRun;") == before


def test_census_reporting_is_reproducible_after_the_source_changes(
    ops: pyodbc.Connection, settings: Settings
) -> None:
    def census_report() -> list[tuple[object, ...]]:
        rows = (
            ops.cursor()
            .execute("EXEC reporting.usp_ReportEnrollmentByTerm @TermCode = '2025FA';")
            .fetchall()
        )
        return [tuple(r) for r in rows]

    def live_credits(id_number: int) -> object:
        return _value(
            ops,
            "SELECT CensusCredits FROM core.vw_StudentTermCensus"
            " WHERE TermCode = '2025FA' AND IdNumber = ?;",
            id_number,
        )

    report_before = census_report()
    fe_before = export.fetch(ops, export.generate(ops, "IPEDS_FE", "2025FA"))

    # A late correction: a 2025FA section registered before census is recorded as dropped
    # before census, and the student moves to another program.
    with connect(settings, settings.source_database) as source:
        enrollment_id, id_number = source.execute(
            "SELECT TOP (1) e.EnrollmentId, e.IdNumber FROM J1Sim.Enrollment AS e"
            " JOIN J1Sim.CourseSection AS c ON c.CourseSectionId = e.CourseSectionId"
            " WHERE c.TermCode = '2025FA' AND e.RegistrationStatus = 'REGISTERED'"
            " ORDER BY e.EnrollmentId;"
        ).fetchone()
        source.execute(
            "UPDATE J1Sim.Enrollment SET RegistrationStatus = 'DROPPED',"
            " StatusChangedAtUtc = RegisteredAtUtc, UpdatedAtUtc = SYSUTCDATETIME()"
            " WHERE EnrollmentId = ?;",
            enrollment_id,
        )
        source.execute(
            "UPDATE J1Sim.Student SET ProgramCode = CASE WHEN ProgramCode = 'LIBA.AS'"
            " THEN 'BUS.AS' ELSE 'LIBA.AS' END, UpdatedAtUtc = SYSUTCDATETIME()"
            " WHERE IdNumber = ?;",
            id_number,
        )
        source.commit()

    credits_before = live_credits(id_number)
    run_nightly(ops)

    assert live_credits(id_number) != credits_before, "the live data should have changed"
    assert census_report() == report_before
    fe_after = export.fetch(ops, export.generate(ops, "IPEDS_FE", "2025FA"))
    assert fe_after.sha256 == fe_before.sha256
    snapshot_id = _value(
        ops,
        "SELECT s.CensusSnapshotId FROM compliance.CensusSnapshot AS s"
        " JOIN compliance.CensusRuleVersion AS r"
        " ON r.RuleVersion = s.RuleVersion AND r.IsCurrent = 1"
        " WHERE s.TermCode = '2025FA';",
    )
    verification = (
        ops.cursor()
        .execute("EXEC compliance.usp_VerifyCensusSnapshot @CensusSnapshotId = ?;", snapshot_id)
        .fetchone()
    )
    assert verification.IsValid == 1


def test_completed_extract_rows_cannot_be_changed(ops: pyodbc.Connection) -> None:
    run_id = _value(ops, "SELECT MAX(ExtractRunId) FROM compliance.ExtractRun;")
    with pytest.raises(pyodbc.Error, match="52123"):
        ops.cursor().execute(
            "UPDATE compliance.ExtractRow SET LineText = N'tampered' WHERE ExtractRunId = ?"
            " AND LineNumber = 1;",
            run_id,
        )
