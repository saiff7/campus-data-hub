# Entity-relationship diagrams

Diagrams show keys and the columns that matter for relationships and integration. Every table
also carries `CreatedAtUtc` and `UpdatedAtUtc` (UTC `datetime2(3)`) unless it is an append-only
history table, which carries `CreatedAtUtc` only. The `.sql` files under `database/` are the
authoritative definitions.

## Slate-Sim (admissions CRM)

```mermaid
erDiagram
    Person ||--o{ Application : submits
    Person ||--o{ Address : has
    Person ||--o{ ContactPoint : has
    Person ||--o{ ExternalIdentifier : "is known by"
    Application ||--o{ ApplicationStatusHistory : "moves through"
    Application ||--o{ ApplicationProgram : "chooses (rank 1-3)"
    Application ||--o| ExportQueue : "queued once per export type"

    Person {
        uniqueidentifier PersonId PK
        nvarchar FirstName "nullable: CRM accepts incomplete data"
        nvarchar LastName "nullable"
        date BirthDate "nullable"
    }
    Application {
        uniqueidentifier ApplicationId PK
        uniqueidentifier PersonId FK
        varchar EntryTermCode "free text, validated in integration"
        varchar StudentType
        varchar CurrentStatus
        datetime2 SubmittedAtUtc
        datetime2 DecisionAtUtc
    }
    ApplicationStatusHistory {
        bigint ApplicationStatusHistoryId PK
        uniqueidentifier ApplicationId FK
        varchar Status
        datetime2 ChangedAtUtc
    }
    ApplicationProgram {
        bigint ApplicationProgramId PK
        uniqueidentifier ApplicationId FK "UQ with ChoiceRank"
        varchar ProgramCode "Slate code, mapped by reference.ProgramCrosswalk"
        tinyint ChoiceRank
    }
    Address {
        bigint AddressId PK
        uniqueidentifier PersonId FK "one primary per person"
        varchar PostalCode
    }
    ContactPoint {
        bigint ContactPointId PK
        uniqueidentifier PersonId FK "one primary per type"
        varchar ContactType "EMAIL or PHONE"
        nvarchar ContactValue "stored as entered"
    }
    ExternalIdentifier {
        bigint ExternalIdentifierId PK
        uniqueidentifier PersonId FK "UQ with IdentifierType"
        varchar IdentifierType "SIS_ID or COMMON_APP_ID"
        varchar IdentifierValue "not globally unique by design"
    }
    ExportQueue {
        bigint ExportQueueId PK
        uniqueidentifier ApplicationId FK
        varchar ExportType
        datetime2 QueuedAtUtc
        datetime2 ExportedAtUtc "NULL while pending"
    }
```

## J1-Sim (student information system)

```mermaid
erDiagram
    Person ||--o| Student : "may be"
    AcademicProgram ||--o{ Student : enrolls
    AcademicTerm ||--o{ Student : "entry term"
    AcademicTerm ||--o{ CourseSection : offers
    Student ||--o{ Enrollment : registers
    CourseSection ||--o{ Enrollment : contains
    Enrollment ||--o| FinalGrade : receives
    Student ||--o{ FinancialAidAward : "is awarded"
    AcademicTerm ||--o{ FinancialAidAward : "for term"
    Student ||--o{ StudentAccountTransaction : "is billed"
    AcademicTerm ||--o{ StudentAccountTransaction : "for term"
    Student ||--o{ CredentialAwarded : earns
    AcademicProgram ||--o{ CredentialAwarded : "for program"
    Person ||--o{ IntegrationReceipt : "created or updated by import"

    Person {
        int IdNumber PK "7-digit institutional ID"
        nvarchar FirstName
        nvarchar LastName
        date BirthDate
        nvarchar Email "shape-checked"
        varchar PostalCode
    }
    Student {
        int IdNumber PK, FK
        varchar ProgramCode FK
        varchar EntryTermCode FK
        varchar StudentStatus
        varchar ResidencyCode
    }
    AcademicTerm {
        varchar TermCode PK
        char AcademicYear
        date StartDate
        date CensusDate
        date EndDate
        bit IsOpenForAdmission
    }
    AcademicProgram {
        varchar ProgramCode PK
        varchar CredentialLevel
        char CipCode
        decimal RequiredCredits
        bit IsActive
    }
    CourseSection {
        int CourseSectionId PK
        varchar TermCode FK "UQ with subject, number, section"
        decimal CreditHours
    }
    Enrollment {
        bigint EnrollmentId PK
        int IdNumber FK "UQ with CourseSectionId"
        int CourseSectionId FK
        varchar RegistrationStatus
    }
    FinalGrade {
        bigint EnrollmentId PK, FK
        varchar GradeCode
        decimal GradePoints "NULL for W and I"
    }
    FinancialAidAward {
        bigint AwardId PK
        int IdNumber FK "UQ with TermCode, FundCode"
        varchar TermCode FK
        varchar FundCode
        decimal OfferedAmount
        decimal AcceptedAmount "<= offered"
        decimal DisbursedAmount "<= accepted"
    }
    StudentAccountTransaction {
        bigint TransactionId PK
        int IdNumber FK
        varchar TermCode FK
        varchar TransactionType
        decimal Amount "sign fixed by type"
    }
    CredentialAwarded {
        bigint CredentialAwardedId PK
        int IdNumber FK "UQ with ProgramCode"
        varchar ProgramCode FK
        varchar TermCode FK
    }
    IntegrationReceipt {
        binary IdempotencyKey PK "from CampusDataOps outbound queue"
        int IdNumber FK
        varchar ActionCode
        uniqueidentifier SourceApplicationId
    }
```

