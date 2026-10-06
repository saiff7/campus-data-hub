"""End-to-end pipeline tests against the deployed databases: run with `make test-db`.

Each scenario starts from the deterministic seed and an empty operational platform, runs the
real stored procedures through campus_ops.pipeline, and checks the outcomes the Part 2
acceptance criteria name. The module leaves the databases reseeded and empty of operational
data, the state `make seed` followed by `make reset-ops` produces.
"""

from collections.abc import Iterator

import pyodbc
import pytest

from campus_ops.config import Settings, get_settings
from campus_ops.db import connect
from campus_ops.generators.dataset import generate_sources
from campus_ops.generators.edge_cases import (
    AMBIGUOUS_MATCH,
    DUPLICATE_PERSON,
    INVALID_TERM,
    MALFORMED_EMAIL,
    MISSING_PROGRAM,
    ORPHAN_DIRECTORY_ACCOUNT,
)
from campus_ops.pipeline import (
    STEPS,
    PipelineError,
    recover,
    reset_operational_data,
    run_nightly,
    run_steps,
    run_summary,
)
from campus_ops.source_writer import replace_source_data

pytestmark = pytest.mark.db

MISSING_PROGRAM_APPLICATION = MISSING_PROGRAM.keys["slate_application_id"]


@pytest.fixture(scope="module")
def settings() -> Settings:
    return get_settings()


def _fresh_platform(settings: Settings) -> None:
    with connect(settings, settings.source_database) as source:
        replace_source_data(source, generate_sources(settings.seed, settings.scale))
    with connect(settings, settings.ops_database, autocommit=True) as ops:
        reset_operational_data(ops)


@pytest.fixture(scope="module", autouse=True)
def leave_clean_platform(settings: Settings) -> Iterator[None]:
    yield
    _fresh_platform(settings)


@pytest.fixture
def ops(settings: Settings) -> Iterator[pyodbc.Connection]:
    _fresh_platform(settings)
    with connect(settings, settings.ops_database, autocommit=True) as connection:
        yield connection


def _value(connection: pyodbc.Connection, sql: str, *params: object) -> object:
    row = connection.cursor().execute(sql, *params).fetchone()
    return None if row is None else row[0]


def _exception_statuses(connection: pyodbc.Connection, application_id: str) -> dict[str, str]:
    rows = (
        connection.cursor()
        .execute(
            "SELECT e.ExceptionReasonCode, e.ExceptionStatusCode, e.DetailCode"
            " FROM integration.IntegrationException AS e WHERE e.ApplicationId = ?;",
            application_id,
        )
        .fetchall()
    )
    return {reason: status for reason, status, _ in rows}


def _counts(connection: pyodbc.Connection) -> dict[str, int]:
    tables = (
        "integration.MatchDecision",
        "integration.IntegrationException",
        "integration.ExceptionAction",
        "integration.OutboundStudentQueue",
        "integration.SourceCrosswalk",
        "SourceSystems.J1Sim.IntegrationReceipt",
        "SourceSystems.J1Sim.Person",
        "SourceSystems.J1Sim.Student",
    )
    return {
        table: int(_value(connection, f"SELECT COUNT_BIG(*) FROM {table};"))  # noqa: S608
        for table in tables
    }


def test_python_steps_match_the_governed_pipeline_steps(ops: pyodbc.Connection) -> None:
    rows = ops.cursor().execute("SELECT StepCode FROM reference.PipelineStep ORDER BY StepOrder;")
    assert tuple(row.StepCode for row in rows) == STEPS


def test_a_full_run_reconciles_and_handles_every_edge_case(ops: pyodbc.Connection) -> None:
    batch_id = run_nightly(ops)
    summary = run_summary(ops, batch_id)

    assert summary.status == "SUCCEEDED"
    assert summary.is_balanced is True
    assert summary.source_eligible == (
        summary.unchanged + summary.matched + summary.created + summary.rejected + summary.pending
    )
    assert summary.target_confirmed == summary.matched + summary.created

    ambiguous = AMBIGUOUS_MATCH.keys["slate_application_id"]
    assert _exception_statuses(ops, ambiguous) == {"AMBIGUOUS_MATCH": "OPEN"}
    queued = _value(
        ops,
        "SELECT COUNT(*) FROM integration.OutboundStudentQueue WHERE ApplicationId = ?;",
        ambiguous,
    )
    assert queued == 0
    assert (
        _value(
            ops,
            "SELECT DetailCode FROM integration.IntegrationException"
            " WHERE ApplicationId = ? AND ExceptionReasonCode = 'MISSING_REQUIRED_FIELD';",
            MISSING_PROGRAM_APPLICATION,
        )
        == "PROGRAM"
    )
    assert _exception_statuses(ops, INVALID_TERM.keys["slate_application_id"]) == {
        "INVALID_ENTRY_TERM": "OPEN"
    }

    # A non-blocking exception: the applicant is created without the invalid email.
    malformed = MALFORMED_EMAIL.keys["slate_application_id"]
    assert _exception_statuses(ops, malformed) == {"INVALID_CONTACT_FORMAT": "OPEN"}
    assert (
        _value(
            ops,
            "SELECT p.Email FROM integration.OutboundStudentQueue AS q"
            " JOIN SourceSystems.J1Sim.Person AS p ON p.IdNumber = q.ResultIdNumber"
            " WHERE q.ApplicationId = ? AND q.QueueStatusCode = 'SUCCEEDED';",
            malformed,
        )
        is None
    )

    duplicates = {
        row.RecordKey
        for row in ops.cursor().execute(
            "SELECT RecordKey FROM dq.vw_CurrentDataQualityIssues"
            " WHERE RuleCode = 'SIS_DUPLICATE_PERSON';"
        )
    }
    assert duplicates == {
        DUPLICATE_PERSON.keys["j1_id_primary"],
        DUPLICATE_PERSON.keys["j1_id_duplicate"],
    }
    orphan_detail = _value(
        ops,
        "SELECT i.DetailCode FROM dq.vw_CurrentDataQualityIssues AS i"
        " JOIN staging.DirectoryAccount AS d ON CAST(d.AccountGuid AS VARCHAR(36)) = i.RecordKey"
        " WHERE i.RuleCode = 'DIR_ORPHAN_ACCOUNT' AND d.EmployeeIdRaw = ?;",
        ORPHAN_DIRECTORY_ACCOUNT.keys["employee_id"],
    )
    assert orphan_detail == "NOT_A_J1_PERSON"


