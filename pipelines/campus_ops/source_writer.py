"""Replaces the simulator databases' contents with a generated dataset.

The simulators stand in for systems we do not control, so seeding is a full replacement
inside one transaction: either the whole dataset is present or the previous one remains.
"""

import logging

import pyodbc

from campus_ops.generators.dataset import LOAD_ORDER, SourceDataset

log = logging.getLogger(__name__)

INSERT_CHUNK_ROWS = 5000

# Tables the integration writes into the simulators (through the J1-Sim import interface)
# rather than the generator. They reference generated rows, so they are cleared first.
INTEGRATION_WRITTEN_TABLES = ("[J1Sim].[IntegrationReceipt]",)


def replace_source_data(connection: pyodbc.Connection, dataset: SourceDataset) -> dict[str, int]:
    cursor = connection.cursor()
    cursor.fast_executemany = True
    try:
        for table in INTEGRATION_WRITTEN_TABLES:
            cursor.execute(f"DELETE FROM {table};")  # noqa: S608 - fixed table names
        for row_type in reversed(LOAD_ORDER):
            cursor.execute(f"DELETE FROM {row_type.TABLE};")  # noqa: S608 - fixed table names
        loaded: dict[str, int] = {}
        for row_type in LOAD_ORDER:
            rows = dataset.rows(row_type)
            columns = row_type.column_names()
            statement = (
                f"INSERT INTO {row_type.TABLE} ({', '.join(f'[{c}]' for c in columns)}) "  # noqa: S608
                f"VALUES ({', '.join('?' for _ in columns)});"
            )
            for start in range(0, len(rows), INSERT_CHUNK_ROWS):
                chunk = rows[start : start + INSERT_CHUNK_ROWS]
                cursor.executemany(statement, [row.values() for row in chunk])
            loaded[row_type.TABLE] = len(rows)
            log.info("loaded table=%s rows=%d", row_type.TABLE, len(rows))
        connection.commit()
    except pyodbc.Error as error:
        connection.rollback()
        # Engine messages can quote row values, so the log records only the error class and
        # SQLSTATE; the exception itself still propagates to the caller for diagnosis.
        log.error(
            "source load rolled back error=%s sqlstate=%s", type(error).__name__, error.args[0]
        )
        raise
    finally:
        cursor.close()
    return loaded