`IntegrationReceipt` belongs to the simulated import interface (Part 2): a replayed key returns
the original ID number, so a lost acknowledgement cannot create a second person.

## Directory-Sim (identity)

```mermaid
erDiagram
    DirectoryAccount ||--o{ GroupMembership : "belongs to"
    DirectoryAccount ||--o{ AccountStatusHistory : "changes state"

    DirectoryAccount {
        uniqueidentifier AccountGuid PK
        varchar SamAccountName UK
        nvarchar UserPrincipalName UK
        varchar EmployeeId "J1 IdNumber as text; not a foreign key"
        varchar AccountType "STUDENT, STAFF or SERVICE"
        bit IsEnabled
    }
    GroupMembership {
        bigint GroupMembershipId PK
        uniqueidentifier AccountGuid FK "UQ with GroupName"
        varchar GroupName
    }
    AccountStatusHistory {
        bigint AccountStatusHistoryId PK
        uniqueidentifier AccountGuid FK "UQ with ChangedAtUtc"
        bit IsEnabled
        varchar Reason
    }
```

## CampusDataOps (Part 1 objects)

```mermaid
erDiagram
    SourceSystem ||--o{ BatchRun : "loaded by"
    BatchStatus ||--o{ BatchRun : classifies
    BatchRun ||--o{ BatchStep : contains
    BatchStepStatus ||--o{ BatchStep : classifies
    BatchRun ||--o{ ErrorLog : records
    BatchStep ||--o{ ErrorLog : records

    SourceSystem {
        varchar SourceSystemCode PK "SLATE_SIM, J1_SIM, DIRECTORY_SIM"
        bit IsActive
    }
    BatchStatus {
        varchar BatchStatusCode PK "RUNNING, SUCCEEDED, FAILED"
        bit IsTerminal
    }
    BatchStepStatus {
        varchar BatchStepStatusCode PK "adds SKIPPED"
        bit IsTerminal
    }
    BatchRun {
        bigint BatchId PK
        varchar ProcessName "one RUNNING batch per process (filtered unique index)"
        varchar SourceSystemCode FK "NULL for non-landing jobs"
        varchar BatchStatusCode FK
        datetime2 PreviousWatermarkUtc
        datetime2 SourceWatermarkUtc "advances only on success"
        int RowsRead
        int RowsInserted
        int RowsUnchanged
        int RowsRejected
    }
    BatchStep {
        bigint BatchStepId PK
        bigint BatchId FK "UQ with StepName, AttemptNumber"
        varchar StepName
        smallint AttemptNumber
        varchar BatchStepStatusCode FK
    }
    ErrorLog {
        bigint ErrorLogId PK
        bigint BatchId FK "nullable"
        bigint BatchStepId FK "nullable"
        int ErrorNumber
        nvarchar ErrorProcedure
        nvarchar ErrorMessage
    }
    AcademicTerm {
        varchar TermCode PK "governed copy of the SIS calendar"
    }
    ProgramCrosswalk {
        varchar SlateProgramCode PK
        varchar J1ProgramCode UK
        bit IsActive
    }
    ExceptionReason {
        varchar ExceptionReasonCode PK "16 managed categories"
        varchar Category
        varchar DefaultSeverity
        bit BlocksProcessing
    }
```

Part 2 adds `ParentBatchId` (a landing batch's pipeline run) and `RecoveryOfBatchId` (the FAILED
run a recovery run resumes, at most one) to `audit.BatchRun`.

## CampusDataOps landing and staging (Part 2)

Every landing table has the same lineage columns (`LandingRowId` PK, `BatchId` FK, constant
`SourceSystemCode`, `SourceRecordId`, `SourceUpdatedAtUtc`, `RecordHash`, `RequestId`,
`IngestedAtUtc`) and a unique index on (key, `BatchId`). Staging rows point at the landed row
they were built from.

