"""Deliberate edge cases with fixed, documented identifiers.

They are appended after the regular population so their keys never depend on the seed or
scale. Part 2 integration tests and the interview demo rely on these exact identifiers.
SIS IdNumbers 9000000-9000099 are reserved for edge cases.
"""

import random
from dataclasses import dataclass
from datetime import date, datetime

from campus_ops.generators.admissions import AdmissionsData, Applicant
from campus_ops.generators.common import FAKE_EMAIL_DOMAIN
from campus_ops.generators.directory import DirectoryData
from campus_ops.generators.records import J1Person, J1Student

EDGE_CREATED = datetime(2026, 3, 2, 9, 0, 0)


@dataclass(frozen=True, slots=True)
class EdgeCase:
    code: str
    description: str
    keys: dict[str, str]


DUPLICATE_PERSON = EdgeCase(
    code="DUPLICATE_SIS_PERSON",
    description="Two J1-Sim people share legal name, birth date and address but have different "
    "emails; one is an active student, the other has no student record.",
    keys={"j1_id_primary": "9000001", "j1_id_duplicate": "9000002"},
)
AMBIGUOUS_MATCH = EdgeCase(
    code="AMBIGUOUS_MATCH",
    description="Twins in J1-Sim share a family email and birth date. An admitted Slate-Sim "
    "applicant with that email and birth date matches both under the email + DOB rule.",
    keys={
        "j1_id_candidate_1": "9000011",
        "j1_id_candidate_2": "9000012",
        "slate_person_id": "5e1a7e00-0000-4000-8000-000000000011",
        "slate_application_id": "5e1a7e00-0000-4000-8000-000000000012",
    },
)
MISSING_PROGRAM = EdgeCase(
    code="MISSING_PROGRAM",
    description="An admitted Slate-Sim application has no program choice.",
    keys={
        "slate_person_id": "5e1a7e00-0000-4000-8000-000000000021",
        "slate_application_id": "5e1a7e00-0000-4000-8000-000000000022",
    },
)
INVALID_TERM = EdgeCase(
    code="INVALID_TERM",
    description="An admitted Slate-Sim application names entry term 2031FA, which the SIS calendar "
    "does not contain.",
    keys={
        "slate_person_id": "5e1a7e00-0000-4000-8000-000000000031",
        "slate_application_id": "5e1a7e00-0000-4000-8000-000000000032",
        "entry_term_code": "2031FA",
    },
)
MALFORMED_EMAIL = EdgeCase(
    code="MALFORMED_EMAIL",
    description="An admitted Slate-Sim applicant's only email has a doubled @ sign.",
    keys={
        "slate_person_id": "5e1a7e00-0000-4000-8000-000000000041",
        "slate_application_id": "5e1a7e00-0000-4000-8000-000000000042",
        "email": f"casey.rivera@@{FAKE_EMAIL_DOMAIN}",
    },
)
ORPHAN_DIRECTORY_ACCOUNT = EdgeCase(
    code="ORPHAN_DIRECTORY_ACCOUNT",
    description="An enabled student directory account carries EmployeeId 9000099, which is not "
    "a J1-Sim person.",
    keys={"employee_id": "9000099"},
)

EDGE_CASES: tuple[EdgeCase, ...] = (
    DUPLICATE_PERSON,
    AMBIGUOUS_MATCH,
    MISSING_PROGRAM,
    INVALID_TERM,
    MALFORMED_EMAIL,
    ORPHAN_DIRECTORY_ACCOUNT,
)


def _j1_person(
    id_number: int, *, first: str, last: str, birth: date, email: str, postal: str
) -> J1Person:
    return J1Person(
        id_number=id_number,
        first_name=first,
        middle_name=None,
        last_name=last,
        birth_date=birth,
        email=email,
        phone="508-555-0142",
        address_line1="48 Cedar St",
        city="Worcester",
        state_code="MA",
        postal_code=postal,
        created_at_utc=EDGE_CREATED,
        updated_at_utc=EDGE_CREATED,
    )


