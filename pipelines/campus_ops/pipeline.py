"""Runs the nightly integration from Python by calling the same stored procedures as the SQL
Server Agent job. The database owns every business rule, transaction and log entry; this
module only sequences the steps and reports what happened.
"""

import logging
from dataclasses import dataclass
from pathlib import Path

import pyodbc

log = logging.getLogger(__name__)

# Must match reference.PipelineStep; test_pipeline_db.py verifies the agreement.
STEPS: tuple[str, ...] = (
    "LOAD",
    "STAGE",
    "DATA_QUALITY",
    "MATCH",
    "QUEUE",
    "PROCESS",
    "RECONCILE",
    "NOTIFY",
)

RESET_SCRIPT = (
    Path(__file__).resolve().parents[2]
    / "database"
    / "CampusDataOps.Database"
    / "Scripts"
    / "reset_operational_data.sql"
)


class PipelineError(RuntimeError):
    """A pipeline step failed; the database has logged the cause against the batch."""

    def __init__(self, batch_id: int, step: str, sqlstate: str) -> None:
        super().__init__(f"step {step} failed in batch {batch_id} (SQLSTATE {sqlstate})")
        self.batch_id = batch_id
        self.step = step


@dataclass(frozen=True, slots=True)
class RunSummary:
    batch_id: int
    status: str
    source_eligible: int | None
    created: int | None
    matched: int | None
    unchanged: int | None
    rejected: int | None
    pending: int | None
    target_confirmed: int | None
    is_balanced: bool | None


def steps_from(step: str) -> tuple[str, ...]:
    if step not in STEPS:
        raise ValueError(f"unknown pipeline step {step!r}; expected one of {', '.join(STEPS)}")
    return STEPS[STEPS.index(step) :]


def _scalar(cursor: pyodbc.Cursor) -> int:
    # Procedures may emit several result sets; the batch id is the first column of the last.
    value = None
    while True:
        if cursor.description is not None:
            row = cursor.fetchone()
            if row is not None:
                value = row[0]
        if not cursor.nextset():
            break
    if value is None:
        raise RuntimeError("procedure returned no batch id")
    return int(value)


def _drain(cursor: pyodbc.Cursor) -> None:
    while cursor.nextset():
        pass


def run_steps(connection: pyodbc.Connection, batch_id: int, steps: tuple[str, ...]) -> None:
    cursor = connection.cursor()
    for step in steps:
        log.info("pipeline step=%s batch=%d starting", step, batch_id)
        try:
            cursor.execute(
                "EXEC [integration].[usp_RunPipelineStep] @StepCode = ?, @BatchId = ?;",
                step,
                batch_id,
            )
            _drain(cursor)
        except pyodbc.Error as error:
            # Engine messages can quote values; log the SQLSTATE only. The full message is
            # in audit.ErrorLog for this batch and step.
            log.error("pipeline step=%s batch=%d failed sqlstate=%s", step, batch_id, error.args[0])
            raise PipelineError(batch_id, step, str(error.args[0])) from error
        log.info("pipeline step=%s batch=%d succeeded", step, batch_id)


def run_nightly(connection: pyodbc.Connection) -> int:
    """Start a run and execute every step. Returns the batch id."""
    cursor = connection.cursor()
    cursor.execute("EXEC [integration].[usp_StartPipelineRun];")
    batch_id = _scalar(cursor)
    run_steps(connection, batch_id, STEPS)
    return batch_id


def recover(connection: pyodbc.Connection, failed_batch_id: int, resume_at: str) -> int:
    """Open a recovery run for a failed run and execute the steps from resume_at onward."""
    remaining = steps_from(resume_at)
    cursor = connection.cursor()
    cursor.execute(
        "EXEC [integration].[usp_OpenRecoveryRun] @FailedBatchId = ?, @ResumeAtStepCode = ?;",
        failed_batch_id,
        resume_at,
    )
    batch_id = _scalar(cursor)
    log.info("recovery batch=%d failed_batch=%d step=%s", batch_id, failed_batch_id, resume_at)
    run_steps(connection, batch_id, remaining)
    return batch_id


def run_summary(connection: pyodbc.Connection, batch_id: int) -> RunSummary:
    row = (
        connection.cursor()
        .execute(
            """
            SELECT br.[BatchStatusCode], rr.[SourceEligible], rr.[Created], rr.[Matched],
                   rr.[Unchanged], rr.[Rejected], rr.[Pending], rr.[TargetConfirmed],
                   rr.[IsBalanced]
            FROM [audit].[BatchRun] AS br
            LEFT JOIN [integration].[ReconciliationResult] AS rr ON br.[BatchId] = rr.[BatchId]
            WHERE br.[BatchId] = ?;
            """,
            batch_id,
        )
        .fetchone()
    )
    if row is None:
        raise ValueError(f"batch {batch_id} does not exist")
    return RunSummary(
        batch_id,
        row[0],
        row[1],
        row[2],
        row[3],
        row[4],
        row[5],
        row[6],
        row[7],
        None if row[8] is None else bool(row[8]),
    )


def reset_operational_data(connection: pyodbc.Connection) -> None:
    """Development only: run Scripts/reset_operational_data.sql with its confirmation set."""
    script = RESET_SCRIPT.read_text(encoding="utf-8").replace("$(ConfirmReset)", "YES")
    cursor = connection.cursor()
    for batch in _batches(script):
        cursor.execute(batch)
        _drain(cursor)


def _batches(script: str) -> list[str]:
    batches, current = [], []
    for line in script.splitlines():
        if line.strip().upper() == "GO":
            batches.append("\n".join(current))
            current = []
        else:
            current.append(line)
    batches.append("\n".join(current))
    return [batch for batch in batches if batch.strip()]