```mermaid
erDiagram
    BatchRun ||--o{ SlateApplicantRaw : lands
    BatchRun ||--o{ SlateApplicationRaw : lands
    BatchRun ||--o{ J1PersonRaw : lands
    SlateApplicantRaw ||--o{ Applicant : "latest version staged"
    SlateApplicationRaw ||--o{ Applicant : "latest version staged"
    J1PersonRaw ||--o{ Person : "latest version staged"

    SlateApplicationRaw {
        bigint LandingRowId PK
        bigint BatchId FK "UQ with ApplicationId"
        uniqueidentifier ApplicationId
        binary RecordHash "SHA-256 over FOR JSON row"
    }
    Applicant {
        uniqueidentifier ApplicationId PK
        uniqueidentifier SlatePersonId
        binary SourceHash "changes only when source values change"
        bit IsEligible
        nvarchar EmailRaw
        nvarchar EmailStd "NULL when invalid"
        varchar TermValidationCode
        varchar ProgramValidationCode
        varchar MissingRequiredFields
    }
    Person {
        int IdNumber PK
        nvarchar LastNameStd "indexed with first name, birth date, postal code"
        nvarchar EmailStd "indexed with birth date"
        varchar StudentStatus
    }
```

The same pattern applies to `J1EnrollmentRaw`, `J1FinancialAidRaw`, `J1AccountTransactionRaw` and
`DirectoryAccountRaw` (staged one-for-one) and to `J1AccountControlTotal` (read by data quality).

## CampusDataOps integration (Part 2)

```mermaid
erDiagram
    MatchEvaluation ||--o{ MatchCandidate : finds
    MatchEvaluation ||--o{ MatchDecision : "decided by"
    MatchDecisionType ||--o{ MatchDecision : classifies
    MatchRule ||--o{ MatchCandidate : "found by"
    MatchDecision ||--o{ OutboundStudentQueue : "queued from"
    OutboundStudentQueue ||--o| SourceCrosswalk : "creates on success"
    ErrorLog ||--o{ OutboundStudentQueue : "last error"
    IntegrationException ||--o{ ExceptionAction : "history"
    ExceptionStatusTransition ||--o{ ExceptionAction : "allows"
    ExceptionReason ||--o{ IntegrationException : classifies
    OutboundStudentQueue ||--o{ ReconciliationDetail : "outcome of"
    ReconciliationResult ||--o{ ReconciliationDetail : summarizes

    MatchEvaluation {
        bigint MatchEvaluationId PK
        bigint BatchId FK "UQ with ApplicationId"
        binary SourceHash
    }
    MatchCandidate {
        bigint MatchEvaluationId PK, FK
        varchar RuleCode PK, FK
        int CandidateIdNumber PK
        bit MatchedOnEmail "evidence flags, no values"
    }
    MatchDecision {
        bigint MatchDecisionId PK
        uniqueidentifier ApplicationId "one current (filtered unique index)"
        varchar DecisionTypeCode FK "CHECK: AUTO_MATCH unique and automatic"
        int CandidateCount
        int MatchedIdNumber "NULL for blocked decisions (CHECK)"
        varchar ConflictCode
        nvarchar DecidedBy
    }
    IntegrationException {
        bigint ExceptionId PK
        varchar ExceptionReasonCode FK "one active per subject and reason"
        uniqueidentifier ApplicationId "or SubjectBatchId"
        varchar ExceptionStatusCode FK
        binary SourceHash "holds an analyst closure until the source changes"
        int OccurrenceCount
    }
    ExceptionAction {
        bigint ExceptionActionId PK
        bigint ExceptionId FK
        varchar FromStatusCode FK "composite FK to allowed transitions"
        varchar ToStatusCode FK
        nvarchar ActionBy
    }
    OutboundStudentQueue {
        bigint QueueId PK
        binary IdempotencyKey UK
        uniqueidentifier ApplicationId "one live row (filtered unique index)"
        varchar ActionCode FK
        varchar QueueStatusCode FK
        smallint AttemptCount
        bigint ReconciledBatchId
    }
    SourceCrosswalk {
        bigint SourceCrosswalkId PK
        varchar SourceRecordId UK "Slate-Sim PersonId"
        int TargetIdNumber UK
    }
    ReconciliationDetail {
        bigint BatchId PK
        uniqueidentifier ApplicationId PK "one outcome each"
        varchar OutcomeCode FK
        bit IsTargetConfirmed
    }
    ReconciliationResult {
        bigint BatchId PK "CHECK: outcomes add up to eligible"
        int SourceEligible
        int Processed "Matched + Created"
        int TargetConfirmed
        bit IsBalanced
    }
```

`ReconciliationEntityCount` (per run and entity: landed vs staged keys) sits beside
`ReconciliationResult`.

## CampusDataOps data quality (Part 2)

```mermaid
erDiagram
    Rule ||--o{ RuleExecution : "evaluated in"
    ValidationRun ||--o{ RuleExecution : contains
    RuleExecution ||--o{ RuleResult : "failing records"

    Rule {
        varchar RuleCode PK
        varchar Severity
        nvarchar OwnerDepartment
        bit IsActive
        date EffectiveFrom
        nvarchar CheckProcedure
    }
    ValidationRun {
        bigint ValidationRunId PK
        bigint BatchId UK
        int RulesEvaluated
        int FailuresFound
    }
    RuleExecution {
        bigint ValidationRunId PK, FK
        varchar RuleCode PK, FK
        int RecordsEvaluated
        int RecordsFailed
    }
    RuleResult {
        bigint RuleResultId PK
        varchar RecordKey "UQ with run and rule"
        varchar DetailCode "codes only"
    }
```