def _admitted(
    person_id: str,
    application_id: str,
    first: str,
    last: str,
    *,
    birth: date,
    email: str,
    term: str | None,
    programs: tuple[str, ...],
) -> Applicant:
    return Applicant(
        person_id=person_id,
        application_id=application_id,
        first_name=first,
        middle_name=None,
        last_name=last,
        birth_date=birth,
        email=email,
        phone=None,
        street="12 Union St",
        city="Lowell",
        postal_code="01852",
        entry_term_code=term,
        student_type="FIRST_TIME",
        final_status="ADMITTED",
        program_codes=programs,
        sis_id=None,
        common_app_id=None,
        created_at_utc=EDGE_CREATED,
    )


def apply_edge_cases(
    rng: random.Random,
    j1_people: list[J1Person],
    students: list[J1Student],
    admissions: AdmissionsData,
    directory: DirectoryData,
) -> None:
    ellsworth_birth = date(2001, 4, 12)
    j1_people.append(
        _j1_person(
            9000001,
            first="Morgan",
            last="Ellsworth",
            birth=ellsworth_birth,
            email=f"morgan.ellsworth@{FAKE_EMAIL_DOMAIN}",
            postal="01608",
        )
    )
    j1_people.append(
        _j1_person(
            9000002,
            first="Morgan",
            last="Ellsworth",
            birth=ellsworth_birth,
            email=f"m.ellsworth@{FAKE_EMAIL_DOMAIN}",
            postal="01608",
        )
    )
    students.append(
        J1Student(
            id_number=9000001,
            program_code="BUS.AS",
            entry_term_code="2025FA",
            student_status="ACTIVE",
            residency_code="IN_STATE",
            matriculation_date=date(2025, 8, 1),
            created_at_utc=EDGE_CREATED,
            updated_at_utc=EDGE_CREATED,
        )
    )

    twins_birth = date(2004, 3, 15)
    family_email = f"okafor.family@{FAKE_EMAIL_DOMAIN}"
    j1_people.append(
        _j1_person(
            9000011,
            first="Riley",
            last="Okafor",
            birth=twins_birth,
            email=family_email,
            postal="01103",
        )
    )
    j1_people.append(
        _j1_person(
            9000012,
            first="Rowan",
            last="Okafor",
            birth=twins_birth,
            email=family_email,
            postal="01103",
        )
    )
    keys = AMBIGUOUS_MATCH.keys
    admissions.add_applicant(
        rng,
        _admitted(
            keys["slate_person_id"],
            keys["slate_application_id"],
            "Riley",
            "Okafor",
            birth=twins_birth,
            email=family_email,
            term="2027FA",
            programs=("ADM-CIS",),
        ),
    )

    keys = MISSING_PROGRAM.keys
    admissions.add_applicant(
        rng,
        _admitted(
            keys["slate_person_id"],
            keys["slate_application_id"],
            "Avery",
            "Lindqvist",
            birth=date(2007, 11, 3),
            email=f"avery.lindqvist@{FAKE_EMAIL_DOMAIN}",
            term="2027FA",
            programs=(),
        ),
    )

    keys = INVALID_TERM.keys
    admissions.add_applicant(
        rng,
        _admitted(
            keys["slate_person_id"],
            keys["slate_application_id"],
            "Quinn",
            "Barros",
            birth=date(2006, 6, 21),
            email=f"quinn.barros@{FAKE_EMAIL_DOMAIN}",
            term=keys["entry_term_code"],
            programs=("ADM-NURS",),
        ),
    )

    keys = MALFORMED_EMAIL.keys
    admissions.add_applicant(
        rng,
        _admitted(
            keys["slate_person_id"],
            keys["slate_application_id"],
            "Casey",
            "Rivera",
            birth=date(2005, 9, 9),
            email=keys["email"],
            term="2027SP",
            programs=("ADM-LIBA",),
        ),
    )

    directory.add_account(
        rng,
        first="Taylor",
        last="Brandt",
        employee_id=ORPHAN_DIRECTORY_ACCOUNT.keys["employee_id"],
        account_type="STUDENT",
        is_enabled=True,
        created=EDGE_CREATED,
        group_names=("grp-all-students",),
    )