def test_an_unchanged_rerun_creates_nothing(ops: pyodbc.Connection) -> None:
    first = run_nightly(ops)
    before = _counts(ops)

    second = run_nightly(ops)
    after = _counts(ops)

    assert after == before
    first_summary, second_summary = run_summary(ops, first), run_summary(ops, second)
    assert second_summary.status == "SUCCEEDED"
    assert second_summary.created == second_summary.matched == 0
    assert second_summary.unchanged == first_summary.created + first_summary.matched
    assert second_summary.rejected == first_summary.rejected


def test_a_duplicate_source_delivery_is_counted_as_unchanged(ops: pyodbc.Connection) -> None:
    cursor = ops.cursor()
    for _ in range(2):
        cursor.execute("EXEC landing.usp_RunLandingLoad @SourceSystemCode = 'SLATE_SIM';")
    first, second = cursor.execute(
        "SELECT TOP (2) RowsRead, RowsInserted, RowsUnchanged FROM audit.BatchRun"
        " WHERE ProcessName = 'LANDING_SLATE_SIM' ORDER BY BatchId;"
    ).fetchall()

    assert first.RowsInserted == first.RowsRead > 0
    assert second.RowsInserted == 0
    assert second.RowsUnchanged == second.RowsRead


def _fix_missing_program(settings: Settings) -> None:
    with connect(settings, settings.source_database) as source:
        source.cursor().execute(
            "INSERT INTO SlateSim.ApplicationProgram (ApplicationProgramId, ApplicationId,"
            " ProgramCode, ChoiceRank, CreatedAtUtc, UpdatedAtUtc)"
            " SELECT MAX(ApplicationProgramId) + 1, ?, 'ADM-CIS', 1, SYSUTCDATETIME(),"
            " SYSUTCDATETIME() FROM SlateSim.ApplicationProgram;",
            MISSING_PROGRAM_APPLICATION,
        )
        source.commit()


def _set_sis_read_only(connection: pyodbc.Connection, read_only: bool) -> None:
    mode = "READ_ONLY" if read_only else "READ_WRITE"
    connection.cursor().execute(
        f"ALTER DATABASE [SourceSystems] SET {mode} WITH ROLLBACK IMMEDIATE;"
    )


def test_a_sis_outage_fails_the_run_visibly_and_a_recovery_run_completes_it(
    settings: Settings, ops: pyodbc.Connection
) -> None:
    run_nightly(ops)
    _fix_missing_program(settings)

    _set_sis_read_only(ops, read_only=True)
    try:
        with pytest.raises(PipelineError) as failure:
            run_nightly(ops)
    finally:
        _set_sis_read_only(ops, read_only=False)

    failed_batch = failure.value.batch_id
    assert failure.value.step == "PROCESS"
    assert run_summary(ops, failed_batch).status == "FAILED"
    assert (
        _value(
            ops,
            "SELECT COUNT(*) FROM audit.ErrorLog AS e"
            " JOIN audit.BatchStep AS s ON s.BatchStepId = e.BatchStepId"
            " WHERE e.BatchId = ? AND s.StepName = 'PROCESS' AND e.ErrorNumber = 3906;",
            failed_batch,
        )
        == 1
    )
    assert (
        _value(
            ops,
            "SELECT QueueStatusCode FROM integration.OutboundStudentQueue WHERE ApplicationId = ?;",
            MISSING_PROGRAM_APPLICATION,
        )
        == "FAILED_RETRYABLE"
    )

    recovery_batch = recover(ops, failed_batch, "PROCESS")

    assert run_summary(ops, recovery_batch).status == "SUCCEEDED"
    assert run_summary(ops, recovery_batch).is_balanced is True
    assert (
        _value(
            ops,
            "SELECT COUNT(*) FROM SourceSystems.J1Sim.IntegrationReceipt"
            " WHERE SourceApplicationId = ?;",
            MISSING_PROGRAM_APPLICATION,
        )
        == 1
    )
    assert _exception_statuses(ops, MISSING_PROGRAM_APPLICATION) == {
        "MISSING_REQUIRED_FIELD": "CLOSED"
    }
    skipped = [
        row.StepName
        for row in ops.cursor().execute(
            "SELECT StepName FROM audit.BatchStep"
            " WHERE BatchId = ? AND BatchStepStatusCode = 'SKIPPED' ORDER BY StepOrder;",
            recovery_batch,
        )
    ]
    assert skipped == list(STEPS[: STEPS.index("PROCESS")])


