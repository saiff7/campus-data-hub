"""Determinism and in-memory enforcement of the constraints the database will apply."""

from collections import Counter
from decimal import Decimal

import pytest

from campus_ops.generators.common import AS_OF
from campus_ops.generators.dataset import LOAD_ORDER, SourceDataset, generate_sources
from campus_ops.generators.records import (
    DirectoryAccount,
    DirectoryAccountStatusHistory,
    DirectoryGroupMembership,
    J1AcademicProgram,
    J1AcademicTerm,
    J1CourseSection,
    J1CredentialAwarded,
    J1Enrollment,
    J1FinalGrade,
    J1FinancialAidAward,
    J1Person,
    J1Student,
    J1StudentAccountTransaction,
    Row,
    SlateAddress,
    SlateApplication,
    SlateApplicationProgram,
    SlateApplicationStatusHistory,
    SlateContactPoint,
    SlateExportQueue,
    SlateExternalIdentifier,
    SlatePerson,
)
from tests.python.conftest import TEST_SCALE, TEST_SEED

# Primary keys and unique constraints, mirroring the SourceSystems table definitions.
UNIQUE_KEYS: dict[type[Row], tuple[tuple[str, ...], ...]] = {
    SlatePerson: (("person_id",),),
    SlateApplication: (("application_id",),),
    SlateApplicationStatusHistory: (
        ("application_status_history_id",),
        ("application_id", "changed_at_utc", "status"),
    ),
    SlateApplicationProgram: (("application_program_id",), ("application_id", "choice_rank")),
    SlateAddress: (("address_id",),),
    SlateContactPoint: (("contact_point_id",),),
    SlateExternalIdentifier: (("external_identifier_id",), ("person_id", "identifier_type")),
    SlateExportQueue: (("export_queue_id",), ("application_id", "export_type")),
    J1Person: (("id_number",),),
    J1AcademicTerm: (("term_code",), ("term_name",)),
    J1AcademicProgram: (("program_code",),),
    J1Student: (("id_number",),),
    J1CourseSection: (
        ("course_section_id",),
        ("term_code", "subject_code", "course_number", "section_number"),
    ),
    J1Enrollment: (("enrollment_id",), ("id_number", "course_section_id")),
    J1FinalGrade: (("enrollment_id",),),
    J1FinancialAidAward: (("award_id",), ("id_number", "term_code", "fund_code")),
    J1StudentAccountTransaction: (("transaction_id",),),
    J1CredentialAwarded: (("credential_awarded_id",), ("id_number", "program_code")),
    DirectoryAccount: (("account_guid",), ("sam_account_name",), ("user_principal_name",)),
    DirectoryGroupMembership: (("group_membership_id",), ("account_guid", "group_name")),
    DirectoryAccountStatusHistory: (
        ("account_status_history_id",),
        ("account_guid", "changed_at_utc"),
    ),
}

# (child type, child field, parent type, parent field): foreign keys within each simulator.
FOREIGN_KEYS: tuple[tuple[type[Row], str, type[Row], str], ...] = (
    (SlateApplication, "person_id", SlatePerson, "person_id"),
    (SlateApplicationStatusHistory, "application_id", SlateApplication, "application_id"),
    (SlateApplicationProgram, "application_id", SlateApplication, "application_id"),
    (SlateAddress, "person_id", SlatePerson, "person_id"),
    (SlateContactPoint, "person_id", SlatePerson, "person_id"),
    (SlateExternalIdentifier, "person_id", SlatePerson, "person_id"),
    (SlateExportQueue, "application_id", SlateApplication, "application_id"),
    (J1Student, "id_number", J1Person, "id_number"),
    (J1Student, "program_code", J1AcademicProgram, "program_code"),
    (J1Student, "entry_term_code", J1AcademicTerm, "term_code"),
    (J1CourseSection, "term_code", J1AcademicTerm, "term_code"),
    (J1Enrollment, "id_number", J1Student, "id_number"),
    (J1Enrollment, "course_section_id", J1CourseSection, "course_section_id"),
    (J1FinalGrade, "enrollment_id", J1Enrollment, "enrollment_id"),
    (J1FinancialAidAward, "id_number", J1Student, "id_number"),
    (J1FinancialAidAward, "term_code", J1AcademicTerm, "term_code"),
    (J1StudentAccountTransaction, "id_number", J1Student, "id_number"),
    (J1StudentAccountTransaction, "term_code", J1AcademicTerm, "term_code"),
    (J1CredentialAwarded, "id_number", J1Student, "id_number"),
    (J1CredentialAwarded, "program_code", J1AcademicProgram, "program_code"),
    (J1CredentialAwarded, "term_code", J1AcademicTerm, "term_code"),
    (DirectoryGroupMembership, "account_guid", DirectoryAccount, "account_guid"),
    (DirectoryAccountStatusHistory, "account_guid", DirectoryAccount, "account_guid"),
)


def test_same_seed_and_scale_reproduce_identical_data(dataset: SourceDataset) -> None:
    again = generate_sources(TEST_SEED, TEST_SCALE)
    assert again.fingerprint() == dataset.fingerprint()
    assert again.counts() == dataset.counts()


