"""J1-Sim academic records: terms, programs, sections, students and their histories.

Each student is simulated term by term from entry: register, receive grades for terms
that have ended, then possibly stop out, withdraw or complete the program.
"""

import random
from collections import defaultdict
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from decimal import Decimal

from campus_ops.generators.calendar import (
    COURSES,
    GENERAL_EDUCATION_SUBJECTS,
    INACTIVE_PROGRAM_LAST_ENTRY,
    INSTRUCTIONAL_TERMS,
    PROGRAMS,
    PROGRAMS_BY_J1_CODE,
    TERMS,
    Term,
)
from campus_ops.generators.common import AS_OF, at_noon, random_datetime, weighted_choice
from campus_ops.generators.records import (
    J1AcademicProgram,
    J1AcademicTerm,
    J1CourseSection,
    J1CredentialAwarded,
    J1Enrollment,
    J1FinalGrade,
    J1Person,
    J1Student,
)

CATALOG_CREATED = datetime(2023, 6, 1, 12, 0, 0)
FIRST_SECTION_ID = 100001
STUDENT_SHARE_OF_PEOPLE = 0.9
ENTRY_TERM_WEIGHTS = (
    ("2024FA", 25),
    ("2025SP", 10),
    ("2025FA", 25),
    ("2026SP", 10),
    ("2026FA", 30),
)
GRADE_SCALE: tuple[tuple[str, Decimal | None, int], ...] = (
    ("A", Decimal("4.00"), 18),
    ("A-", Decimal("3.70"), 10),
    ("B+", Decimal("3.30"), 10),
    ("B", Decimal("3.00"), 14),
    ("B-", Decimal("2.70"), 8),
    ("C+", Decimal("2.30"), 8),
    ("C", Decimal("2.00"), 10),
    ("C-", Decimal("1.70"), 4),
    ("D+", Decimal("1.30"), 2),
    ("D", Decimal("1.00"), 3),
    ("F", Decimal("0.00"), 6),
    ("I", None, 1),
)
PASSING_GRADES = frozenset(
    code for code, points, _ in GRADE_SCALE if points is not None and points >= 1
)


@dataclass(slots=True)
class AcademicHistory:
    students: list[J1Student] = field(default_factory=list)
    enrollments: list[J1Enrollment] = field(default_factory=list)
    grades: list[J1FinalGrade] = field(default_factory=list)
    credentials: list[J1CredentialAwarded] = field(default_factory=list)
    # Credits charged per (IdNumber, TermCode): registered plus withdrawn, not dropped.
    billed_credits: dict[tuple[int, str], Decimal] = field(default_factory=dict)


def term_rows() -> list[J1AcademicTerm]:
    return [
        J1AcademicTerm(
            term_code=t.code,
            term_name=t.name,
            academic_year=t.academic_year,
            start_date=t.start,
            census_date=t.census,
            end_date=t.end,
            is_open_for_admission=t.open_for_admission,
            created_at_utc=CATALOG_CREATED,
            updated_at_utc=CATALOG_CREATED,
        )
        for t in TERMS
    ]


def program_rows() -> list[J1AcademicProgram]:
    return [
        J1AcademicProgram(
            program_code=p.j1_code,
            program_name=p.name,
            credential_level=p.credential_level,
            cip_code=p.cip_code,
            required_credits=p.required_credits,
            is_active=p.is_active,
            created_at_utc=CATALOG_CREATED,
            updated_at_utc=CATALOG_CREATED,
        )
        for p in PROGRAMS
    ]


def build_sections() -> list[J1CourseSection]:
    sections: list[J1CourseSection] = []
    next_id = FIRST_SECTION_ID
    for term in INSTRUCTIONAL_TERMS:
        created = at_noon(term.start - timedelta(days=120))
        for subject, number, title, credits in COURSES:
            if term.term_type == "SUMMER":
                if subject not in GENERAL_EDUCATION_SUBJECTS:
                    continue
                section_numbers = ("50",)
            else:
                section_numbers = ("01", "02")
            for section_number in section_numbers:
                sections.append(
                    J1CourseSection(
                        course_section_id=next_id,
                        term_code=term.code,
                        subject_code=subject,
                        course_number=number,
                        section_number=section_number,
                        course_title=title,
                        credit_hours=credits,
                        capacity=30,
                        created_at_utc=created,
                        updated_at_utc=created,
                    )
                )
                next_id += 1
    return sections


def _pick_program(rng: random.Random, entry: Term) -> str:
    candidates = [p for p in PROGRAMS if p.is_active or entry.start <= INACTIVE_PROGRAM_LAST_ENTRY]
    return rng.choice(candidates).j1_code


class _SectionIndex:
    def __init__(self, sections: list[J1CourseSection]) -> None:
        self._by_term_subject: dict[tuple[str, str], list[J1CourseSection]] = defaultdict(list)
        for section in sections:
            self._by_term_subject[(section.term_code, section.subject_code)].append(section)

    def choose(
        self, rng: random.Random, term_code: str, subjects: tuple[str, ...], count: int
    ) -> list[J1CourseSection]:
        pool = [
            s for subject in subjects for s in self._by_term_subject.get((term_code, subject), [])
        ]
        chosen: list[J1CourseSection] = []
        taken_courses: set[tuple[str, str]] = set()
        for section in rng.sample(pool, k=len(pool)):
            course = (section.subject_code, section.course_number)
            if course not in taken_courses:
                chosen.append(section)
                taken_courses.add(course)
            if len(chosen) == count:
                break
        return chosen


