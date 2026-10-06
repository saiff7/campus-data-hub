"""Column contracts of every extract type: names, order and value type.

They must equal the header line each builder writes (compliance.usp_BuildExtract*), which
test_extracts_db.py checks against the database. Types:
  int      whole number          decimal  number with a fixed scale, period separator
  bool     0 or 1                date     YYYY-MM-DD
  text     any text              count    whole number that public copies may suppress
Empty fields are NULL in every type.
"""

from dataclasses import dataclass
from typing import Literal

ColumnType = Literal["int", "decimal", "bool", "date", "text", "count"]


@dataclass(frozen=True, slots=True)
class Column:
    name: str
    type: ColumnType


CONTRACTS: dict[str, tuple[Column, ...]] = {
    "ENROLLMENT_CENSUS": (
        Column("CensusSnapshotId", "int"),
        Column("TermCode", "text"),
        Column("CensusDate", "date"),
        Column("RuleVersion", "text"),
        Column("IdNumber", "int"),
        Column("ProgramCode", "text"),
        Column("CredentialLevel", "text"),
        Column("EntryTermCode", "text"),
        Column("ResidencyCode", "text"),
        Column("CensusCredits", "decimal"),
        Column("CountedSections", "int"),
        Column("AttendanceIntensity", "text"),
        Column("EntryStatus", "text"),
        Column("AgeAtCensus", "int"),
        Column("IsCensusIncluded", "bool"),
        Column("ExclusionReason", "text"),
    ),
    "AID_PACKAGING": (
        Column("IdNumber", "int"),
        Column("AidYear", "text"),
        Column("FundCode", "text"),
        Column("FundSource", "text"),
        Column("FundType", "text"),
        Column("AwardCount", "int"),
        Column("OfferedAmount", "decimal"),
        Column("AcceptedAmount", "decimal"),
        Column("DisbursedAmount", "decimal"),
        Column("CancelledAmount", "decimal"),
        Column("DeclinedAmount", "decimal"),
        Column("RemainingAmount", "decimal"),
    ),
    "ACCOUNT_AGING": (
        Column("IdNumber", "int"),
        Column("AsOfDate", "date"),
        Column("NetBalance", "decimal"),
        Column("CurrentAmount", "decimal"),
        Column("Days001To030", "decimal"),
        Column("Days031To060", "decimal"),
        Column("Days061To090", "decimal"),
        Column("Days091Plus", "decimal"),
        Column("CreditBalance", "decimal"),
        Column("TransactionCount", "int"),
        Column("LastPaymentDate", "date"),
    ),
    "ACADEMIC_PROGRESS": (
        Column("IdNumber", "int"),
        Column("TermCode", "text"),
        Column("ProgramCode", "text"),
        Column("AttemptedCredits", "decimal"),
        Column("EarnedCredits", "decimal"),
        Column("GpaCredits", "decimal"),
        Column("QualityPoints", "decimal"),
        Column("TermGpa", "decimal"),
        Column("CumulativeAttemptedCredits", "decimal"),
        Column("CumulativeEarnedCredits", "decimal"),
        Column("CumulativeGpaCredits", "decimal"),
        Column("CumulativeGpa", "decimal"),
        Column("AcademicStanding", "text"),
        Column("GradesPending", "bool"),
        Column("RequiredCredits", "decimal"),
        Column("IsCompletionEligible", "bool"),
        Column("HasCredential", "bool"),
    ),
    "EXCEPTION_WORKLIST": (
        Column("ExceptionId", "int"),
        Column("ExceptionReasonCode", "text"),
        Column("Severity", "text"),
        Column("OwnerDepartment", "text"),
        Column("ExceptionStatusCode", "text"),
        Column("AssignedTo", "text"),
        Column("ApplicationId", "text"),
        Column("DetailCode", "text"),
        Column("CurrentDecisionType", "text"),
        Column("CandidateCount", "int"),
        Column("AgeDays", "int"),
        Column("ApplicantInitials", "text"),
        Column("BirthYear", "int"),
        Column("MaskedEmail", "text"),
        Column("EntryTermCodeRaw", "text"),
        Column("ProgramChoice1Raw", "text"),
        Column("PermittedNextStatuses", "text"),
    ),
    "LEADERSHIP_KPI": (
        Column("TermCode", "text"),
        Column("AcademicYear", "text"),
        Column("MeasureCode", "text"),
        Column("MeasureName", "text"),
        Column("Unit", "text"),
        Column("OwnerDepartmentCode", "text"),
        Column("MeasureValue", "decimal"),
        Column("DataStatus", "text"),
    ),
    "DQ_SCORECARD": (
        Column("ValidationRunId", "int"),
        Column("BatchId", "int"),
        Column("RuleCode", "text"),
        Column("EntityName", "text"),
        Column("Severity", "text"),
        Column("OwnerDepartment", "text"),
        Column("RecordsEvaluated", "int"),
        Column("RecordsFailed", "int"),
        Column("PassRate", "decimal"),
    ),
    "IPEDS_FE": (
        Column("ReportingPeriod", "text"),
        Column("Section", "text"),
        Column("AttendanceStatus", "text"),
        Column("StudentCategory", "text"),
        Column("ResidencyGroup", "text"),
        Column("AgeBand", "text"),
        Column("Headcount", "count"),
    ),
    "IPEDS_E12": (
        Column("ReportingPeriod", "text"),
        Column("Section", "text"),
        Column("AttendanceStatus", "text"),
        Column("StudentCategory", "text"),
        Column("Headcount", "count"),
        Column("CreditHours", "decimal"),
    ),
    "IPEDS_C": (
        Column("ReportingPeriod", "text"),
        Column("Section", "text"),
        Column("CipCode", "text"),
        Column("AwardLevel", "text"),
        Column("AwardCount", "count"),
    ),
    "IPEDS_SFA": (
        Column("ReportingPeriod", "text"),
        Column("StudentGroup", "text"),
        Column("AidType", "text"),
        Column("RecipientCount", "count"),
        Column("TotalAmount", "decimal"),
        Column("AverageAmount", "decimal"),
    ),
}