def test_different_seed_changes_data(dataset: SourceDataset) -> None:
    assert generate_sources(TEST_SEED + 1, TEST_SCALE).fingerprint() != dataset.fingerprint()


def test_scale_controls_population_size(dataset: SourceDataset) -> None:
    larger = generate_sources(TEST_SEED, TEST_SCALE * 2)
    assert len(larger.rows(J1Person)) > len(dataset.rows(J1Person))
    assert len(larger.rows(SlatePerson)) > len(dataset.rows(SlatePerson))


@pytest.mark.parametrize("scale", [0, -1])
def test_non_positive_scale_is_rejected(scale: float) -> None:
    with pytest.raises(ValueError, match="scale"):
        generate_sources(TEST_SEED, scale)


def test_every_table_is_populated(dataset: SourceDataset) -> None:
    empty = [row_type.TABLE for row_type in LOAD_ORDER if not dataset.rows(row_type)]
    assert empty == []


@pytest.mark.parametrize(
    ("row_type", "keys"), list(UNIQUE_KEYS.items()), ids=lambda v: getattr(v, "TABLE", "")
)
def test_unique_keys_hold(
    dataset: SourceDataset, row_type: type[Row], keys: tuple[tuple[str, ...], ...]
) -> None:
    rows = dataset.rows(row_type)
    for key in keys:
        counts = Counter(tuple(getattr(row, name) for name in key) for row in rows)
        duplicates = [value for value, count in counts.items() if count > 1]
        assert duplicates == [], f"{row_type.TABLE} duplicate {key}"


@pytest.mark.parametrize(
    ("child", "child_field", "parent", "parent_field"),
    FOREIGN_KEYS,
    ids=[f"{c.TABLE}.{cf}->{p.TABLE}" for c, cf, p, _ in FOREIGN_KEYS],
)
def test_foreign_keys_resolve(
    dataset: SourceDataset, child: type[Row], child_field: str, parent: type[Row], parent_field: str
) -> None:
    parent_keys = {getattr(row, parent_field) for row in dataset.rows(parent)}
    orphans = {getattr(row, child_field) for row in dataset.rows(child)} - parent_keys
    assert orphans == set()


def test_no_timestamp_is_after_the_simulation_date(dataset: SourceDataset) -> None:
    late = [
        (row_type.TABLE, name)
        for row_type in LOAD_ORDER
        for row in dataset.rows(row_type)
        for name in ("created_at_utc", "updated_at_utc")
        if getattr(row, name, AS_OF) > AS_OF
    ]
    assert late == []


def test_updated_is_never_before_created(dataset: SourceDataset) -> None:
    backwards = [
        row_type.TABLE
        for row_type in LOAD_ORDER
        for row in dataset.rows(row_type)
        if hasattr(row, "updated_at_utc") and row.updated_at_utc < row.created_at_utc
    ]
    assert backwards == []


def test_aid_amounts_are_ordered(dataset: SourceDataset) -> None:
    for award in dataset.rows(J1FinancialAidAward):
        assert award.offered_amount > 0
        assert 0 <= award.disbursed_amount <= award.accepted_amount <= award.offered_amount


def test_ledger_amount_signs_follow_transaction_type(dataset: SourceDataset) -> None:
    for txn in dataset.rows(J1StudentAccountTransaction):
        if txn.transaction_type in ("CHARGE", "REFUND"):
            assert txn.amount > 0
        elif txn.transaction_type in ("PAYMENT", "AID_CREDIT"):
            assert txn.amount < 0
        else:
            assert txn.amount != 0


def test_ledger_includes_unpaid_balances_for_aging(dataset: SourceDataset) -> None:
    balances: Counter[int] = Counter()
    for txn in dataset.rows(J1StudentAccountTransaction):
        balances[txn.id_number] += txn.amount
    assert sum(1 for balance in balances.values() if balance > Decimal("0")) > 0


def test_grade_points_only_for_gpa_grades(dataset: SourceDataset) -> None:
    for grade in dataset.rows(J1FinalGrade):
        if grade.grade_code in ("W", "I"):
            assert grade.grade_points is None
        else:
            assert grade.grade_points is not None
            assert 0 <= grade.grade_points <= 4


def test_application_decisions_follow_submission(dataset: SourceDataset) -> None:
    for app in dataset.rows(SlateApplication):
        if app.decision_at_utc is not None:
            assert app.submitted_at_utc is not None
            assert app.decision_at_utc >= app.submitted_at_utc


def test_only_admitted_or_deposited_applications_are_exported(dataset: SourceDataset) -> None:
    status = {a.application_id: a.current_status for a in dataset.rows(SlateApplication)}
    assert {status[e.application_id] for e in dataset.rows(SlateExportQueue)} <= {
        "ADMITTED",
        "DEPOSITED",
    }


def test_graduates_have_a_credential(dataset: SourceDataset) -> None:
    credentialed = {c.id_number for c in dataset.rows(J1CredentialAwarded)}
    graduates = {s.id_number for s in dataset.rows(J1Student) if s.student_status == "GRADUATED"}
    assert graduates == credentialed
    assert graduates, "expected some graduates at test scale"