@dataclass(frozen=True, slots=True)
class _TermOutcome:
    billed_credits: Decimal
    earned_credits: Decimal
    last_activity: datetime


def _register_for_term(
    rng: random.Random,
    history: AcademicHistory,
    *,
    id_number: int,
    term: Term,
    sections: list[J1CourseSection],
) -> _TermOutcome:
    """Registers one student for one term's sections and grades them if the term has ended."""
    term_has_ended = term.end < AS_OF.date()
    billed = earned = Decimal("0")
    last_activity = datetime.min
    for section in sections:
        enrollment_id = len(history.enrollments) + 1
        registered = random_datetime(
            rng, at_noon(term.start - timedelta(days=60)), at_noon(term.start - timedelta(days=5))
        )
        roll = rng.random()
        if roll < 0.05:
            reg_status = "DROPPED"
            changed = random_datetime(rng, registered, at_noon(term.start + timedelta(days=7)))
        elif roll < 0.09 and term_has_ended:
            reg_status = "WITHDRAWN"
            changed = random_datetime(
                rng, at_noon(term.census), at_noon(term.end - timedelta(days=14))
            )
        else:
            reg_status = "REGISTERED"
            changed = registered
        changed = min(changed, AS_OF)
        history.enrollments.append(
            J1Enrollment(
                enrollment_id=enrollment_id,
                id_number=id_number,
                course_section_id=section.course_section_id,
                registration_status=reg_status,
                registered_at_utc=registered,
                status_changed_at_utc=changed,
                created_at_utc=registered,
                updated_at_utc=changed,
            )
        )
        last_activity = max(last_activity, changed)
        if reg_status == "DROPPED":
            continue
        billed += section.credit_hours
        if not term_has_ended:
            continue
        if reg_status == "WITHDRAWN":
            grade_code, points = "W", None
        else:
            grade_code, points = weighted_choice(
                rng, tuple(((code, pts), weight) for code, pts, weight in GRADE_SCALE)
            )
        posted = at_noon(term.end + timedelta(days=3))
        history.grades.append(
            J1FinalGrade(
                enrollment_id=enrollment_id,
                grade_code=grade_code,
                grade_points=points,
                posted_at_utc=posted,
                created_at_utc=posted,
                updated_at_utc=posted,
            )
        )
        if grade_code in PASSING_GRADES:
            earned += section.credit_hours
        last_activity = max(last_activity, posted)
    return _TermOutcome(billed, earned, last_activity)


def _award_credential(
    history: AcademicHistory, *, id_number: int, program_code: str, term: Term
) -> datetime:
    awarded = term.end + timedelta(days=7)
    history.credentials.append(
        J1CredentialAwarded(
            credential_awarded_id=len(history.credentials) + 1,
            id_number=id_number,
            program_code=program_code,
            term_code=term.code,
            awarded_date=awarded,
            created_at_utc=at_noon(awarded),
            updated_at_utc=at_noon(awarded),
        )
    )
    return at_noon(awarded)


def simulate_academics(
    rng: random.Random, people: list[J1Person], sections: list[J1CourseSection]
) -> AcademicHistory:
    history = AcademicHistory()
    index = _SectionIndex(sections)
    terms_in_order = list(INSTRUCTIONAL_TERMS)

    for person in people:
        if rng.random() >= STUDENT_SHARE_OF_PEOPLE:
            continue
        entry_code = weighted_choice(rng, ENTRY_TERM_WEIGHTS)
        entry = next(t for t in terms_in_order if t.code == entry_code)
        program_code = _pick_program(rng, entry)
        program = PROGRAMS_BY_J1_CODE[program_code]
        subjects = program.core_subjects + GENERAL_EDUCATION_SUBJECTS
        status = "ACTIVE"
        earned = Decimal("0")
        last_activity = at_noon(entry.start - timedelta(days=30))

        for term in terms_in_order[terms_in_order.index(entry) :]:
            if term.term_type == "SUMMER":
                if rng.random() >= 0.15:
                    continue
                course_count = 1
            else:
                course_count = 2 if rng.random() < 0.25 else rng.randint(3, 5)

            outcome = _register_for_term(
                rng,
                history,
                id_number=person.id_number,
                term=term,
                sections=index.choose(rng, term.code, subjects, course_count),
            )
            if outcome.billed_credits:
                history.billed_credits[(person.id_number, term.code)] = outcome.billed_credits
            earned += outcome.earned_credits
            last_activity = max(last_activity, outcome.last_activity)

            if term.end >= AS_OF.date():
                break
            if earned >= program.required_credits:
                status = "GRADUATED"
                awarded_at = _award_credential(
                    history, id_number=person.id_number, program_code=program_code, term=term
                )
                last_activity = max(last_activity, awarded_at)
                break
            if term.term_type != "SUMMER":
                roll = rng.random()
                if roll < 0.03:
                    status = "WITHDRAWN"
                    break
                if roll < 0.11:
                    status = "INACTIVE"
                    break

        matriculated = entry.start - timedelta(days=rng.randint(21, 75))
        history.students.append(
            J1Student(
                id_number=person.id_number,
                program_code=program_code,
                entry_term_code=entry.code,
                student_status=status,
                residency_code=weighted_choice(
                    rng, (("IN_STATE", 88), ("OUT_OF_STATE", 9), ("INTERNATIONAL", 3))
                ),
                matriculation_date=matriculated,
                created_at_utc=at_noon(matriculated),
                updated_at_utc=max(at_noon(matriculated), min(last_activity, AS_OF)),
            )
        )
    return history
