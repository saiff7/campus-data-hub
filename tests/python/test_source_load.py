"""Database tests: run with `make test-db` after `make deploy`.

They reload the configured default seed and scale, so the database ends in the same state
`make seed` produces. Negative-path procedure tests run inside transactions that are rolled
back; the error-logging test deletes the single row it creates.
"""

from collections.abc import Iterator

import pyodbc
import pytest

from campus_ops.config import Settings, get_settings
from campus_ops.db import connect
from campus_ops.generators.dataset import LOAD_ORDER, SourceDataset, generate_sources
from campus_ops.source_writer import replace_source_data

pytestmark = pytest.mark.db


@pytest.fixture(scope="module")
def settings() -> Settings:
    return get_settings()


@pytest.fixture(scope="module")
def default_dataset(settings: Settings) -> SourceDataset:
    return generate_sources(settings.seed, settings.scale)


@pytest.fixture
def ops(settings: Settings) -> Iterator[pyodbc.Connection]:
    with connect(settings, settings.ops_database) as connection:
        yield connection
        connection.rollback()


def _table_state(connection: pyodbc.Connection) -> dict[str, tuple[int, int]]:
    cursor = connection.cursor()
    state = {}
    for row_type in LOAD_ORDER:
        count, checksum = cursor.execute(
            f"SELECT COUNT_BIG(*), CHECKSUM_AGG(BINARY_CHECKSUM(*)) FROM {row_type.TABLE};"  # noqa: S608
        ).fetchone()
        state[row_type.TABLE] = (count, checksum)
    return state


def test_record_fields_match_table_columns_in_order(settings: Settings) -> None:
    with connect(settings, settings.source_database) as connection:
        cursor = connection.cursor()
        for row_type in LOAD_ORDER:
            columns = [
                row.name
                for row in cursor.execute(
                    "SELECT c.name FROM sys.columns AS c"
                    " WHERE c.object_id = OBJECT_ID(?) ORDER BY c.column_id;",
                    row_type.TABLE,
                )
            ]
            assert columns == row_type.column_names(), row_type.TABLE


def test_reloading_the_same_seed_is_idempotent(
    settings: Settings, default_dataset: SourceDataset
) -> None:
    with connect(settings, settings.source_database) as connection:
        replace_source_data(connection, default_dataset)
        first = _table_state(connection)
        replace_source_data(connection, default_dataset)
        second = _table_state(connection)
    assert first == second
    assert {table: count for table, (count, _) in second.items()} == default_dataset.counts()


def _begin(cursor: pyodbc.Cursor, source: str = "SLATE_SIM") -> tuple[int, object]:
    return cursor.execute(
        """
        SET NOCOUNT ON;
        DECLARE @BatchId BIGINT, @Watermark DATETIME2(3);
        EXEC landing.usp_BeginLandingBatch @SourceSystemCode = ?, @BatchId = @BatchId OUTPUT,
             @PreviousWatermarkUtc = @Watermark OUTPUT;
        SELECT @BatchId, @Watermark;
        """,
        source,
    ).fetchone()


def _end(
    cursor: pyodbc.Cursor,
    batch_id: int,
    *,
    succeeded: int,
    watermark: str | None,
    read: int,
    inserted: int,
    unchanged: int,
    rejected: int,
) -> None:
    cursor.execute(
        """
        EXEC landing.usp_EndLandingBatch @BatchId = ?, @Succeeded = ?, @SourceWatermarkUtc = ?,
             @RowsRead = ?, @RowsInserted = ?, @RowsUnchanged = ?, @RowsRejected = ?;
        """,
        batch_id,
        succeeded,
        watermark,
        read,
        inserted,
        unchanged,
        rejected,
    )


def test_unknown_source_system_is_rejected(ops: pyodbc.Connection) -> None:
    with pytest.raises(pyodbc.Error, match=r"\(50010\)"):
        _begin(ops.cursor(), "NOT_A_SOURCE")