def test_a_step_cannot_run_before_the_earlier_steps(ops: pyodbc.Connection) -> None:
    batch_id = int(_value(ops, "EXEC integration.usp_StartPipelineRun;"))
    with pytest.raises(PipelineError):
        run_steps(ops, batch_id, ("MATCH",))
    assert run_summary(ops, batch_id).status == "RUNNING"
    ops.cursor().execute(
        "EXEC audit.usp_LogBatchEnd @BatchId = ?, @BatchStatusCode = 'FAILED';", batch_id
    )


def test_an_analyst_resolution_is_retried_written_and_reconciled(ops: pyodbc.Connection) -> None:
    run_nightly(ops)
    application = AMBIGUOUS_MATCH.keys["slate_application_id"]
    chosen = int(AMBIGUOUS_MATCH.keys["j1_id_candidate_1"])
    exception_id = _value(
        ops,
        "SELECT ExceptionId FROM integration.IntegrationException"
        " WHERE ApplicationId = ? AND ExceptionReasonCode = 'AMBIGUOUS_MATCH';",
        application,
    )

    ops.cursor().execute(
        "EXEC integration.usp_ResolveExceptionMatch @ExceptionId = ?, @MatchedIdNumber = ?,"
        " @Note = N'Confirmed with Admissions', @Actor = N'registrar.test';",
        exception_id,
        chosen,
    )
    batch_id = run_nightly(ops)

    summary = run_summary(ops, batch_id)
    assert summary.status == "SUCCEEDED"
    assert summary.matched == 1
    assert summary.is_balanced is True
    assert (
        _value(
            ops,
            "SELECT TargetIdNumber FROM integration.SourceCrosswalk WHERE SourceRecordId = ?;",
            AMBIGUOUS_MATCH.keys["slate_person_id"].upper(),
        )
        == chosen
    )
    assert (
        _value(
            ops,
            "SELECT ActionCode FROM integration.OutboundStudentQueue"
            " WHERE ApplicationId = ? AND QueueStatusCode = 'SUCCEEDED';",
            application,
        )
        == "CREATE_STUDENT"
    )
    assert _exception_statuses(ops, application) == {"AMBIGUOUS_MATCH": "CLOSED"}


def test_the_j1_import_interface_returns_the_same_person_for_a_replayed_key(
    settings: Settings,
) -> None:
    call = """
        SET NOCOUNT ON;
        DECLARE @IdNumber INT;
        EXEC J1Sim.usp_ReceiveAdmittedApplicant
            @IdempotencyKey = 0x7E57, @SourceApplicationId = 'F0000000-0000-4000-8000-000000000001',
            @ActionCode = 'CREATE_PERSON_STUDENT', @FirstName = N'Test', @LastName = N'Replay',
            @BirthDate = '2005-05-05', @ProgramCode = 'CIS.AS', @EntryTermCode = '2027FA',
            @ResidencyCode = 'IN_STATE', @ResultIdNumber = @IdNumber OUTPUT;
        SELECT @IdNumber;
    """
    with connect(settings, settings.source_database) as source:
        cursor = source.cursor()
        try:
            first = cursor.execute(call).fetchone()[0]
            second = cursor.execute(call).fetchone()[0]
            people = cursor.execute(
                "SELECT COUNT(*) FROM J1Sim.Person WHERE LastName = N'Replay';"
            ).fetchone()[0]
            assert first == second
            assert 8_000_000 <= first <= 8_999_999
            assert people == 1
        finally:
            source.rollback()


def test_the_j1_import_interface_rejects_an_inactive_program(settings: Settings) -> None:
    with connect(settings, settings.source_database) as source:
        cursor = source.cursor()
        try:
            with pytest.raises(pyodbc.Error, match="51001"):
                cursor.execute(
                    """
                    DECLARE @IdNumber INT;
                    EXEC J1Sim.usp_ReceiveAdmittedApplicant
                        @IdempotencyKey = 0x7E58,
                        @SourceApplicationId = 'F0000000-0000-4000-8000-000000000002',
                        @ActionCode = 'CREATE_PERSON_STUDENT',
                        @FirstName = N'Test', @LastName = N'Inactive', @BirthDate = '2005-05-05',
                        @ProgramCode = 'MEDA.CERT', @EntryTermCode = '2027FA',
                        @ResidencyCode = 'IN_STATE', @ResultIdNumber = @IdNumber OUTPUT;
                    """
                )
        finally:
            source.rollback()
