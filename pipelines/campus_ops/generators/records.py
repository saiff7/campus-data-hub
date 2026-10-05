"""Row types for every simulator table. Field names are the snake_case form of the SQL
column names, so column lists are derived rather than maintained twice."""

from dataclasses import dataclass, fields
from datetime import date, datetime
from decimal import Decimal
from typing import Any, ClassVar


def _pascal(name: str) -> str:
    return "".join(part.capitalize() for part in name.split("_"))


class Row:
    TABLE: ClassVar[str]

    @classmethod
    def column_names(cls) -> list[str]:
        return [_pascal(f.name) for f in fields(cls)]  # type: ignore[arg-type]

    def values(self) -> tuple[Any, ...]:
        return tuple(getattr(self, f.name) for f in fields(self))  # type: ignore[arg-type]


# --- Slate-Sim -----------------------------------------------------------------------


@dataclass(frozen=True, slots=True)
class SlatePerson(Row):
    TABLE: ClassVar[str] = "[SlateSim].[Person]"
    person_id: str
    first_name: str | None
    middle_name: str | None
    last_name: str | None
    preferred_name: str | None
    birth_date: date | None
    created_at_utc: datetime
    updated_at_utc: datetime


@dataclass(frozen=True, slots=True)
class SlateApplication(Row):
    TABLE: ClassVar[str] = "[SlateSim].[Application]"
    application_id: str
    person_id: str
    entry_term_code: str | None
    student_type: str
    current_status: str
    submitted_at_utc: datetime | None
    decision_at_utc: datetime | None
    created_at_utc: datetime
    updated_at_utc: datetime


@dataclass(frozen=True, slots=True)
class SlateApplicationStatusHistory(Row):
    TABLE: ClassVar[str] = "[SlateSim].[ApplicationStatusHistory]"
    application_status_history_id: int
    application_id: str
    status: str
    changed_at_utc: datetime
    created_at_utc: datetime


@dataclass(frozen=True, slots=True)
class SlateApplicationProgram(Row):
    TABLE: ClassVar[str] = "[SlateSim].[ApplicationProgram]"
    application_program_id: int
    application_id: str
    program_code: str
    choice_rank: int
    created_at_utc: datetime
    updated_at_utc: datetime


@dataclass(frozen=True, slots=True)
class SlateAddress(Row):
    TABLE: ClassVar[str] = "[SlateSim].[Address]"
    address_id: int
    person_id: str
    address_type: str
    line1: str | None
    line2: str | None
    city: str | None
    state_code: str | None
    postal_code: str | None
    country_code: str
    is_primary: bool
    created_at_utc: datetime
    updated_at_utc: datetime


@dataclass(frozen=True, slots=True)
class SlateContactPoint(Row):
    TABLE: ClassVar[str] = "[SlateSim].[ContactPoint]"
    contact_point_id: int
    person_id: str
    contact_type: str
    contact_value: str
    is_primary: bool
    created_at_utc: datetime
    updated_at_utc: datetime


@dataclass(frozen=True, slots=True)
class SlateExternalIdentifier(Row):
    TABLE: ClassVar[str] = "[SlateSim].[ExternalIdentifier]"
    external_identifier_id: int
    person_id: str
    identifier_type: str
    identifier_value: str
    created_at_utc: datetime
    updated_at_utc: datetime


@dataclass(frozen=True, slots=True)
class SlateExportQueue(Row):
    TABLE: ClassVar[str] = "[SlateSim].[ExportQueue]"
    export_queue_id: int
    application_id: str
    export_type: str
    queued_at_utc: datetime
    exported_at_utc: datetime | None
    created_at_utc: datetime
    updated_at_utc: datetime


# --- J1-Sim --------------------------------------------------------------------------


@dataclass(frozen=True, slots=True)
class J1Person(Row):
    TABLE: ClassVar[str] = "[J1Sim].[Person]"
    id_number: int
    first_name: str
    middle_name: str | None
    last_name: str
    birth_date: date
    email: str | None
    phone: str | None
    address_line1: str | None
    city: str | None
    state_code: str | None
    postal_code: str | None
    created_at_utc: datetime
    updated_at_utc: datetime


