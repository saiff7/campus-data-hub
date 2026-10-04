"""Each documented edge case is present, has the shape its description promises, and cannot
be confused with the regular population."""

from campus_ops.generators.common import FIRST_NAMES, LAST_NAMES
from campus_ops.generators.dataset import SourceDataset
from campus_ops.generators.edge_cases import (
    AMBIGUOUS_MATCH,
    DUPLICATE_PERSON,
    EDGE_CASES,
    INVALID_TERM,
    MALFORMED_EMAIL,
    MISSING_PROGRAM,
    ORPHAN_DIRECTORY_ACCOUNT,
)
from campus_ops.generators.people import FIRST_ID_NUMBER
from campus_ops.generators.records import (
    DirectoryAccount,
    J1AcademicTerm,
    J1Person,
    J1Student,
    SlateApplication,
    SlateApplicationProgram,
    SlateContactPoint,
    SlateExportQueue,
    SlatePerson,
)

EDGE_ID_RANGE = range(9000000, 9000100)


def _j1(dataset: SourceDataset) -> dict[int, J1Person]:
    return {p.id_number: p for p in dataset.rows(J1Person)}


def _application(dataset: SourceDataset, application_id: str) -> SlateApplication:
    return next(a for a in dataset.rows(SlateApplication) if a.application_id == application_id)


def _email(dataset: SourceDataset, person_id: str) -> str:
    return next(
        c.contact_value
        for c in dataset.rows(SlateContactPoint)
        if c.person_id == person_id and c.contact_type == "EMAIL"
    )


def test_registry_lists_six_distinct_cases() -> None:
    assert len({case.code for case in EDGE_CASES}) == 6


def test_duplicate_sis_person(dataset: SourceDataset) -> None:
    people = _j1(dataset)
    first = people[int(DUPLICATE_PERSON.keys["j1_id_primary"])]
    second = people[int(DUPLICATE_PERSON.keys["j1_id_duplicate"])]
    identity = ("first_name", "last_name", "birth_date", "address_line1", "postal_code")
    assert [getattr(first, f) for f in identity] == [getattr(second, f) for f in identity]
    assert first.email != second.email
    students = {s.id_number for s in dataset.rows(J1Student)}
    assert first.id_number in students
    assert second.id_number not in students


def test_ambiguous_match_has_two_email_and_birth_date_candidates(dataset: SourceDataset) -> None:
    keys = AMBIGUOUS_MATCH.keys
    applicant = next(p for p in dataset.rows(SlatePerson) if p.person_id == keys["slate_person_id"])
    email = _email(dataset, applicant.person_id)
    candidates = {
        p.id_number
        for p in dataset.rows(J1Person)
        if p.email == email and p.birth_date == applicant.birth_date
    }
    assert candidates == {int(keys["j1_id_candidate_1"]), int(keys["j1_id_candidate_2"])}
    assert _application(dataset, keys["slate_application_id"]).current_status == "ADMITTED"


def test_missing_program(dataset: SourceDataset) -> None:
    application_id = MISSING_PROGRAM.keys["slate_application_id"]
    assert _application(dataset, application_id).current_status == "ADMITTED"
    assert not any(
        p.application_id == application_id for p in dataset.rows(SlateApplicationProgram)
    )


def test_invalid_term(dataset: SourceDataset) -> None:
    application = _application(dataset, INVALID_TERM.keys["slate_application_id"])
    known_terms = {t.term_code for t in dataset.rows(J1AcademicTerm)}
    assert application.entry_term_code == INVALID_TERM.keys["entry_term_code"]
    assert application.entry_term_code not in known_terms


def test_malformed_email(dataset: SourceDataset) -> None:
    email = _email(dataset, MALFORMED_EMAIL.keys["slate_person_id"])
    assert email == MALFORMED_EMAIL.keys["email"]
    assert email.count("@") == 2


def test_orphan_directory_account(dataset: SourceDataset) -> None:
    employee_id = ORPHAN_DIRECTORY_ACCOUNT.keys["employee_id"]
    account = next(a for a in dataset.rows(DirectoryAccount) if a.employee_id == employee_id)
    assert account.account_type == "STUDENT"
    assert account.is_enabled
    assert int(employee_id) not in _j1(dataset)


def test_edge_case_applications_are_queued_for_export(dataset: SourceDataset) -> None:
    queued = {e.application_id for e in dataset.rows(SlateExportQueue)}
    for case in (AMBIGUOUS_MATCH, MISSING_PROGRAM, INVALID_TERM, MALFORMED_EMAIL):
        assert case.keys["slate_application_id"] in queued, case.code


def test_regular_population_cannot_collide_with_edge_cases(dataset: SourceDataset) -> None:
    regular_ids = [p.id_number for p in dataset.rows(J1Person) if p.id_number not in EDGE_ID_RANGE]
    assert min(regular_ids) >= FIRST_ID_NUMBER
    assert max(regular_ids) < EDGE_ID_RANGE.start
    edge_surnames = {"Ellsworth", "Okafor", "Lindqvist", "Barros", "Rivera", "Brandt"}
    assert edge_surnames.isdisjoint(LAST_NAMES)
    assert {"Morgan", "Riley", "Rowan", "Avery", "Quinn", "Casey", "Taylor"}.isdisjoint(FIRST_NAMES)
