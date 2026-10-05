import os

import pytest

from campus_ops.generators.dataset import SourceDataset, generate_sources

TEST_SEED = 424242
TEST_SCALE = 0.25


def pytest_collection_modifyitems(config: pytest.Config, items: list[pytest.Item]) -> None:
    if os.environ.get("CAMPUS_RUN_DB_TESTS") == "1":
        return
    skip_db = pytest.mark.skip(
        reason="database tests need a deployed SQL Server; set CAMPUS_RUN_DB_TESTS=1"
    )
    for item in items:
        if "db" in item.keywords:
            item.add_marker(skip_db)


@pytest.fixture(scope="session")
def dataset() -> SourceDataset:
    return generate_sources(TEST_SEED, TEST_SCALE)