@dataclass(frozen=True, slots=True)
class J1AcademicTerm(Row):
    TABLE: ClassVar[str] = "[J1Sim].[AcademicTerm]"
    term_code: str
    term_name: str
    academic_year: str
    start_date: date
    census_date: date
    end_date: date
    is_open_for_admission: bool
    created_at_utc: datetime
    updated_at_utc: datetime


@dataclass(frozen=True, slots=True)
class J1AcademicProgram(Row):
    TABLE: ClassVar[str] = "[J1Sim].[AcademicProgram]"
    program_code: str
    program_name: str
    credential_level: str
    cip_code: str
    required_credits: Decimal
    is_active: bool
    created_at_utc: datetime
    updated_at_utc: datetime


@dataclass(frozen=True, slots=True)
class J1Student(Row):
    TABLE: ClassVar[str] = "[J1Sim].[Student]"
    id_number: int
    program_code: str
    entry_term_code: str
    student_status: str
    residency_code: str
    matriculation_date: date
    created_at_utc: datetime
    updated_at_utc: datetime


@dataclass(frozen=True, slots=True)
class J1CourseSection(Row):
    TABLE: ClassVar[str] = "[J1Sim].[CourseSection]"
    course_section_id: int
    term_code: str
    subject_code: str
    course_number: str
    section_number: str
    course_title: str
    credit_hours: Decimal
    capacity: int
    created_at_utc: datetime
    updated_at_utc: datetime


@dataclass(frozen=True, slots=True)
class J1Enrollment(Row):
    TABLE: ClassVar[str] = "[J1Sim].[Enrollment]"
    enrollment_id: int
    id_number: int
    course_section_id: int
    registration_status: str
    registered_at_utc: datetime
    status_changed_at_utc: datetime
    created_at_utc: datetime
    updated_at_utc: datetime


@dataclass(frozen=True, slots=True)
class J1FinalGrade(Row):
    TABLE: ClassVar[str] = "[J1Sim].[FinalGrade]"
    enrollment_id: int
    grade_code: str
    grade_points: Decimal | None
    posted_at_utc: datetime
    created_at_utc: datetime
    updated_at_utc: datetime


@dataclass(frozen=True, slots=True)
class J1FinancialAidAward(Row):
    TABLE: ClassVar[str] = "[J1Sim].[FinancialAidAward]"
    award_id: int
    id_number: int
    aid_year: str
    term_code: str
    fund_code: str
    award_status: str
    offered_amount: Decimal
    accepted_amount: Decimal
    disbursed_amount: Decimal
    created_at_utc: datetime
    updated_at_utc: datetime


@dataclass(frozen=True, slots=True)
class J1StudentAccountTransaction(Row):
    TABLE: ClassVar[str] = "[J1Sim].[StudentAccountTransaction]"
    transaction_id: int
    id_number: int
    term_code: str
    transaction_type: str
    detail_code: str
    amount: Decimal
    posted_date: date
    due_date: date | None
    created_at_utc: datetime
    updated_at_utc: datetime


@dataclass(frozen=True, slots=True)
class J1CredentialAwarded(Row):
    TABLE: ClassVar[str] = "[J1Sim].[CredentialAwarded]"
    credential_awarded_id: int
    id_number: int
    program_code: str
    term_code: str
    awarded_date: date
    created_at_utc: datetime
    updated_at_utc: datetime


# --- Directory-Sim -------------------------------------------------------------------


@dataclass(frozen=True, slots=True)
class DirectoryAccount(Row):
    TABLE: ClassVar[str] = "[DirectorySim].[DirectoryAccount]"
    account_guid: str
    sam_account_name: str
    user_principal_name: str
    employee_id: str | None
    display_name: str
    account_type: str
    is_enabled: bool
    when_created_utc: datetime
    created_at_utc: datetime
    updated_at_utc: datetime


@dataclass(frozen=True, slots=True)
class DirectoryGroupMembership(Row):
    TABLE: ClassVar[str] = "[DirectorySim].[GroupMembership]"
    group_membership_id: int
    account_guid: str
    group_name: str
    added_at_utc: datetime
    created_at_utc: datetime
    updated_at_utc: datetime


@dataclass(frozen=True, slots=True)
class DirectoryAccountStatusHistory(Row):
    TABLE: ClassVar[str] = "[DirectorySim].[AccountStatusHistory]"
    account_status_history_id: int
    account_guid: str
    is_enabled: bool
    reason: str
    changed_at_utc: datetime
    created_at_utc: datetime
