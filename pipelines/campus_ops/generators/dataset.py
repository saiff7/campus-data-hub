"""Builds the complete simulator dataset and its fingerprint."""

import hashlib
from dataclasses import dataclass
from datetime import date, datetime
from decimal import Decimal

from campus_ops.generators import (
    academics,
    admissions,
    directory,
    edge_cases,
    financial_aid,
    people,
    student_accounts,
)
from campus_ops.generators.common import domain_rng
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

BASE_J1_PEOPLE = 2000
BASE_SLATE_APPLICANTS = 600

# Parent tables before children; deletes run in reverse.
LOAD_ORDER: tuple[type[Row], ...] = (
    SlatePerson,
    SlateApplication,
    SlateApplicationStatusHistory,
    SlateApplicationProgram,
    SlateAddress,
    SlateContactPoint,
    SlateExternalIdentifier,
    SlateExportQueue,
    J1AcademicTerm,
    J1AcademicProgram,
    J1Person,
    J1Student,
    J1CourseSection,
    J1Enrollment,
    J1FinalGrade,
    J1FinancialAidAward,
    J1StudentAccountTransaction,
    J1CredentialAwarded,
    DirectoryAccount,
    DirectoryGroupMembership,
    DirectoryAccountStatusHistory,
)


@dataclass(frozen=True, slots=True)
class SourceDataset:
    seed: int
    scale: float
    tables: dict[type[Row], list[Row]]

    def rows(self, row_type: type[Row]) -> list[Row]:
        return self.tables[row_type]

    def counts(self) -> dict[str, int]:
        return {row_type.TABLE: len(self.tables[row_type]) for row_type in LOAD_ORDER}

    def fingerprint(self) -> str:
        """SHA-256 over every value in load order; equal fingerprints mean equal data."""
        digest = hashlib.sha256()
        for row_type in LOAD_ORDER:
            digest.update(row_type.TABLE.encode())
            for row in self.tables[row_type]:
                digest.update("\x1f".join(_canonical(v) for v in row.values()).encode())
                digest.update(b"\x1e")
        return digest.hexdigest()


def _canonical(value: object) -> str:
    if value is None:
        return "\x00"
    if isinstance(value, bool):
        return "1" if value else "0"
    if isinstance(value, datetime | date):
        return value.isoformat()
    if isinstance(value, Decimal):
        return format(value, "f")
    return str(value)


def generate_sources(seed: int, scale: float = 1.0) -> SourceDataset:
    if scale <= 0:
        raise ValueError("scale must be positive")
    j1_people = people.build_j1_people(
        domain_rng(seed, "people"), max(1, round(BASE_J1_PEOPLE * scale))
    )
    sections = academics.build_sections()
    history = academics.simulate_academics(domain_rng(seed, "academics"), j1_people, sections)
    awards = financial_aid.build_awards(
        domain_rng(seed, "financial_aid"), history.students, history.billed_credits
    )
    transactions = student_accounts.build_transactions(
        domain_rng(seed, "student_accounts"), history.billed_credits, awards
    )
    applicants = admissions.build_admissions(
        domain_rng(seed, "admissions"),
        max(1, round(BASE_SLATE_APPLICANTS * scale)),
        j1_people,
        history.students,
    )
    accounts = directory.build_directory(domain_rng(seed, "directory"), j1_people, history.students)
    edge_cases.apply_edge_cases(
        domain_rng(seed, "edge_cases"), j1_people, history.students, applicants, accounts
    )

    tables: dict[type[Row], list[Row]] = {
        SlatePerson: applicants.persons,
        SlateApplication: applicants.applications,
        SlateApplicationStatusHistory: applicants.status_history,
        SlateApplicationProgram: applicants.programs,
        SlateAddress: applicants.addresses,
        SlateContactPoint: applicants.contacts,
        SlateExternalIdentifier: applicants.identifiers,
        SlateExportQueue: applicants.exports,
        J1AcademicTerm: academics.term_rows(),
        J1AcademicProgram: academics.program_rows(),
        J1Person: j1_people,
        J1Student: history.students,
        J1CourseSection: sections,
        J1Enrollment: history.enrollments,
        J1FinalGrade: history.grades,
        J1FinancialAidAward: awards,
        J1StudentAccountTransaction: transactions,
        J1CredentialAwarded: history.credentials,
        DirectoryAccount: accounts.accounts,
        DirectoryGroupMembership: accounts.groups,
        DirectoryAccountStatusHistory: accounts.history,
    }
    return SourceDataset(seed=seed, scale=scale, tables=tables)
