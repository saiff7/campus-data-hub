"""Governed term calendar and program catalog.

These values must match database/CampusDataOps.Database/reference/Seed/reference_seed.sql;
tests/python/test_reference_alignment.py fails if the two drift apart.
"""

from dataclasses import dataclass
from datetime import date, timedelta
from decimal import Decimal

from campus_ops.generators.common import AS_OF


@dataclass(frozen=True, slots=True)
class Term:
    code: str
    name: str
    term_type: str
    academic_year: str
    start: date
    census: date
    end: date
    open_for_admission: bool


@dataclass(frozen=True, slots=True)
class Program:
    slate_code: str
    j1_code: str
    name: str
    credential_level: str
    cip_code: str
    required_credits: Decimal
    is_active: bool
    core_subjects: tuple[str, ...]


def _term(year: int, term_type: str, open_for_admission: bool) -> Term:
    if term_type == "FALL":
        code, name, ay_start = f"{year}FA", f"Fall {year}", year
        start, census, end = date(year, 9, 2), date(year, 9, 16), date(year, 12, 19)
    elif term_type == "SPRING":
        code, name, ay_start = f"{year}SP", f"Spring {year}", year - 1
        start, census, end = date(year, 1, 20), date(year, 2, 3), date(year, 5, 15)
    else:
        # Summer is assigned to the academic year of the preceding fall (project assumption).
        code, name, ay_start = f"{year}SU", f"Summer {year}", year - 1
        start, census, end = date(year, 6, 1), date(year, 6, 8), date(year, 8, 7)
    return Term(
        code, name, term_type, f"{ay_start}-{ay_start + 1}", start, census, end, open_for_admission
    )


TERMS: tuple[Term, ...] = (
    _term(2024, "FALL", False),
    _term(2025, "SPRING", False),
    _term(2025, "SUMMER", False),
    _term(2025, "FALL", False),
    _term(2026, "SPRING", False),
    _term(2026, "SUMMER", False),
    _term(2026, "FALL", False),
    _term(2027, "SPRING", True),
    _term(2027, "SUMMER", True),
    _term(2027, "FALL", True),
)
TERMS_BY_CODE = {term.code: term for term in TERMS}
# Registration opens this many days before a term starts.
REGISTRATION_WINDOW_DAYS = 90
# Terms with registration activity as of the simulation date. 2026FA is registered but
# not yet started on AS_OF, so it has enrollments and charges but no grades.
INSTRUCTIONAL_TERMS = tuple(
    term for term in TERMS if term.start - timedelta(days=REGISTRATION_WINDOW_DAYS) <= AS_OF.date()
)
ADMISSION_TERMS = tuple(term for term in TERMS if term.open_for_admission)

GENERAL_EDUCATION_SUBJECTS = ("ENG", "MAT", "PSY", "COM", "CHM", "SOC")

PROGRAMS: tuple[Program, ...] = (
    Program(
        "ADM-ACCT",
        "ACCT.AS",
        "Accounting",
        "ASSOCIATE",
        "52.0301",
        Decimal("60.0"),
        True,
        ("ACC", "BUS"),
    ),
    Program(
        "ADM-BUS",
        "BUS.AS",
        "Business Administration",
        "ASSOCIATE",
        "52.0201",
        Decimal("60.0"),
        True,
        ("BUS", "ACC"),
    ),
    Program(
        "ADM-CIS",
        "CIS.AS",
        "Computer Information Systems",
        "ASSOCIATE",
        "11.0101",
        Decimal("60.0"),
        True,
        ("CIS",),
    ),
    Program(
        "ADM-NURS",
        "NURS.AS",
        "Nursing",
        "ASSOCIATE",
        "51.3801",
        Decimal("70.0"),
        True,
        ("NUR", "BIO"),
    ),
    Program(
        "ADM-LIBA",
        "LIBA.AS",
        "Liberal Arts",
        "ASSOCIATE",
        "24.0101",
        Decimal("60.0"),
        True,
        ("HIS", "ART", "SOC"),
    ),
    Program(
        "ADM-CJ",
        "CJ.AS",
        "Criminal Justice",
        "ASSOCIATE",
        "43.0104",
        Decimal("60.0"),
        True,
        ("CRJ",),
    ),
    Program(
        "ADM-ECE",
        "ECE.CERT",
        "Early Childhood Education",
        "CERTIFICATE",
        "19.0709",
        Decimal("30.0"),
        True,
        ("ECE",),
    ),
    Program(
        "ADM-WELD",
        "WELD.CERT",
        "Welding Technology",
        "CERTIFICATE",
        "48.0508",
        Decimal("30.0"),
        True,
        ("WLD",),
    ),
    Program(
        "ADM-MEDA",
        "MEDA.CERT",
        "Medical Assisting",
        "CERTIFICATE",
        "51.0801",
        Decimal("30.0"),
        False,
        ("MED", "BIO"),
    ),
)
PROGRAMS_BY_J1_CODE = {program.j1_code: program for program in PROGRAMS}
# Last date new students could enter the discontinued program.
INACTIVE_PROGRAM_LAST_ENTRY = date(2025, 6, 30)

COURSES: tuple[tuple[str, str, str, Decimal], ...] = (
    ("ENG", "101", "Composition I", Decimal("3.0")),
    ("ENG", "102", "Composition II", Decimal("3.0")),
    ("MAT", "110", "College Algebra", Decimal("3.0")),
    ("MAT", "120", "Introductory Statistics", Decimal("3.0")),
    ("PSY", "101", "Introduction to Psychology", Decimal("3.0")),
    ("SOC", "101", "Introduction to Sociology", Decimal("3.0")),
    ("COM", "101", "Public Speaking", Decimal("3.0")),
    ("CHM", "101", "General Chemistry", Decimal("4.0")),
    ("BIO", "110", "General Biology", Decimal("4.0")),
    ("BIO", "210", "Anatomy and Physiology", Decimal("4.0")),
    ("HIS", "101", "United States History", Decimal("3.0")),
    ("ART", "101", "Art Appreciation", Decimal("3.0")),
    ("ACC", "101", "Financial Accounting", Decimal("3.0")),
    ("ACC", "102", "Managerial Accounting", Decimal("3.0")),
    ("BUS", "101", "Introduction to Business", Decimal("3.0")),
    ("BUS", "210", "Business Law", Decimal("3.0")),
    ("CIS", "110", "Introduction to Computing", Decimal("3.0")),
    ("CIS", "150", "Programming I", Decimal("3.0")),
    ("CIS", "250", "Database Systems", Decimal("3.0")),
    ("NUR", "101", "Fundamentals of Nursing", Decimal("6.0")),
    ("NUR", "201", "Medical-Surgical Nursing", Decimal("6.0")),
    ("CRJ", "101", "Introduction to Criminal Justice", Decimal("3.0")),
    ("CRJ", "201", "Criminal Law", Decimal("3.0")),
    ("ECE", "101", "Child Growth and Development", Decimal("3.0")),
    ("ECE", "120", "Early Childhood Curriculum", Decimal("3.0")),
    ("WLD", "101", "Welding Fundamentals", Decimal("4.0")),
    ("WLD", "120", "Shielded Metal Arc Welding", Decimal("4.0")),
    ("MED", "101", "Medical Terminology", Decimal("3.0")),
)
