"""The Python calendar and program catalog must match the CampusDataOps reference seed,
because the generator writes the SIS copy and the seed writes the governed copy."""

import re
from pathlib import Path

from campus_ops.generators.calendar import PROGRAMS, TERMS

SEED = (
    Path(__file__).resolve().parents[2]
    / "database/CampusDataOps.Database/reference/Seed/reference_seed.sql"
)


def _values_block(table_variable: str) -> str:
    text = SEED.read_text()
    match = re.search(rf"INSERT INTO {re.escape(table_variable)}\b.*?VALUES(.*?);", text, re.DOTALL)
    assert match, f"no VALUES block for {table_variable}"
    return match.group(1)


def _tuples(block: str) -> list[list[str]]:
    rows = re.findall(r"\(([^()]*)\)", block)
    return [[part.strip().removeprefix("N").strip("'") for part in row.split(",")] for row in rows]


def test_term_calendar_matches_seed() -> None:
    seeded = _tuples(_values_block("@AcademicTerm"))
    expected = [
        [
            t.code,
            t.name,
            t.term_type,
            t.academic_year,
            t.start.isoformat(),
            t.census.isoformat(),
            t.end.isoformat(),
            "1" if t.open_for_admission else "0",
        ]
        for t in TERMS
    ]
    assert seeded == expected


def test_program_catalog_matches_seed() -> None:
    seeded = _tuples(_values_block("@ProgramCrosswalk"))
    expected = [
        [
            p.slate_code,
            p.j1_code,
            p.name,
            p.credential_level,
            p.cip_code,
            "1" if p.is_active else "0",
        ]
        for p in PROGRAMS
    ]
    assert [row[:6] for row in seeded] == expected


def test_reporting_program_catalog_matches_generator() -> None:
    reporting_seed = SEED.with_name("reporting_reference_seed.sql").read_text()
    match = re.search(r"INSERT INTO @AcademicProgram\b.*?VALUES(.*?);", reporting_seed, re.DOTALL)
    assert match, "no VALUES block for @AcademicProgram"
    seeded = [[row[0], row[1], row[2], row[3], row[4], row[7]] for row in _tuples(match.group(1))]
    expected = [
        [
            p.j1_code,
            p.name,
            p.credential_level,
            p.cip_code,
            str(p.required_credits),
            "1" if p.is_active else "0",
        ]
        for p in PROGRAMS
    ]
    assert seeded == expected