def test_second_running_batch_for_a_source_is_blocked(ops: pyodbc.Connection) -> None:
    cursor = ops.cursor()
    _begin(cursor)
    with pytest.raises(pyodbc.Error, match=r"\(50003\)"):
        _begin(cursor)


def test_unbalanced_control_totals_are_rejected(ops: pyodbc.Connection) -> None:
    cursor = ops.cursor()
    batch_id, _ = _begin(cursor)
    with pytest.raises(pyodbc.Error, match=r"\(50015\)"):
        _end(
            cursor,
            batch_id,
            succeeded=1,
            watermark="2026-09-01T12:00:00",
            read=10,
            inserted=7,
            unchanged=2,
            rejected=0,
        )


def test_successful_batch_must_report_a_watermark(ops: pyodbc.Connection) -> None:
    cursor = ops.cursor()
    batch_id, _ = _begin(cursor)
    with pytest.raises(pyodbc.Error, match=r"\(50013\)"):
        _end(
            cursor,
            batch_id,
            succeeded=1,
            watermark=None,
            read=0,
            inserted=0,
            unchanged=0,
            rejected=0,
        )


def test_failed_batch_cannot_advance_the_watermark(ops: pyodbc.Connection) -> None:
    cursor = ops.cursor()
    batch_id, _ = _begin(cursor)
    with pytest.raises(pyodbc.Error, match=r"\(50016\)"):
        _end(
            cursor,
            batch_id,
            succeeded=0,
            watermark="2026-09-01T12:00:00",
            read=0,
            inserted=0,
            unchanged=0,
            rejected=0,
        )


def test_watermark_cannot_move_backwards(ops: pyodbc.Connection) -> None:
    cursor = ops.cursor()
    first_id, _ = _begin(cursor)
    _end(
        cursor,
        first_id,
        succeeded=1,
        watermark="2026-09-01T12:00:00",
        read=1,
        inserted=1,
        unchanged=0,
        rejected=0,
    )
    second_id, previous = _begin(cursor)
    assert previous is not None
    with pytest.raises(pyodbc.Error, match=r"\(50014\)"):
        _end(
            cursor,
            second_id,
            succeeded=1,
            watermark="2026-08-01T00:00:00",
            read=0,
            inserted=0,
            unchanged=0,
            rejected=0,
        )


def test_failed_batch_does_not_change_the_next_watermark(ops: pyodbc.Connection) -> None:
    cursor = ops.cursor()
    first_id, _ = _begin(cursor)
    _end(
        cursor,
        first_id,
        succeeded=1,
        watermark="2026-09-01T12:00:00",
        read=1,
        inserted=1,
        unchanged=0,
        rejected=0,
    )
    failed_id, _ = _begin(cursor)
    _end(
        cursor, failed_id, succeeded=0, watermark=None, read=0, inserted=0, unchanged=0, rejected=0
    )
    _, watermark = _begin(cursor)
    assert watermark.isoformat() == "2026-09-01T12:00:00"


def test_procedure_errors_outside_a_transaction_are_logged(settings: Settings) -> None:
    with connect(settings, settings.ops_database) as connection:
        connection.autocommit = True
        cursor = connection.cursor()
        before = cursor.execute(
            "SELECT ISNULL(MAX(ErrorLogId), 0) FROM audit.ErrorLog;"
        ).fetchone()[0]
        with pytest.raises(pyodbc.Error, match=r"\(50011\)"):
            _end(
                cursor,
                -1,
                succeeded=1,
                watermark="2026-09-01T12:00:00",
                read=0,
                inserted=0,
                unchanged=0,
                rejected=0,
            )
        logged = cursor.execute(
            "SELECT ErrorLogId, ErrorNumber, BatchId, ErrorProcedure"
            " FROM audit.ErrorLog WHERE ErrorLogId > ?;",
            before,
        ).fetchall()
        cursor.execute("DELETE FROM audit.ErrorLog WHERE ErrorLogId > ?;", before)
    assert [(row.ErrorNumber, row.BatchId, row.ErrorProcedure) for row in logged] == [
        (50011, None, "landing.usp_EndLandingBatch")
    ]
