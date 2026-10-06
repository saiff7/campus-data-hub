# Data dictionary

Every table and view in CampusDataOps, by schema, generated from the deployed database catalog
by `make data-dictionary`. Descriptions are the leading comment of each object's SQL file.
Business definitions are in the [business glossary](specifications/business-glossary.md) and
the [report catalog](specifications/report-catalog.md); who may read what is in the
[security model](architecture/security-model.md).

## reference

Governed codes and calendars, seeded on every deploy.

### `reference.AcademicDivision` (table)

Academic divisions that group programs, used for reporting and program-scoped access.

| Column | Type | Nullable |
|---|---|---|
| `DivisionCode` | varchar(30) | no |
| `DivisionName` | nvarchar(100) | no |
| `CreatedAtUtc` | datetime2(3) | no |
| `UpdatedAtUtc` | datetime2(3) | no |

### `reference.AcademicProgram` (table)

Governed copy of the SIS program catalog for reporting. It must agree with J1Sim.AcademicProgram; a database test enforces that agreement after seeding. IpedsAwardLevel follows the IPEDS Completions award levels for a semester-credit institution (docs/specifications/ipeds-measure-mapping.md): associate degree 3; certificate of 30-59 credits 2; certificate of 9-29 credits 1b.

| Column | Type | Nullable |
|---|---|---|
| `ProgramCode` | varchar(20) | no |
| `ProgramName` | nvarchar(150) | no |
| `CredentialLevel` | varchar(20) | no |
| `CipCode` | char(7) | no |
| `RequiredCredits` | decimal(5,1) | no |
| `IpedsAwardLevel` | varchar(3) | no |
| `DivisionCode` | varchar(30) | no |
| `IsActive` | bit | no |
| `CreatedAtUtc` | datetime2(3) | no |
| `UpdatedAtUtc` | datetime2(3) | no |

### `reference.AcademicStandingRule` (table)

Academic standing by cumulative GPA (project assumption; docs/specifications/report-catalog.md R4). A student without GPA credits is NOT_EVALUATED, which needs no range here.

| Column | Type | Nullable |
|---|---|---|
| `StandingCode` | varchar(20) | no |
| `Description` | nvarchar(200) | no |
| `MinCumulativeGpa` | decimal(3,2) | no |
| `MaxCumulativeGpaExclusive` | decimal(3,2) | yes |
| `CreatedAtUtc` | datetime2(3) | no |
| `UpdatedAtUtc` | datetime2(3) | no |

### `reference.AcademicTerm` (table)

Governed term calendar used by integration and compliance. It must agree with the J1-Sim term table; a database test enforces that agreement after seeding. Summer terms belong to the academic year of the preceding fall (project assumption, documented in the business glossary).

| Column | Type | Nullable |
|---|---|---|
| `TermCode` | varchar(10) | no |
| `TermName` | nvarchar(50) | no |
| `TermType` | varchar(10) | no |
| `AcademicYear` | char(9) | no |
| `StartDate` | date | no |
| `CensusDate` | date | no |
| `EndDate` | date | no |
| `IsOpenForAdmission` | bit | no |
| `CreatedAtUtc` | datetime2(3) | no |
| `UpdatedAtUtc` | datetime2(3) | no |

### `reference.AgingBucket` (table)

Account aging buckets by days past due on the as-of date. A NULL bound is open-ended. Buckets must not overlap; the aging tests check every boundary day.

| Column | Type | Nullable |
|---|---|---|
| `BucketCode` | varchar(10) | no |
| `BucketName` | nvarchar(50) | no |
| `MinDaysPastDue` | int | yes |
| `MaxDaysPastDue` | int | yes |
| `SortOrder` | tinyint | no |
| `CreatedAtUtc` | datetime2(3) | no |
| `UpdatedAtUtc` | datetime2(3) | no |

### `reference.AidFund` (table)

Financial aid funds and how reports classify them. IsFederalStudentLoan marks loans made to the student (IPEDS SFA "federal loans to students"; PLUS loans would be 0).

| Column | Type | Nullable |
|---|---|---|
| `FundCode` | varchar(15) | no |
| `FundName` | nvarchar(100) | no |
| `FundSource` | varchar(15) | no |
| `FundType` | varchar(10) | no |
| `IsPell` | bit | no |
| `IsFederalStudentLoan` | bit | no |
| `CreatedAtUtc` | datetime2(3) | no |
| `UpdatedAtUtc` | datetime2(3) | no |

### `reference.ApprovalStatus` (table)

Governed extract approval status codes (docs/specifications/extract-controls.md).

| Column | Type | Nullable |
|---|---|---|
| `ApprovalStatusCode` | varchar(15) | no |
| `Description` | nvarchar(200) | no |
| `CreatedAtUtc` | datetime2(3) | no |
| `UpdatedAtUtc` | datetime2(3) | no |

### `reference.BatchStatus` (table)

| Column | Type | Nullable |
|---|---|---|
| `BatchStatusCode` | varchar(20) | no |
| `Description` | nvarchar(200) | no |
| `IsTerminal` | bit | no |
| `CreatedAtUtc` | datetime2(3) | no |
| `UpdatedAtUtc` | datetime2(3) | no |

### `reference.BatchStepStatus` (table)

| Column | Type | Nullable |
|---|---|---|
| `BatchStepStatusCode` | varchar(20) | no |
| `Description` | nvarchar(200) | no |
| `IsTerminal` | bit | no |
| `CreatedAtUtc` | datetime2(3) | no |
| `UpdatedAtUtc` | datetime2(3) | no |

### `reference.Department` (table)

Administrative offices that own reports, measures, extracts and data-quality rules. DepartmentName equals the OwnerDepartment text used by dq.Rule and reference.ExceptionReason.

| Column | Type | Nullable |
|---|---|---|
| `DepartmentCode` | varchar(30) | no |
| `DepartmentName` | nvarchar(100) | no |
| `CreatedAtUtc` | datetime2(3) | no |
| `UpdatedAtUtc` | datetime2(3) | no |

### `reference.ExceptionReason` (table)

| Column | Type | Nullable |
|---|---|---|
| `ExceptionReasonCode` | varchar(40) | no |
| `Description` | nvarchar(400) | no |
| `Category` | varchar(20) | no |
| `DefaultSeverity` | varchar(10) | no |
| `OwnerDepartment` | nvarchar(100) | no |
| `BlocksProcessing` | bit | no |
| `RemediationGuidance` | nvarchar(800) | no |
| `IsActive` | bit | no |
| `CreatedAtUtc` | datetime2(3) | no |
| `UpdatedAtUtc` | datetime2(3) | no |

### `reference.ExceptionStatus` (table)

Integration exception lifecycle states. IsActiveState = 1 for states in which a repeat of the same condition updates the existing exception instead of creating a new one.

| Column | Type | Nullable |
|---|---|---|
| `ExceptionStatusCode` | varchar(30) | no |
| `Description` | nvarchar(400) | no |
| `IsActiveState` | bit | no |
| `SortOrder` | tinyint | no |
| `CreatedAtUtc` | datetime2(3) | no |
| `UpdatedAtUtc` | datetime2(3) | no |

### `reference.ExceptionStatusTransition` (table)

Allowed exception status changes. integration.ExceptionAction references this table, so a transition that is not listed here cannot be recorded.

| Column | Type | Nullable |
|---|---|---|
| `FromStatusCode` | varchar(30) | no |
| `ToStatusCode` | varchar(30) | no |
| `Description` | nvarchar(400) | no |
| `CreatedAtUtc` | datetime2(3) | no |
| `UpdatedAtUtc` | datetime2(3) | no |

### `reference.ExtractSchedule` (table)

Which extracts each Agent schedule produces and how their reporting period is chosen (docs/specifications/extract-controls.md); compliance.usp_RunScheduledExtracts reads it.

| Column | Type | Nullable |
|---|---|---|
| `ScheduleCode` | varchar(10) | no |
| `ExtractTypeCode` | varchar(30) | no |
| `PeriodRule` | varchar(30) | no |
| `SortOrder` | tinyint | no |
| `CreatedAtUtc` | datetime2(3) | no |
| `UpdatedAtUtc` | datetime2(3) | no |

### `reference.ExtractStatus` (table)

Governed extract run status codes (docs/specifications/extract-controls.md).

| Column | Type | Nullable |
|---|---|---|
| `ExtractStatusCode` | varchar(15) | no |
| `Description` | nvarchar(200) | no |
| `CreatedAtUtc` | datetime2(3) | no |
| `UpdatedAtUtc` | datetime2(3) | no |

### `reference.ExtractType` (table)

Every extract the platform produces (docs/specifications/extract-controls.md). AccessRoleName is the department role allowed to generate and export it (the integration service and db_owner may too). Only aggregate types may be public-safe. GeneratorVersion changes whenever the builder's output changes.

| Column | Type | Nullable |
|---|---|---|
| `ExtractTypeCode` | varchar(30) | no |
| `Description` | nvarchar(400) | no |
| `Grain` | nvarchar(200) | no |
| `OwnerDepartmentCode` | varchar(30) | no |
| `SecurityClass` | varchar(25) | no |
| `PeriodType` | varchar(15) | no |
| `AccessRoleName` | nvarchar(128) | no |
| `IsPublicSafe` | bit | no |
| `IsPrivileged` | bit | no |
| `GeneratorVersion` | varchar(10) | no |
| `CreatedAtUtc` | datetime2(3) | no |
| `UpdatedAtUtc` | datetime2(3) | no |

### `reference.MatchDecisionType` (table)

Outcome of one match evaluation. AllowsProcessing marks decisions that may be queued for J1-Sim; blocked decisions name the exception reason they raise.

| Column | Type | Nullable |
|---|---|---|
| `DecisionTypeCode` | varchar(20) | no |
| `Description` | nvarchar(400) | no |
| `AllowsProcessing` | bit | no |
| `IsManual` | bit | no |
| `ExceptionReasonCode` | varchar(40) | yes |
| `CreatedAtUtc` | datetime2(3) | no |
| `UpdatedAtUtc` | datetime2(3) | no |

### `reference.MatchRule` (table)

Ordered deterministic match rules (docs/specifications/matching-rules.md). Only rules with IsAutoMatchEligible = 1 may produce an AUTO_MATCH, and integration.MatchDecision enforces the same list in a CHECK constraint.

| Column | Type | Nullable |
|---|---|---|
| `RuleCode` | varchar(20) | no |
| `Priority` | tinyint | no |
| `Description` | nvarchar(400) | no |
| `ConfidenceCategory` | varchar(10) | no |
| `IsAutoMatchEligible` | bit | no |
| `CreatedAtUtc` | datetime2(3) | no |
| `UpdatedAtUtc` | datetime2(3) | no |

### `reference.OutboundAction` (table)

Write actions the outbound queue can request from the J1-Sim import interface. RequiresTargetIdNumber = 1 when the action applies to an existing J1-Sim person.

| Column | Type | Nullable |
|---|---|---|
| `ActionCode` | varchar(30) | no |
| `Description` | nvarchar(400) | no |
| `RequiresTargetIdNumber` | bit | no |
| `ReconciliationOutcome` | varchar(20) | no |
| `CreatedAtUtc` | datetime2(3) | no |
| `UpdatedAtUtc` | datetime2(3) | no |

### `reference.OutboundQueueStatus` (table)

| Column | Type | Nullable |
|---|---|---|
| `QueueStatusCode` | varchar(20) | no |
| `Description` | nvarchar(400) | no |
| `IsSendable` | bit | no |
| `IsTerminal` | bit | no |
| `CreatedAtUtc` | datetime2(3) | no |
| `UpdatedAtUtc` | datetime2(3) | no |

### `reference.PipelineStep` (table)

Ordered steps of the NIGHTLY_INTEGRATION pipeline. A step runs only after every earlier step in the same run has SUCCEEDED or been SKIPPED by a recovery run.

| Column | Type | Nullable |
|---|---|---|
| `StepCode` | varchar(20) | no |
| `StepOrder` | smallint | no |
| `Description` | nvarchar(400) | no |
| `CreatedAtUtc` | datetime2(3) | no |
| `UpdatedAtUtc` | datetime2(3) | no |

### `reference.ProgramCrosswalk` (table)

Maps admissions (Slate-Sim) program codes to SIS (J1-Sim) program codes. A Slate code absent from this table, or mapped to an inactive SIS program, cannot be integrated.

| Column | Type | Nullable |
|---|---|---|
| `SlateProgramCode` | varchar(20) | no |
| `J1ProgramCode` | varchar(20) | no |
| `ProgramName` | nvarchar(150) | no |
| `CredentialLevel` | varchar(20) | no |
| `CipCode` | char(7) | no |
| `IsActive` | bit | no |
| `EffectiveFrom` | date | no |
| `EffectiveTo` | date | yes |
| `CreatedAtUtc` | datetime2(3) | no |
| `UpdatedAtUtc` | datetime2(3) | no |

### `reference.ReconciliationOutcome` (table)

Mutually exclusive per-application outcomes of one reconciliation run.

| Column | Type | Nullable |
|---|---|---|
| `OutcomeCode` | varchar(20) | no |
| `Description` | nvarchar(400) | no |
| `SortOrder` | tinyint | no |
| `CreatedAtUtc` | datetime2(3) | no |
| `UpdatedAtUtc` | datetime2(3) | no |

### `reference.SourceSystem` (table)

| Column | Type | Nullable |
|---|---|---|
| `SourceSystemCode` | varchar(20) | no |
| `SourceSystemName` | nvarchar(100) | no |
| `Description` | nvarchar(400) | no |
| `IsActive` | bit | no |
| `CreatedAtUtc` | datetime2(3) | no |
| `UpdatedAtUtc` | datetime2(3) | no |

### `reference.ValidationStatus` (table)

Governed extract validation status codes (docs/specifications/extract-controls.md).

| Column | Type | Nullable |
|---|---|---|
| `ValidationStatusCode` | varchar(15) | no |
| `Description` | nvarchar(200) | no |
| `CreatedAtUtc` | datetime2(3) | no |
| `UpdatedAtUtc` | datetime2(3) | no |

## audit

Batches, steps, errors, privileged access and permission changes.

### `audit.AccessEvent` (table)

Privileged data access: extract generation, export and approval, exception drill-through and security administration (docs/architecture/security-model.md). Refused attempts are logged too (IsAllowed = 0). Detail holds codes and reasons, never protected values.

| Column | Type | Nullable |
|---|---|---|
| `AccessEventId` | bigint | no |
| `EventType` | varchar(30) | no |
| `ObjectName` | nvarchar(256) | no |
| `DatabaseUser` | nvarchar(128) | no |
| `OriginalLogin` | nvarchar(128) | no |
| `IsPrivileged` | bit | no |
| `IsAllowed` | bit | no |
| `ExtractRunId` | bigint | yes |
| `SubjectKey` | varchar(100) | yes |
| `Detail` | nvarchar(400) | yes |
| `OccurredAtUtc` | datetime2(3) | no |

### `audit.BatchRun` (table)

One row per execution of a process (a source landing load or a scheduled job). Watermarks advance only on SUCCEEDED landing batches; the landing procedures enforce it. ParentBatchId links a landing batch to the pipeline run that requested it; RecoveryOfBatchId links a recovery run to the FAILED run it resumes.

| Column | Type | Nullable |
|---|---|---|
| `BatchId` | bigint | no |
| `ProcessName` | varchar(100) | no |
| `SourceSystemCode` | varchar(20) | yes |
| `ParentBatchId` | bigint | yes |
| `RecoveryOfBatchId` | bigint | yes |
| `BatchStatusCode` | varchar(20) | no |
| `RequestedAtUtc` | datetime2(3) | no |
| `StartedAtUtc` | datetime2(3) | no |
| `EndedAtUtc` | datetime2(3) | yes |
| `InvokedBy` | nvarchar(128) | no |
| `PreviousWatermarkUtc` | datetime2(3) | yes |
| `SourceWatermarkUtc` | datetime2(3) | yes |
| `RowsRead` | int | yes |
| `RowsInserted` | int | yes |
| `RowsUpdated` | int | yes |
| `RowsUnchanged` | int | yes |
| `RowsRejected` | int | yes |
| `ExceptionCount` | int | yes |
| `CreatedAtUtc` | datetime2(3) | no |
| `UpdatedAtUtc` | datetime2(3) | no |

### `audit.BatchStep` (table)

| Column | Type | Nullable |
|---|---|---|
| `BatchStepId` | bigint | no |
| `BatchId` | bigint | no |
| `StepName` | varchar(100) | no |
| `StepOrder` | smallint | no |
| `AttemptNumber` | smallint | no |
| `BatchStepStatusCode` | varchar(20) | no |
| `StartedAtUtc` | datetime2(3) | no |
| `EndedAtUtc` | datetime2(3) | yes |
| `RowsAffected` | int | yes |
| `CreatedAtUtc` | datetime2(3) | no |
| `UpdatedAtUtc` | datetime2(3) | no |

### `audit.ErrorLog` (table)

Error text comes from the engine and may quote key values; procedures must not raise custom messages that embed personal data (names, birth dates, contact values).

| Column | Type | Nullable |
|---|---|---|
| `ErrorLogId` | bigint | no |
| `BatchId` | bigint | yes |
| `BatchStepId` | bigint | yes |
| `ErrorNumber` | int | no |
| `ErrorSeverity` | int | no |
| `ErrorState` | int | no |
| `ErrorProcedure` | nvarchar(128) | yes |
| `ErrorLine` | int | yes |
| `ErrorMessage` | nvarchar(4000) | no |
| `LoggedBy` | nvarchar(128) | no |
| `LoggedAtUtc` | datetime2(3) | no |

### `audit.PermissionChangeEvent` (table)

Every database security change (GRANT, DENY, REVOKE, role membership, user and role DDL), written by the database DDL trigger trg_audit_PermissionChange (docs/architecture/security-model.md).

| Column | Type | Nullable |
|---|---|---|
| `PermissionChangeEventId` | bigint | no |
| `EventType` | nvarchar(64) | no |
| `LoginName` | nvarchar(128) | yes |
| `UserName` | nvarchar(128) | yes |
| `ObjectName` | nvarchar(256) | yes |
| `Permissions` | nvarchar(400) | yes |
| `Grantees` | nvarchar(400) | yes |
| `CommandText` | nvarchar(2000) | yes |
| `OccurredAtUtc` | datetime2(3) | no |

## landing

Append-only source rows as received (ADR-002). Denied to every role.

### `landing.DirectoryAccountRaw` (table)

One row per Directory-Sim account per version received, with its groups as a sorted list. Append-only (ADR-002). A row is inserted only when its RecordHash differs from the latest landed version of the same key; one version per key per batch is database-enforced.

| Column | Type | Nullable |
|---|---|---|
| `LandingRowId` | bigint | no |
| `BatchId` | bigint | no |
| `SourceSystemCode` | varchar(20) | no |
| `AccountGuid` | uniqueidentifier | no |
| `SamAccountName` | varchar(64) | no |
| `UserPrincipalName` | nvarchar(256) | no |
| `EmployeeId` | varchar(20) | yes |
| `DisplayName` | nvarchar(200) | no |
| `AccountType` | varchar(10) | no |
| `IsEnabled` | bit | no |
| `WhenCreatedUtc` | datetime2(3) | no |
| `GroupNames` | nvarchar(4000) | yes |
| `SourceRecordId` | varchar(64) | no |
| `SourceUpdatedAtUtc` | datetime2(3) | no |
| `RecordHash` | binary(32) | no |
| `RequestId` | varchar(100) | no |
| `IngestedAtUtc` | datetime2(3) | no |

### `landing.J1AccountControlTotal` (table)

Source-side count and sum of account transactions per student and term, captured when any transaction in the group changed. dq.usp_CheckAccountControlTotals reconciles staged detail to the latest captured total. Append-only (ADR-002). A row is inserted only when its RecordHash differs from the latest landed version of the same key; one version per key per batch is database-enforced.

| Column | Type | Nullable |
|---|---|---|
| `LandingRowId` | bigint | no |
| `BatchId` | bigint | no |
| `SourceSystemCode` | varchar(20) | no |
| `IdNumber` | int | no |
| `TermCode` | varchar(10) | no |
| `TransactionCount` | int | no |
| `AmountTotal` | decimal(14,2) | no |
| `SourceRecordId` | varchar(23) | no |
| `SourceUpdatedAtUtc` | datetime2(3) | no |
| `RecordHash` | binary(32) | no |
| `RequestId` | varchar(100) | no |
| `IngestedAtUtc` | datetime2(3) | no |

### `landing.J1AccountTransactionRaw` (table)

One row per J1-Sim student account transaction per version received. Append-only (ADR-002). A row is inserted only when its RecordHash differs from the latest landed version of the same key; one version per key per batch is database-enforced.

| Column | Type | Nullable |
|---|---|---|
| `LandingRowId` | bigint | no |
| `BatchId` | bigint | no |
| `SourceSystemCode` | varchar(20) | no |
| `TransactionId` | bigint | no |
| `IdNumber` | int | no |
| `TermCode` | varchar(10) | no |
| `TransactionType` | varchar(12) | no |
| `DetailCode` | varchar(10) | no |
| `Amount` | decimal(12,2) | no |
| `PostedDate` | date | no |
| `DueDate` | date | yes |
| `SourceRecordId` | varchar(64) | no |
| `SourceUpdatedAtUtc` | datetime2(3) | no |
| `RecordHash` | binary(32) | no |
| `RequestId` | varchar(100) | no |
| `IngestedAtUtc` | datetime2(3) | no |

### `landing.J1CredentialRaw` (table)

One row per J1-Sim credential award per version received. Append-only (ADR-002). A row is inserted only when its RecordHash differs from the latest landed version of the same key; one version per key per batch is database-enforced.

| Column | Type | Nullable |
|---|---|---|
| `LandingRowId` | bigint | no |
| `BatchId` | bigint | no |
| `SourceSystemCode` | varchar(20) | no |
| `CredentialAwardedId` | bigint | no |
| `IdNumber` | int | no |
| `ProgramCode` | varchar(20) | no |
| `TermCode` | varchar(10) | no |
| `AwardedDate` | date | no |
| `SourceRecordId` | varchar(64) | no |
| `SourceUpdatedAtUtc` | datetime2(3) | no |
| `RecordHash` | binary(32) | no |
| `RequestId` | varchar(100) | no |
| `IngestedAtUtc` | datetime2(3) | no |

### `landing.J1EnrollmentRaw` (table)

One row per J1-Sim enrollment per version received, with section and final grade. Append-only (ADR-002). A row is inserted only when its RecordHash differs from the latest landed version of the same key; one version per key per batch is database-enforced.

| Column | Type | Nullable |
|---|---|---|
| `LandingRowId` | bigint | no |
| `BatchId` | bigint | no |
| `SourceSystemCode` | varchar(20) | no |
| `EnrollmentId` | bigint | no |
| `IdNumber` | int | no |
| `CourseSectionId` | int | no |
| `TermCode` | varchar(10) | no |
| `SubjectCode` | varchar(6) | no |
| `CourseNumber` | varchar(6) | no |
| `SectionNumber` | varchar(4) | no |
| `CreditHours` | decimal(4,1) | no |
| `RegistrationStatus` | varchar(15) | no |
| `RegisteredAtUtc` | datetime2(3) | no |
| `StatusChangedAtUtc` | datetime2(3) | no |
| `GradeCode` | varchar(2) | yes |
| `GradePoints` | decimal(3,2) | yes |
| `GradePostedAtUtc` | datetime2(3) | yes |
| `SourceRecordId` | varchar(64) | no |
| `SourceUpdatedAtUtc` | datetime2(3) | no |
| `RecordHash` | binary(32) | no |
| `RequestId` | varchar(100) | no |
| `IngestedAtUtc` | datetime2(3) | no |

### `landing.J1FinancialAidRaw` (table)

One row per J1-Sim financial aid award per version received. Append-only (ADR-002). A row is inserted only when its RecordHash differs from the latest landed version of the same key; one version per key per batch is database-enforced.

| Column | Type | Nullable |
|---|---|---|
| `LandingRowId` | bigint | no |
| `BatchId` | bigint | no |
| `SourceSystemCode` | varchar(20) | no |
| `AwardId` | bigint | no |
| `IdNumber` | int | no |
| `AidYear` | char(9) | no |
| `TermCode` | varchar(10) | no |
| `FundCode` | varchar(15) | no |
| `AwardStatus` | varchar(10) | no |
| `OfferedAmount` | decimal(12,2) | no |
| `AcceptedAmount` | decimal(12,2) | no |
| `DisbursedAmount` | decimal(12,2) | no |
| `SourceRecordId` | varchar(64) | no |
| `SourceUpdatedAtUtc` | datetime2(3) | no |
| `RecordHash` | binary(32) | no |
| `RequestId` | varchar(100) | no |
| `IngestedAtUtc` | datetime2(3) | no |

### `landing.J1PersonRaw` (table)

One row per J1-Sim person per version received, with the student record if any. Append-only (ADR-002). A row is inserted only when its RecordHash differs from the latest landed version of the same key; one version per key per batch is database-enforced.

| Column | Type | Nullable |
|---|---|---|
| `LandingRowId` | bigint | no |
| `BatchId` | bigint | no |
| `SourceSystemCode` | varchar(20) | no |
| `IdNumber` | int | no |
| `FirstName` | nvarchar(100) | no |
| `MiddleName` | nvarchar(100) | yes |
| `LastName` | nvarchar(100) | no |
| `BirthDate` | date | no |
| `Email` | nvarchar(320) | yes |
| `Phone` | varchar(20) | yes |
| `AddressLine1` | nvarchar(200) | yes |
| `City` | nvarchar(100) | yes |
| `StateCode` | char(2) | yes |
| `PostalCode` | varchar(10) | yes |
| `StudentProgramCode` | varchar(20) | yes |
| `StudentEntryTermCode` | varchar(10) | yes |
| `StudentStatus` | varchar(20) | yes |
| `ResidencyCode` | varchar(20) | yes |
| `MatriculationDate` | date | yes |
| `SourceRecordId` | varchar(64) | no |
| `SourceUpdatedAtUtc` | datetime2(3) | no |
| `RecordHash` | binary(32) | no |
| `RequestId` | varchar(100) | no |
| `IngestedAtUtc` | datetime2(3) | no |

### `landing.SlateApplicantRaw` (table)

One row per Slate-Sim person per version received. Values are exactly as extracted; standardization happens in staging. Append-only (ADR-002). A row is inserted only when its RecordHash differs from the latest landed version of the same key; one version per key per batch is database-enforced.

| Column | Type | Nullable |
|---|---|---|
| `LandingRowId` | bigint | no |
| `BatchId` | bigint | no |
| `SourceSystemCode` | varchar(20) | no |
| `PersonId` | uniqueidentifier | no |
| `FirstName` | nvarchar(100) | yes |
| `MiddleName` | nvarchar(100) | yes |
| `LastName` | nvarchar(100) | yes |
| `PreferredName` | nvarchar(100) | yes |
| `BirthDate` | date | yes |
| `Email` | nvarchar(320) | yes |
| `Phone` | nvarchar(320) | yes |
| `AddressLine1` | nvarchar(200) | yes |
| `AddressLine2` | nvarchar(200) | yes |
| `City` | nvarchar(100) | yes |
| `StateCode` | char(2) | yes |
| `PostalCode` | varchar(10) | yes |
| `CountryCode` | char(2) | yes |
| `SisIdClaim` | varchar(50) | yes |
| `SourceRecordId` | varchar(64) | no |
| `SourceUpdatedAtUtc` | datetime2(3) | no |
| `RecordHash` | binary(32) | no |
| `RequestId` | varchar(100) | no |
| `IngestedAtUtc` | datetime2(3) | no |

### `landing.SlateApplicationRaw` (table)

One row per Slate-Sim application per version received, with ranked program choices and the admitted-applicant export time. Append-only (ADR-002). A row is inserted only when its RecordHash differs from the latest landed version of the same key; one version per key per batch is database-enforced.

| Column | Type | Nullable |
|---|---|---|
| `LandingRowId` | bigint | no |
| `BatchId` | bigint | no |
| `SourceSystemCode` | varchar(20) | no |
| `ApplicationId` | uniqueidentifier | no |
| `PersonId` | uniqueidentifier | no |
| `EntryTermCode` | varchar(10) | yes |
| `StudentType` | varchar(20) | no |
| `ApplicationStatus` | varchar(20) | no |
| `SubmittedAtUtc` | datetime2(3) | yes |
| `DecisionAtUtc` | datetime2(3) | yes |
| `ProgramChoice1` | varchar(20) | yes |
| `ProgramChoice2` | varchar(20) | yes |
| `ProgramChoice3` | varchar(20) | yes |
| `ExportQueuedAtUtc` | datetime2(3) | yes |
| `SourceRecordId` | varchar(64) | no |
| `SourceUpdatedAtUtc` | datetime2(3) | no |
| `RecordHash` | binary(32) | no |
| `RequestId` | varchar(100) | no |
| `IngestedAtUtc` | datetime2(3) | no |

### `landing.vw_SourceDirectoryAccount` (view)

Extract boundary for Directory-Sim accounts with their groups as a sorted list.

| Column | Type | Nullable |
|---|---|---|
| `AccountGuid` | uniqueidentifier | no |
| `SamAccountName` | varchar(64) | no |
| `UserPrincipalName` | nvarchar(256) | no |
| `EmployeeId` | varchar(20) | yes |
| `DisplayName` | nvarchar(200) | no |
| `AccountType` | varchar(10) | no |
| `IsEnabled` | bit | no |
| `WhenCreatedUtc` | datetime2(3) | no |
| `GroupNames` | nvarchar(4000) | yes |
| `SourceUpdatedAtUtc` | datetime2(3) | yes |

### `landing.vw_SourceJ1AccountControlTotal` (view)

The source's own count and sum of account transactions per student and term. J1-Sim stores no balance, so these totals, captured at load time, are what staged detail reconciles to.

| Column | Type | Nullable |
|---|---|---|
| `IdNumber` | int | no |
| `TermCode` | varchar(10) | no |
| `TransactionCount` | bigint | yes |
| `AmountTotal` | decimal(38,2) | yes |
| `SourceUpdatedAtUtc` | datetime2(3) | yes |

### `landing.vw_SourceJ1AccountTransaction` (view)

| Column | Type | Nullable |
|---|---|---|
| `TransactionId` | bigint | no |
| `IdNumber` | int | no |
| `TermCode` | varchar(10) | no |
| `TransactionType` | varchar(12) | no |
| `DetailCode` | varchar(10) | no |
| `Amount` | decimal(12,2) | no |
| `PostedDate` | date | no |
| `DueDate` | date | yes |
| `SourceUpdatedAtUtc` | datetime2(3) | no |

### `landing.vw_SourceJ1Credential` (view)

| Column | Type | Nullable |
|---|---|---|
| `CredentialAwardedId` | bigint | no |
| `IdNumber` | int | no |
| `ProgramCode` | varchar(20) | no |
| `TermCode` | varchar(10) | no |
| `AwardedDate` | date | no |
| `SourceUpdatedAtUtc` | datetime2(3) | no |

### `landing.vw_SourceJ1Enrollment` (view)

Extract boundary for J1-Sim enrollments with their section and final grade.

| Column | Type | Nullable |
|---|---|---|
| `EnrollmentId` | bigint | no |
| `IdNumber` | int | no |
| `CourseSectionId` | int | no |
| `TermCode` | varchar(10) | no |
| `SubjectCode` | varchar(6) | no |
| `CourseNumber` | varchar(6) | no |
| `SectionNumber` | varchar(4) | no |
| `CreditHours` | decimal(4,1) | no |
| `RegistrationStatus` | varchar(15) | no |
| `RegisteredAtUtc` | datetime2(3) | no |
| `StatusChangedAtUtc` | datetime2(3) | no |
| `GradeCode` | varchar(2) | yes |
| `GradePoints` | decimal(3,2) | yes |
| `GradePostedAtUtc` | datetime2(3) | yes |
| `SourceUpdatedAtUtc` | datetime2(3) | yes |

### `landing.vw_SourceJ1FinancialAid` (view)

| Column | Type | Nullable |
|---|---|---|
| `AwardId` | bigint | no |
| `IdNumber` | int | no |
| `AidYear` | char(9) | no |
| `TermCode` | varchar(10) | no |
| `FundCode` | varchar(15) | no |
| `AwardStatus` | varchar(10) | no |
| `OfferedAmount` | decimal(12,2) | no |
| `AcceptedAmount` | decimal(12,2) | no |
| `DisbursedAmount` | decimal(12,2) | no |
| `SourceUpdatedAtUtc` | datetime2(3) | no |

### `landing.vw_SourceJ1Person` (view)

Extract boundary for J1-Sim people with their student record, if any.

| Column | Type | Nullable |
|---|---|---|
| `IdNumber` | int | no |
| `FirstName` | nvarchar(100) | no |
| `MiddleName` | nvarchar(100) | yes |
| `LastName` | nvarchar(100) | no |
| `BirthDate` | date | no |
| `Email` | nvarchar(320) | yes |
| `Phone` | varchar(20) | yes |
| `AddressLine1` | nvarchar(200) | yes |
| `City` | nvarchar(100) | yes |
| `StateCode` | char(2) | yes |
| `PostalCode` | varchar(10) | yes |
| `StudentProgramCode` | varchar(20) | yes |
| `StudentEntryTermCode` | varchar(10) | yes |
| `StudentStatus` | varchar(20) | yes |
| `ResidencyCode` | varchar(20) | yes |
| `MatriculationDate` | date | yes |
| `SourceUpdatedAtUtc` | datetime2(3) | yes |

### `landing.vw_SourceSlateApplicant` (view)

Extract boundary for Slate-Sim people: one row per person with the primary email, primary phone, primary address and SIS ID claim. SourceUpdatedAtUtc is the latest change across all of those rows, so a corrected email alone makes the person eligible for the next load.

| Column | Type | Nullable |
|---|---|---|
| `PersonId` | uniqueidentifier | no |
| `FirstName` | nvarchar(100) | yes |
| `MiddleName` | nvarchar(100) | yes |
| `LastName` | nvarchar(100) | yes |
| `PreferredName` | nvarchar(100) | yes |
| `BirthDate` | date | yes |
| `Email` | nvarchar(320) | yes |
| `Phone` | nvarchar(320) | yes |
| `AddressLine1` | nvarchar(200) | yes |
| `AddressLine2` | nvarchar(200) | yes |
| `City` | nvarchar(100) | yes |
| `StateCode` | char(2) | yes |
| `PostalCode` | varchar(10) | yes |
| `CountryCode` | char(2) | yes |
| `SisIdClaim` | varchar(50) | yes |
| `SourceUpdatedAtUtc` | datetime2(3) | yes |

### `landing.vw_SourceSlateApplication` (view)

Extract boundary for Slate-Sim applications: one row per application with its ranked program choices and its admitted-applicant export, if any.

| Column | Type | Nullable |
|---|---|---|
| `ApplicationId` | uniqueidentifier | no |
| `PersonId` | uniqueidentifier | no |
| `EntryTermCode` | varchar(10) | yes |
| `StudentType` | varchar(20) | no |
| `ApplicationStatus` | varchar(20) | no |
| `SubmittedAtUtc` | datetime2(3) | yes |
| `DecisionAtUtc` | datetime2(3) | yes |
| `ProgramChoice1` | varchar(20) | yes |
| `ProgramChoice2` | varchar(20) | yes |
| `ProgramChoice3` | varchar(20) | yes |
| `ExportQueuedAtUtc` | datetime2(3) | yes |
| `SourceUpdatedAtUtc` | datetime2(3) | yes |

## staging

Current standardized rows. Denied to every role.

### `staging.AccountTransaction` (table)

| Column | Type | Nullable |
|---|---|---|
| `TransactionId` | bigint | no |
| `LandingRowId` | bigint | no |
| `IdNumber` | int | no |
| `TermCode` | varchar(10) | no |
| `TransactionType` | varchar(12) | no |
| `DetailCode` | varchar(10) | no |
| `Amount` | decimal(12,2) | no |
| `PostedDate` | date | no |
| `DueDate` | date | yes |
| `LastStagedBatchId` | bigint | no |
| `CreatedAtUtc` | datetime2(3) | no |
| `UpdatedAtUtc` | datetime2(3) | no |

### `staging.Applicant` (table)

Current standardized state of each Slate-Sim application, with the applicant's person values. Raw values sit beside standardized ones; nothing is corrected silently. Validation columns describe the problem with codes; integration.usp_CreateIntegrationExceptions turns them into exceptions. SourceHash changes only when the landed source values change, and is what matching uses to decide whether an application needs a new decision. Validity flags are NULL when the raw value is absent or blank, 1 when it standardizes and 0 when it is present but invalid.

| Column | Type | Nullable |
|---|---|---|
| `ApplicationId` | uniqueidentifier | no |
| `SlatePersonId` | uniqueidentifier | no |
| `ApplicantLandingRowId` | bigint | no |
| `ApplicationLandingRowId` | bigint | no |
| `SourceHash` | binary(32) | no |
| `ApplicationStatus` | varchar(20) | no |
| `StudentType` | varchar(20) | no |
| `ExportQueuedAtUtc` | datetime2(3) | yes |
| `IsEligible` | bit | no |
| `FirstNameRaw` | nvarchar(100) | yes |
| `FirstNameStd` | nvarchar(100) | yes |
| `MiddleNameRaw` | nvarchar(100) | yes |
| `MiddleNameStd` | nvarchar(100) | yes |
| `LastNameRaw` | nvarchar(100) | yes |
| `LastNameStd` | nvarchar(100) | yes |
| `BirthDate` | date | yes |
| `EmailRaw` | nvarchar(320) | yes |
| `EmailStd` | nvarchar(320) | yes |
| `IsEmailValid` | bit | yes |
| `PhoneRaw` | nvarchar(320) | yes |
| `PhoneStd` | varchar(10) | yes |
| `IsPhoneValid` | bit | yes |
| `AddressLine1` | nvarchar(200) | yes |
| `City` | nvarchar(100) | yes |
| `StateCode` | char(2) | yes |
| `CountryCode` | char(2) | yes |
| `PostalCodeRaw` | varchar(10) | yes |
| `PostalCode5` | char(5) | yes |
| `ResidencyCode` | varchar(20) | no |
| `SisIdClaimRaw` | varchar(50) | yes |
| `SisIdClaim` | int | yes |
| `IsSisIdClaimValid` | bit | yes |
| `EntryTermCodeRaw` | varchar(10) | yes |
| `EntryTermCode` | varchar(10) | yes |
| `TermValidationCode` | varchar(20) | yes |
| `ProgramChoice1Raw` | varchar(20) | yes |
| `J1ProgramCode` | varchar(20) | yes |
| `ProgramValidationCode` | varchar(20) | yes |
| `MissingRequiredFields` | varchar(100) | yes |
| `DuplicateApplicationCount` | int | no |
| `FirstStagedBatchId` | bigint | no |
| `LastStagedBatchId` | bigint | no |
| `CreatedAtUtc` | datetime2(3) | no |
| `UpdatedAtUtc` | datetime2(3) | no |

### `staging.CredentialAwarded` (table)

Current state of each J1-Sim credential award (certificate or associate degree).

| Column | Type | Nullable |
|---|---|---|
| `CredentialAwardedId` | bigint | no |
| `LandingRowId` | bigint | no |
| `IdNumber` | int | no |
| `ProgramCode` | varchar(20) | no |
| `TermCode` | varchar(10) | no |
| `AwardedDate` | date | no |
| `LastStagedBatchId` | bigint | no |
| `CreatedAtUtc` | datetime2(3) | no |
| `UpdatedAtUtc` | datetime2(3) | no |

### `staging.DirectoryAccount` (table)

Current state of each Directory-Sim account. EmployeeIdNumber is the EmployeeId parsed as a J1-Sim ID number when it is exactly seven digits; the raw text is kept beside it.

| Column | Type | Nullable |
|---|---|---|
| `AccountGuid` | uniqueidentifier | no |
| `LandingRowId` | bigint | no |
| `SamAccountName` | varchar(64) | no |
| `AccountType` | varchar(10) | no |
| `IsEnabled` | bit | no |
| `EmployeeIdRaw` | varchar(20) | yes |
| `EmployeeIdNumber` | int | yes |
| `GroupNames` | nvarchar(4000) | yes |
| `LastStagedBatchId` | bigint | no |
| `CreatedAtUtc` | datetime2(3) | no |
| `UpdatedAtUtc` | datetime2(3) | no |

### `staging.Enrollment` (table)

| Column | Type | Nullable |
|---|---|---|
| `EnrollmentId` | bigint | no |
| `LandingRowId` | bigint | no |
| `IdNumber` | int | no |
| `CourseSectionId` | int | no |
| `TermCode` | varchar(10) | no |
| `SubjectCode` | varchar(6) | no |
| `CourseNumber` | varchar(6) | no |
| `SectionNumber` | varchar(4) | no |
| `CreditHours` | decimal(4,1) | no |
| `RegistrationStatus` | varchar(15) | no |
| `RegisteredAtUtc` | datetime2(3) | no |
| `StatusChangedAtUtc` | datetime2(3) | no |
| `GradeCode` | varchar(2) | yes |
| `GradePoints` | decimal(3,2) | yes |
| `GradePostedAtUtc` | datetime2(3) | yes |
| `LastStagedBatchId` | bigint | no |
| `CreatedAtUtc` | datetime2(3) | no |
| `UpdatedAtUtc` | datetime2(3) | no |

### `staging.FinancialAidAward` (table)

| Column | Type | Nullable |
|---|---|---|
| `AwardId` | bigint | no |
| `LandingRowId` | bigint | no |
| `IdNumber` | int | no |
| `AidYear` | char(9) | no |
| `TermCode` | varchar(10) | no |
| `FundCode` | varchar(15) | no |
| `AwardStatus` | varchar(10) | no |
| `OfferedAmount` | decimal(12,2) | no |
| `AcceptedAmount` | decimal(12,2) | no |
| `DisbursedAmount` | decimal(12,2) | no |
| `LastStagedBatchId` | bigint | no |
| `CreatedAtUtc` | datetime2(3) | no |
| `UpdatedAtUtc` | datetime2(3) | no |

### `staging.Person` (table)

Current standardized state of each J1-Sim person and student record. Matching compares the stored normalized columns, which the two filtered indexes below support.

| Column | Type | Nullable |
|---|---|---|
| `IdNumber` | int | no |
| `LandingRowId` | bigint | no |
| `FirstNameRaw` | nvarchar(100) | no |
| `FirstNameStd` | nvarchar(100) | yes |
| `MiddleNameRaw` | nvarchar(100) | yes |
| `LastNameRaw` | nvarchar(100) | no |
| `LastNameStd` | nvarchar(100) | yes |
| `BirthDate` | date | no |
| `EmailRaw` | nvarchar(320) | yes |
| `EmailStd` | nvarchar(320) | yes |
| `PhoneRaw` | varchar(20) | yes |
| `PhoneStd` | varchar(10) | yes |
| `AddressLine1` | nvarchar(200) | yes |
| `City` | nvarchar(100) | yes |
| `StateCode` | char(2) | yes |
| `PostalCodeRaw` | varchar(10) | yes |
| `PostalCode5` | char(5) | yes |
| `HasStudentRecord` | bit | no |
| `StudentProgramCode` | varchar(20) | yes |
| `StudentEntryTermCode` | varchar(10) | yes |
| `StudentStatus` | varchar(20) | yes |
| `ResidencyCode` | varchar(20) | yes |
| `MatriculationDate` | date | yes |
| `LastStagedBatchId` | bigint | no |
| `CreatedAtUtc` | datetime2(3) | no |
| `UpdatedAtUtc` | datetime2(3) | no |

## core

Conformed views over staging (decision D3). Denied to every role.

### `core.vw_AccountTransaction` (view)

Conformed student account transactions. Positive amounts are debits; a debit without a due date (refunds, adjustments) is due when posted (docs/specifications/report-catalog.md R3).

| Column | Type | Nullable |
|---|---|---|
| `TransactionId` | bigint | no |
| `IdNumber` | int | no |
| `TermCode` | varchar(10) | no |
| `TransactionType` | varchar(12) | no |
| `DetailCode` | varchar(10) | no |
| `Amount` | decimal(12,2) | no |
| `PostedDate` | date | no |
| `DueDate` | date | yes |
| `EffectiveDueDate` | date | yes |

### `core.vw_AidAward` (view)

Conformed financial aid awards with fund classification.

| Column | Type | Nullable |
|---|---|---|
| `AwardId` | bigint | no |
| `IdNumber` | int | no |
| `AidYear` | char(9) | no |
| `TermCode` | varchar(10) | no |
| `FundCode` | varchar(15) | no |
| `FundSource` | varchar(15) | yes |
| `FundType` | varchar(10) | yes |
| `IsPell` | bit | yes |
| `IsFederalStudentLoan` | bit | yes |
| `AwardStatus` | varchar(10) | no |
| `OfferedAmount` | decimal(12,2) | no |
| `AcceptedAmount` | decimal(12,2) | no |
| `DisbursedAmount` | decimal(12,2) | no |

### `core.vw_Application` (view)

Conformed Slate-Sim applications. FunnelTermCode is the raw entry term when it names a governed term (open or closed), so funnel counts do not depend on admission validation.

| Column | Type | Nullable |
|---|---|---|
| `ApplicationId` | uniqueidentifier | no |
| `SlatePersonId` | uniqueidentifier | no |
| `ApplicationStatus` | varchar(20) | no |
| `StudentType` | varchar(20) | no |
| `IsEligible` | bit | no |
| `FunnelTermCode` | varchar(10) | yes |
| `EntryTermCode` | varchar(10) | yes |
| `EntryTermCodeRaw` | varchar(10) | yes |
| `ProgramChoice1Raw` | varchar(20) | yes |
| `J1ProgramCode` | varchar(20) | yes |
| `FirstNameRaw` | nvarchar(100) | yes |
| `FirstNameStd` | nvarchar(100) | yes |
| `LastNameRaw` | nvarchar(100) | yes |
| `LastNameStd` | nvarchar(100) | yes |
| `BirthDate` | date | yes |
| `EmailRaw` | nvarchar(320) | yes |
| `EmailStd` | nvarchar(320) | yes |
| `PhoneRaw` | nvarchar(320) | yes |
| `PhoneStd` | varchar(10) | yes |
| `PostalCode5` | char(5) | yes |
| `ResidencyCode` | varchar(20) | no |
| `SisIdClaim` | int | yes |

### `core.vw_Credential` (view)

Conformed credential awards with the program's CIP code and IPEDS award level. ReportingYear is the July-June year containing the award date (IPEDS Completions period).

| Column | Type | Nullable |
|---|---|---|
| `CredentialAwardedId` | bigint | no |
| `IdNumber` | int | no |
| `ProgramCode` | varchar(20) | no |
| `TermCode` | varchar(10) | no |
| `AwardedDate` | date | no |
| `CipCode` | char(7) | yes |
| `CredentialLevel` | varchar(20) | yes |
| `IpedsAwardLevel` | varchar(3) | yes |
| `RequiredCredits` | decimal(5,1) | yes |
| `ReportingYear` | varchar(25) | no |

### `core.vw_Enrollment` (view)

Conformed course enrollments with census and grade flags (docs/specifications/report-catalog.md R1, R4). A section counts at census when it was registered by the end of the census date and was still REGISTERED then. The source keeps only the latest status change, so a section changed after the census date is treated as REGISTERED at census.

| Column | Type | Nullable |
|---|---|---|
| `EnrollmentId` | bigint | no |
| `IdNumber` | int | no |
| `CourseSectionId` | int | no |
| `TermCode` | varchar(10) | no |
| `SubjectCode` | varchar(6) | no |
| `CourseNumber` | varchar(6) | no |
| `SectionNumber` | varchar(4) | no |
| `CreditHours` | decimal(4,1) | no |
| `RegistrationStatus` | varchar(15) | no |
| `RegisteredAtUtc` | datetime2(3) | no |
| `StatusChangedAtUtc` | datetime2(3) | no |
| `GradeCode` | varchar(2) | yes |
| `GradePoints` | decimal(3,2) | yes |
| `IsAttempted` | bit | yes |
| `IsCountedAtCensus` | bit | yes |
| `IsRegisteredByCensus` | bit | yes |

### `core.vw_Person` (view)

Conformed SIS people with their standardized identity values. Protected: no managed role may read core directly; reporting objects expose only what each report needs.

| Column | Type | Nullable |
|---|---|---|
| `IdNumber` | int | no |
| `FirstNameStd` | nvarchar(100) | yes |
| `LastNameStd` | nvarchar(100) | yes |
| `BirthDate` | date | no |
| `EmailStd` | nvarchar(320) | yes |
| `PhoneStd` | varchar(10) | yes |
| `PostalCode5` | char(5) | yes |
| `HasStudentRecord` | bit | no |

### `core.vw_Program` (view)

Conformed SIS programs with their academic division.

| Column | Type | Nullable |
|---|---|---|
| `ProgramCode` | varchar(20) | no |
| `ProgramName` | nvarchar(150) | no |
| `CredentialLevel` | varchar(20) | no |
| `CipCode` | char(7) | no |
| `RequiredCredits` | decimal(5,1) | no |
| `IpedsAwardLevel` | varchar(3) | no |
| `DivisionCode` | varchar(30) | no |
| `DivisionName` | nvarchar(100) | no |
| `IsActive` | bit | no |

### `core.vw_Student` (view)

Conformed SIS students: one active program per student (simulator simplification).

| Column | Type | Nullable |
|---|---|---|
| `IdNumber` | int | no |
| `ProgramCode` | varchar(20) | yes |
| `EntryTermCode` | varchar(10) | yes |
| `StudentStatus` | varchar(20) | yes |
| `ResidencyCode` | varchar(20) | yes |
| `MatriculationDate` | date | yes |
| `BirthDate` | date | no |

### `core.vw_StudentTermCensus` (view)

One row per person and term with any enrollment: the census population before rule-version thresholds are applied (docs/specifications/report-catalog.md R1). compliance.usp_CaptureCensusSnapshot applies the current rule version and freezes the result. EntryStatus is ENTERING when the entry term is this term, or this is a fall term and the entry term is the summer of the same calendar year; IPEDS counts prior-summer starters as first-time in fall. AgeAtCensus is whole years on the census date.

| Column | Type | Nullable |
|---|---|---|
| `IdNumber` | int | no |
| `TermCode` | varchar(10) | no |
| `TermType` | varchar(10) | no |
| `CensusDate` | date | no |
| `HasStudentRecord` | bit | yes |
| `ProgramCode` | varchar(20) | yes |
| `EntryTermCode` | varchar(10) | yes |
| `StudentStatus` | varchar(20) | yes |
| `ResidencyCode` | varchar(20) | yes |
| `CensusCredits` | decimal(5,1) | yes |
| `CountedSections` | int | yes |
| `SectionsRegisteredByCensus` | int | yes |
| `EntryStatus` | varchar(10) | yes |
| `AgeAtCensus` | int | yes |

### `core.vw_Term` (view)

Conformed academic terms. AcademicYearStartDate is 1 July of the academic year's first calendar year, which is also the start of the IPEDS July-June reporting period.

| Column | Type | Nullable |
|---|---|---|
| `TermCode` | varchar(10) | no |
| `TermName` | nvarchar(50) | no |
| `TermType` | varchar(10) | no |
| `AcademicYear` | char(9) | no |
| `StartDate` | date | no |
| `CensusDate` | date | no |
| `EndDate` | date | no |
| `IsOpenForAdmission` | bit | no |
| `AcademicYearStartDate` | date | yes |

## integration

Matching, exceptions, the outbound queue and reconciliation.

### `integration.ExceptionAction` (table)

Append-only history of exception status changes. The composite foreign key to reference.ExceptionStatusTransition means a disallowed transition cannot be recorded; the creating action (no previous status) must open the exception.

| Column | Type | Nullable |
|---|---|---|
| `ExceptionActionId` | bigint | no |
| `ExceptionId` | bigint | no |
| `FromStatusCode` | varchar(30) | yes |
| `ToStatusCode` | varchar(30) | no |
| `BatchId` | bigint | yes |
| `ActionBy` | nvarchar(128) | no |
| `ActionAtUtc` | datetime2(3) | no |
| `ReasonText` | nvarchar(400) | no |
| `Note` | nvarchar(1000) | yes |
| `RecordedBy` | nvarchar(128) | no |

### `integration.IntegrationException` (table)

Managed exceptions for the applicant workflow (docs/specifications/integration-controls.md). An exception is about an application (ApplicationId) or a whole batch (SubjectBatchId). One active exception per subject and reason is enforced by the filtered unique index; a repeat updates LastSeenBatchId and OccurrenceCount. SourceHash is the staged application version when the exception was last seen: a CLOSED exception keeps holding its condition back only while the application is unchanged, so an analyst's closure is not re-raised every night.

| Column | Type | Nullable |
|---|---|---|
| `ExceptionId` | bigint | no |
| `ExceptionReasonCode` | varchar(40) | no |
| `SourceSystemCode` | varchar(20) | no |
| `ApplicationId` | uniqueidentifier | yes |
| `SubjectBatchId` | bigint | yes |
| `ExceptionStatusCode` | varchar(30) | no |
| `Severity` | varchar(10) | no |
| `AssignedTo` | nvarchar(128) | yes |
| `DetailCode` | varchar(200) | yes |
| `SourceHash` | binary(32) | yes |
| `FirstSeenBatchId` | bigint | no |
| `LastSeenBatchId` | bigint | no |
| `OccurrenceCount` | int | no |
| `CreatedAtUtc` | datetime2(3) | no |
| `UpdatedAtUtc` | datetime2(3) | no |
| `RowVersion` | timestamp | no |

### `integration.MatchCandidate` (table)

Every J1-Sim person a rule found for an evaluation. Evidence is stored as flags, never as copies of names, birth dates or contact values.

| Column | Type | Nullable |
|---|---|---|
| `MatchEvaluationId` | bigint | no |
| `RuleCode` | varchar(20) | no |
| `CandidateIdNumber` | int | no |
| `IsStagedPerson` | bit | no |
| `MatchedOnSisId` | bit | no |
| `MatchedOnEmail` | bit | no |
| `MatchedOnBirthDate` | bit | no |
| `MatchedOnName` | bit | no |
| `MatchedOnPostalCode` | bit | no |
| `CreatedAtUtc` | datetime2(3) | no |

### `integration.MatchDecision` (table)

Identity decisions for eligible applications (docs/specifications/matching-rules.md). Rows are never updated except to mark them superseded; exactly one is current per application. The CHECK constraints are the safety net for ADR-001: whatever the procedures do, an automatic match must be unique and come from an automatic rule, and a blocked decision can never carry a matched ID number.

| Column | Type | Nullable |
|---|---|---|
| `MatchDecisionId` | bigint | no |
| `ApplicationId` | uniqueidentifier | no |
| `MatchEvaluationId` | bigint | yes |
| `BatchId` | bigint | yes |
| `SourceHash` | binary(32) | no |
| `DecisionTypeCode` | varchar(20) | no |
| `RuleCode` | varchar(20) | yes |
| `CandidateCount` | int | no |
| `MatchedIdNumber` | int | yes |
| `ConfidenceCategory` | varchar(10) | no |
| `ConflictCode` | varchar(40) | yes |
| `DecidedBy` | nvarchar(128) | no |
| `DecidedAtUtc` | datetime2(3) | no |
| `Note` | nvarchar(1000) | yes |
| `IsCurrent` | bit | no |
| `SupersededAtUtc` | datetime2(3) | yes |
| `RecordedBy` | nvarchar(128) | no |

### `integration.MatchEvaluation` (table)

One row per application evaluated by the match rules in a batch. Candidates and the resulting decision hang off it, so every decision traces back to the run and the staged source version (SourceHash) it was made from.

| Column | Type | Nullable |
|---|---|---|
| `MatchEvaluationId` | bigint | no |
| `BatchId` | bigint | no |
| `ApplicationId` | uniqueidentifier | no |
| `SourceHash` | binary(32) | no |
| `EvaluatedAtUtc` | datetime2(3) | no |

### `integration.OutboundStudentQueue` (table)

Controlled writes from CampusDataOps to the J1-Sim import interface (docs/specifications/integration-controls.md). IdempotencyKey is SHA-256 of source system, application, action and target ID number; J1-Sim records the same key in its receipt, so a replay can never create a second person. At most one live (non-cancelled) row exists per application. ReconciledBatchId marks the run whose reconciliation counted the success.

| Column | Type | Nullable |
|---|---|---|
| `QueueId` | bigint | no |
| `IdempotencyKey` | binary(32) | no |
| `ApplicationId` | uniqueidentifier | no |
| `SlatePersonId` | uniqueidentifier | no |
| `ActionCode` | varchar(30) | no |
| `TargetIdNumber` | int | yes |
| `MatchDecisionId` | bigint | no |
| `FirstName` | nvarchar(100) | no |
| `MiddleName` | nvarchar(100) | yes |
| `LastName` | nvarchar(100) | no |
| `BirthDate` | date | no |
| `Email` | nvarchar(320) | yes |
| `Phone` | varchar(10) | yes |
| `AddressLine1` | nvarchar(200) | yes |
| `City` | nvarchar(100) | yes |
| `StateCode` | char(2) | yes |
| `PostalCode` | varchar(10) | yes |
| `J1ProgramCode` | varchar(20) | no |
| `EntryTermCode` | varchar(10) | no |
| `ResidencyCode` | varchar(20) | no |
| `QueueStatusCode` | varchar(20) | no |
| `AttemptCount` | smallint | no |
| `MaxAttempts` | smallint | no |
| `RetryGeneration` | smallint | no |
| `LastAttemptAtUtc` | datetime2(3) | yes |
| `LastErrorLogId` | bigint | yes |
| `ResultIdNumber` | int | yes |
| `CompletedAtUtc` | datetime2(3) | yes |
| `QueuedBatchId` | bigint | no |
| `ProcessedBatchId` | bigint | yes |
| `ReconciledBatchId` | bigint | yes |
| `CreatedAtUtc` | datetime2(3) | no |
| `UpdatedAtUtc` | datetime2(3) | no |

### `integration.ReconciliationDetail` (table)

Record-level reconciliation: exactly one outcome per eligible application per run. The primary key makes outcomes mutually exclusive (docs/specifications/integration-controls.md).

| Column | Type | Nullable |
|---|---|---|
| `BatchId` | bigint | no |
| `ApplicationId` | uniqueidentifier | no |
| `OutcomeCode` | varchar(20) | no |
| `ExceptionReasonCode` | varchar(40) | yes |
| `QueueId` | bigint | yes |
| `TargetIdNumber` | int | yes |
| `IsTargetConfirmed` | bit | yes |
| `CreatedAtUtc` | datetime2(3) | no |

### `integration.ReconciliationEntityCount` (table)

Entity-level reconciliation: for each staged entity, the distinct source keys landed by successful batches against the keys present in staging.

| Column | Type | Nullable |
|---|---|---|
| `BatchId` | bigint | no |
| `EntityCode` | varchar(30) | no |
| `LandedKeyCount` | int | no |
| `StagedKeyCount` | int | no |
| `IsBalanced` | bit | yes |
| `CreatedAtUtc` | datetime2(3) | no |

### `integration.ReconciliationResult` (table)

Batch-level reconciliation, one row per pipeline run. The CHECK constraint is the invariant from the blueprint: the mutually exclusive outcome counts must add up to the eligible count, so an unbalanced summary cannot be stored. A run is balanced when every processed application is confirmed in J1-Sim and every entity count agrees.

| Column | Type | Nullable |
|---|---|---|
| `BatchId` | bigint | no |
| `SourceEligible` | int | no |
| `Unchanged` | int | no |
| `Matched` | int | no |
| `Created` | int | no |
| `Rejected` | int | no |
| `Pending` | int | no |
| `Processed` | int | yes |
| `TargetConfirmed` | int | no |
| `EntityMismatchCount` | int | no |
| `IsBalanced` | bit | yes |
| `CreatedAtUtc` | datetime2(3) | no |

### `integration.SourceCrosswalk` (table)

Confirmed links between a source-system person and a J1-Sim ID number. A row is written only in the same transaction as a successful J1-Sim write, so it always describes a link the target accepted. Both directions are unique per source system: one Slate-Sim person maps to one J1-Sim person and vice versa, so a second claim surfaces as an identity issue.

| Column | Type | Nullable |
|---|---|---|
| `SourceCrosswalkId` | bigint | no |
| `SourceSystemCode` | varchar(20) | no |
| `SourceRecordId` | varchar(64) | no |
| `TargetIdNumber` | int | no |
| `CreatedByQueueId` | bigint | no |
| `CreatedBatchId` | bigint | no |
| `CreatedAtUtc` | datetime2(3) | no |

### `integration.vw_ApplicationBlock` (view)

The single definition of "this application is blocked", used by matching, queueing and reconciliation so they cannot disagree. A blocking exception blocks while it is OPEN, ASSIGNED or AWAITING_SOURCE_CORRECTION; RESOLVED and RETRY_READY no longer block. A CLOSED blocking exception keeps blocking while the application's staged version is the one the analyst closed it for (system closures clear SourceHash, so they never block).

| Column | Type | Nullable |
|---|---|---|
| `ApplicationId` | uniqueidentifier | yes |
| `ExceptionId` | bigint | no |
| `ExceptionReasonCode` | varchar(40) | no |
| `ReasonCategory` | varchar(20) | no |
| `Severity` | varchar(10) | no |
| `ExceptionStatusCode` | varchar(30) | no |

### `integration.vw_IntegratedApplication` (view)

Applications already written to J1-Sim. They are never matched or queued again.

| Column | Type | Nullable |
|---|---|---|
| `ApplicationId` | uniqueidentifier | no |
| `QueueId` | bigint | no |
| `ActionCode` | varchar(30) | no |
| `ResultIdNumber` | int | yes |
| `ProcessedBatchId` | bigint | yes |
| `ReconciledBatchId` | bigint | yes |

### `integration.vw_J1TargetStudent` (view)

Target-side evidence for reconciliation: what J1-Sim actually holds for each receipt of the import interface. This view is the only read of J1-Sim outside landing, so tests can fake it.

| Column | Type | Nullable |
|---|---|---|
| `IdempotencyKey` | binary(32) | no |
| `IdNumber` | int | no |
| `ActionCode` | varchar(30) | no |
| `SourceApplicationId` | uniqueidentifier | no |
| `PersonExists` | bit | yes |
| `ProgramCode` | varchar(20) | yes |
| `EntryTermCode` | varchar(10) | yes |
| `StudentStatus` | varchar(20) | yes |

### `integration.vw_OpenExceptionWorklist` (view)

Operational worklist of active exceptions. It shows identifiers, codes and ages only; names, birth dates and contact values stay in staging for authorized drill-through (Part 3 adds masked views and role grants).

| Column | Type | Nullable |
|---|---|---|
| `ExceptionId` | bigint | no |
| `ExceptionReasonCode` | varchar(40) | no |
| `ReasonCategory` | varchar(20) | no |
| `Severity` | varchar(10) | no |
| `OwnerDepartment` | nvarchar(100) | no |
| `BlocksProcessing` | bit | no |
| `ExceptionStatusCode` | varchar(30) | no |
| `AssignedTo` | nvarchar(128) | yes |
| `ApplicationId` | uniqueidentifier | yes |
| `SlatePersonId` | uniqueidentifier | yes |
| `SubjectBatchId` | bigint | yes |
| `DetailCode` | varchar(200) | yes |
| `CurrentDecisionType` | varchar(20) | yes |
| `CandidateCount` | int | yes |
| `OccurrenceCount` | int | no |
| `FirstSeenBatchId` | bigint | no |
| `LastSeenBatchId` | bigint | no |
| `CreatedAtUtc` | datetime2(3) | no |
| `RemediationGuidance` | nvarchar(800) | no |
| `AgeDays` | int | yes |

### `integration.vw_UnmatchedApplicants` (view)

Eligible applications not yet written to J1-Sim, with why they are waiting: no decision yet, a blocked identity decision, or a blocking exception.

| Column | Type | Nullable |
|---|---|---|
| `ApplicationId` | uniqueidentifier | no |
| `SlatePersonId` | uniqueidentifier | no |
| `EntryTermCode` | varchar(10) | yes |
| `J1ProgramCode` | varchar(20) | yes |
| `CurrentDecisionType` | varchar(20) | yes |
| `RuleCode` | varchar(20) | yes |
| `CandidateCount` | int | yes |
| `ConflictCode` | varchar(40) | yes |
| `BlockingReasonCount` | int | yes |
| `QueueStatusCode` | varchar(20) | yes |

## dq

Data-quality rules, runs, results and dispositions.

### `dq.IssueDisposition` (table)

An owner's decision about a recurring data-quality failure (docs/specifications/data-quality-rules.md): fix it in the source, accept it as a known exception until a review date, or mark it a false positive. One current disposition per rule and record; earlier ones are kept, superseded. Dispositions annotate findings; they never suppress them from the scorecard.

| Column | Type | Nullable |
|---|---|---|
| `IssueDispositionId` | bigint | no |
| `RuleCode` | varchar(40) | no |
| `RecordKey` | varchar(100) | no |
| `DispositionCode` | varchar(20) | no |
| `Note` | nvarchar(400) | no |
| `ReviewBy` | date | yes |
| `IsCurrent` | bit | no |
| `DecidedBy` | nvarchar(128) | no |
| `DecidedAtUtc` | datetime2(3) | no |
| `SupersededAtUtc` | datetime2(3) | yes |

### `dq.Rule` (table)

Metadata for each data-quality rule (docs/specifications/data-quality-rules.md). The check procedures evaluate a rule only while it is active and effective; CheckProcedure names the procedure that implements it, for traceability.

| Column | Type | Nullable |
|---|---|---|
| `RuleCode` | varchar(40) | no |
| `Description` | nvarchar(400) | no |
| `EntityName` | varchar(40) | no |
| `Severity` | varchar(10) | no |
| `OwnerDepartment` | nvarchar(100) | no |
| `EffectiveFrom` | date | no |
| `IsActive` | bit | no |
| `ExpectedCondition` | nvarchar(400) | no |
| `RemediationGuidance` | nvarchar(800) | no |
| `CheckProcedure` | nvarchar(256) | no |
| `CreatedAtUtc` | datetime2(3) | no |
| `UpdatedAtUtc` | datetime2(3) | no |

### `dq.RuleExecution` (table)

Per-rule totals for one validation run; the scorecard's pass rate comes from here.

| Column | Type | Nullable |
|---|---|---|
| `ValidationRunId` | bigint | no |
| `RuleCode` | varchar(40) | no |
| `RecordsEvaluated` | int | no |
| `RecordsFailed` | int | no |
| `CreatedAtUtc` | datetime2(3) | no |

### `dq.RuleResult` (table)

One row per record that failed a rule in a validation run. RecordKey and DetailCode carry identifiers and codes only, never names, birth dates or contact values.

| Column | Type | Nullable |
|---|---|---|
| `RuleResultId` | bigint | no |
| `ValidationRunId` | bigint | no |
| `RuleCode` | varchar(40) | no |
| `RecordKey` | varchar(100) | no |
| `DetailCode` | varchar(200) | yes |
| `CreatedAtUtc` | datetime2(3) | no |

### `dq.ValidationRun` (table)

One execution of the data-quality suite. A batch has at most one run; the suite returns the existing run instead of duplicating it.

| Column | Type | Nullable |
|---|---|---|
| `ValidationRunId` | bigint | no |
| `BatchId` | bigint | no |
| `StartedAtUtc` | datetime2(3) | no |
| `EndedAtUtc` | datetime2(3) | no |
| `RulesEvaluated` | int | no |
| `FailuresFound` | int | no |
| `CreatedAtUtc` | datetime2(3) | no |

### `dq.vw_CurrentDataQualityIssues` (view)

Failures from the most recent validation run, with rule ownership and remediation, the first run in which the same rule failed for the same record, and the owner's current disposition, if any (Part 3). A disposition annotates a failure; it never hides it.

| Column | Type | Nullable |
|---|---|---|
| `RuleCode` | varchar(40) | no |
| `RuleDescription` | nvarchar(400) | no |
| `EntityName` | varchar(40) | no |
| `Severity` | varchar(10) | no |
| `OwnerDepartment` | nvarchar(100) | no |
| `RecordKey` | varchar(100) | no |
| `DetailCode` | varchar(200) | yes |
| `ValidationRunId` | bigint | no |
| `BatchId` | bigint | no |
| `FirstValidationRunId` | bigint | yes |
| `RemediationGuidance` | nvarchar(800) | no |
| `DispositionCode` | varchar(20) | yes |
| `DispositionReviewBy` | date | yes |

### `dq.vw_DataQualityScorecard` (view)

Pass rate per rule for the most recent validation run.

| Column | Type | Nullable |
|---|---|---|
| `ValidationRunId` | bigint | no |
| `BatchId` | bigint | no |
| `RuleCode` | varchar(40) | no |
| `EntityName` | varchar(40) | no |
| `Severity` | varchar(10) | no |
| `OwnerDepartment` | nvarchar(100) | no |
| `RecordsEvaluated` | int | no |
| `RecordsFailed` | int | no |
| `PassRate` | decimal(9,6) | yes |

## reporting

The six report datasets and their procedures.

### `reporting.fn_StudentAccountAging` (function)

R3 Student account aging as of a date (docs/specifications/report-catalog.md). Grain: one row per student with a transaction posted on or before @AsOfDate. Credits (negative amounts) pay debits oldest effective due date first, then by transaction id (first-in-first-out: the source does not record which charge a payment paid). Each debit's unpaid remainder is aged into reference.AgingBucket by days past due on @AsOfDate. Invariant: CURRENT + D001_030 + D031_060 + D061_090 + D091_PLUS - CreditBalance = NetBalance.

| Column | Type | Nullable |
|---|---|---|
| `IdNumber` | int | no |
| `NetBalance` | decimal(38,2) | yes |
| `TransactionCount` | int | yes |
| `LastPaymentDate` | date | yes |
| `AsOfDate` | date | yes |
| `CurrentAmount` | decimal(38,2) | no |
| `Days001To030` | decimal(38,2) | no |
| `Days031To060` | decimal(38,2) | no |
| `Days061To090` | decimal(38,2) | no |
| `Days091Plus` | decimal(38,2) | no |
| `CreditBalance` | decimal(38,2) | yes |

### `reporting.vw_AcademicProgress` (view)

R4 Academic progress (docs/specifications/report-catalog.md). Grain: one row per student per term with at least one section that was not dropped. Earned: graded D or better (grade points >= 1.00). GPA credits: grades that carry points (W and I do not). Cumulative values run over this and every earlier term by term start date.

| Column | Type | Nullable |
|---|---|---|
| `IdNumber` | int | no |
| `TermCode` | varchar(10) | no |
| `ProgramCode` | varchar(20) | yes |
| `TermGpa` | decimal(3,2) | yes |
| `CumulativeGpa` | decimal(3,2) | yes |
| `RequiredCredits` | decimal(5,1) | yes |
| `AttemptedCredits` | decimal(5,1) | yes |
| `EarnedCredits` | decimal(5,1) | yes |
| `GpaCredits` | decimal(5,1) | yes |
| `QualityPoints` | decimal(7,2) | yes |
| `CumulativeAttemptedCredits` | decimal(6,1) | yes |
| `CumulativeEarnedCredits` | decimal(6,1) | yes |
| `CumulativeGpaCredits` | decimal(6,1) | yes |
| `GradesPending` | bit | yes |
| `IsCompletionEligible` | bit | yes |
| `HasCredential` | bit | yes |
| `AcademicStanding` | varchar(20) | yes |

### `reporting.vw_EnrollmentCensus` (view)

R1 Enrollment census extract (docs/specifications/report-catalog.md). Reads only immutable snapshots captured under the current census rule version; never live data (ADR-003). Grain: one row per student per term.

| Column | Type | Nullable |
|---|---|---|
| `CensusSnapshotId` | int | no |
| `TermCode` | varchar(10) | no |
| `CensusDate` | date | no |
| `RuleVersion` | varchar(20) | no |
| `IdNumber` | int | no |
| `ProgramCode` | varchar(20) | yes |
| `ProgramName` | nvarchar(150) | yes |
| `CredentialLevel` | varchar(20) | yes |
| `EntryTermCode` | varchar(10) | yes |
| `ResidencyCode` | varchar(20) | yes |
| `CensusCredits` | decimal(5,1) | no |
| `CountedSections` | smallint | no |
| `AttendanceIntensity` | varchar(10) | yes |
| `EntryStatus` | varchar(10) | yes |
| `AgeAtCensus` | tinyint | yes |
| `IsCensusIncluded` | bit | no |
| `ExclusionReason` | varchar(30) | yes |

### `reporting.vw_ExceptionWorklist` (view)

R5 Applicant integration exception worklist, masked (docs/specifications/report-catalog.md). Grain: one row per active exception. Applicant identity is reduced to initials, birth year and a masked email; full values are available only through reporting.usp_GetExceptionDetail.

| Column | Type | Nullable |
|---|---|---|
| `ExceptionId` | bigint | no |
| `ExceptionReasonCode` | varchar(40) | no |
| `ReasonCategory` | varchar(20) | no |
| `Severity` | varchar(10) | no |
| `OwnerDepartment` | nvarchar(100) | no |
| `BlocksProcessing` | bit | no |
| `ExceptionStatusCode` | varchar(30) | no |
| `AssignedTo` | nvarchar(128) | yes |
| `ApplicationId` | uniqueidentifier | yes |
| `DetailCode` | varchar(200) | yes |
| `CurrentDecisionType` | varchar(20) | yes |
| `CandidateCount` | int | yes |
| `OccurrenceCount` | int | no |
| `CreatedAtUtc` | datetime2(3) | no |
| `AgeDays` | int | yes |
| `RemediationGuidance` | nvarchar(800) | no |
| `EntryTermCodeRaw` | varchar(10) | yes |
| `ProgramChoice1Raw` | varchar(20) | yes |
| `PermittedNextStatuses` | varchar(max) | yes |
| `ApplicantInitials` | nvarchar(2) | no |
| `BirthYear` | int | yes |
| `MaskedEmail` | nvarchar(324) | yes |

### `reporting.vw_FinancialAidPackaging` (view)

R2 Financial aid packaging report (docs/specifications/report-catalog.md). Grain: one row per student, aid year and fund; term awards within the aid year are summed.

| Column | Type | Nullable |
|---|---|---|
| `IdNumber` | int | no |
| `AidYear` | char(9) | no |
| `FundCode` | varchar(15) | no |
| `FundSource` | varchar(15) | yes |
| `FundType` | varchar(10) | yes |
| `AwardCount` | int | yes |
| `OfferedAmount` | decimal(38,2) | yes |
| `AcceptedAmount` | decimal(38,2) | yes |
| `DisbursedAmount` | decimal(38,2) | yes |
| `CancelledAmount` | decimal(38,2) | yes |
| `DeclinedAmount` | decimal(38,2) | yes |
| `RemainingAmount` | decimal(38,2) | yes |

### `reporting.vw_LeadershipKPI` (view)

R6 Leadership KPI dataset (docs/specifications/report-catalog.md). Grain: one row per term and measure; definitions, owners and lineage are in compliance.MeasureDefinition. Census measures come only from snapshots (DataStatus FINAL, or NO_SNAPSHOT with a NULL value); the rest are computed from current data (DataStatus CURRENT).

| Column | Type | Nullable |
|---|---|---|
| `TermCode` | varchar(10) | no |
| `AcademicYear` | char(9) | no |
| `TermType` | varchar(10) | no |
| `MeasureCode` | varchar(40) | no |
| `MeasureName` | nvarchar(100) | no |
| `Unit` | varchar(10) | no |
| `OwnerDepartmentCode` | varchar(30) | no |
| `MeasureValue` | decimal(18,4) | yes |
| `DataStatus` | varchar(11) | no |

### `reporting.vw_ProgramCensusRoster` (view)

Masked census roster for program coordinators (docs/architecture/security-model.md). Row-level security on compliance.CensusSnapshotEnrollment limits each coordinator to their programs. Grain: one row per student per term, current census rule version only.

| Column | Type | Nullable |
|---|---|---|
| `TermCode` | varchar(10) | no |
| `CensusDate` | date | no |
| `ProgramCode` | varchar(20) | yes |
| `MaskedStudentId` | char(8) | yes |
| `CensusCredits` | decimal(5,1) | no |
| `AttendanceIntensity` | varchar(10) | yes |
| `EntryStatus` | varchar(10) | yes |
| `IsCensusIncluded` | bit | no |

### `reporting.vw_StudentAccountAging` (view)

R3 as of today (UTC). Use reporting.usp_ReportAccountAging for another date.

| Column | Type | Nullable |
|---|---|---|
| `IdNumber` | int | no |
| `AsOfDate` | date | yes |
| `NetBalance` | decimal(38,2) | yes |
| `TransactionCount` | int | yes |
| `LastPaymentDate` | date | yes |
| `CurrentAmount` | decimal(38,2) | no |
| `Days001To030` | decimal(38,2) | no |
| `Days031To060` | decimal(38,2) | no |
| `Days061To090` | decimal(38,2) | no |
| `Days091Plus` | decimal(38,2) | no |
| `CreditBalance` | decimal(38,2) | yes |

## compliance

Census snapshots, measures, extract runs and IPEDS-aligned views.

### `compliance.CensusRuleVersion` (table)

Versioned census rules (ADR-003). Changing a rule means adding a version and capturing a new snapshot beside the old one; exactly one version is current.

| Column | Type | Nullable |
|---|---|---|
| `RuleVersion` | varchar(20) | no |
| `Description` | nvarchar(400) | no |
| `FullTimeMinCredits` | decimal(4,1) | no |
| `EffectiveFrom` | date | no |
| `IsCurrent` | bit | no |
| `CreatedAtUtc` | datetime2(3) | no |
| `UpdatedAtUtc` | datetime2(3) | no |

### `compliance.CensusSnapshot` (table)

One immutable census snapshot per term and rule version (ADR-003). The header records what the snapshot was built from and a checksum of its rows; compliance.usp_VerifyCensusSnapshot recomputes it. The trigger below rejects every update and delete.

| Column | Type | Nullable |
|---|---|---|
| `CensusSnapshotId` | int | no |
| `TermCode` | varchar(10) | no |
| `CensusDate` | date | no |
| `RuleVersion` | varchar(20) | no |
| `SourceBatchId` | bigint | no |
| `SourceWatermarkUtc` | datetime2(3) | yes |
| `CapturedAtUtc` | datetime2(3) | no |
| `CapturedBy` | nvarchar(128) | no |
| `PopulationCount` | int | no |
| `IncludedCount` | int | no |
| `FullTimeCount` | int | no |
| `CreditTotal` | decimal(9,1) | no |
| `RowChecksum` | binary(32) | no |
| `CaptureLagDays` | int | yes |

### `compliance.CensusSnapshotEnrollment` (table)

One row per person and term in a census snapshot (docs/specifications/report-catalog.md R1). Immutable: the trigger rejects every update and delete. Row-level security (security.ProgramScopePolicy) filters it for program coordinators. The inclusion check names IS NOT NULL explicitly: a CHECK passes when its condition is UNKNOWN.

| Column | Type | Nullable |
|---|---|---|
| `CensusSnapshotId` | int | no |
| `IdNumber` | int | no |
| `ProgramCode` | varchar(20) | yes |
| `EntryTermCode` | varchar(10) | yes |
| `StudentStatus` | varchar(20) | yes |
| `ResidencyCode` | varchar(20) | yes |
| `CensusCredits` | decimal(5,1) | no |
| `CountedSections` | smallint | no |
| `AttendanceIntensity` | varchar(10) | yes |
| `EntryStatus` | varchar(10) | yes |
| `AgeAtCensus` | tinyint | yes |
| `IsCensusIncluded` | bit | no |
| `ExclusionReason` | varchar(30) | yes |

### `compliance.ControlThreshold` (table)

Allowed change of a control's value against the latest earlier run of the same extract type. Exceeding it is a WARN, never a FAIL (docs/specifications/extract-controls.md). The values are project assumptions for Institutional Research to tune.

| Column | Type | Nullable |
|---|---|---|
| `ExtractTypeCode` | varchar(30) | no |
| `ControlCode` | varchar(40) | no |
| `MaxChangePct` | decimal(9,2) | no |
| `CreatedAtUtc` | datetime2(3) | no |
| `UpdatedAtUtc` | datetime2(3) | no |

### `compliance.ExtractControlTotal` (table)

Control totals of an extract run (docs/specifications/extract-controls.md). Builders write ExpectedValue (computed independently of the extract rows, or NULL for an information-only control) and ActualValue (computed from the rows); compliance.usp_ValidateExtractControlTotals sets the prior-period comparison and the outcome. Frozen once the run completes.

| Column | Type | Nullable |
|---|---|---|
| `ExtractRunId` | bigint | no |
| `ControlCode` | varchar(40) | no |
| `ControlKind` | varchar(15) | no |
| `ComparisonOperator` | varchar(2) | no |
| `ExpectedValue` | decimal(19,2) | yes |
| `ActualValue` | decimal(19,2) | no |
| `PriorExtractRunId` | bigint | yes |
| `PriorValue` | decimal(19,2) | yes |
| `ChangePct` | decimal(9,2) | yes |
| `ThresholdPct` | decimal(9,2) | yes |
| `OutcomeCode` | varchar(4) | yes |
| `Note` | nvarchar(400) | yes |

### `compliance.ExtractRow` (table)

The exact CSV lines of an extract run; line 1 is the header. Written only while the run is GENERATING; afterwards the trigger rejects every change.

| Column | Type | Nullable |
|---|---|---|
| `ExtractRunId` | bigint | no |
| `LineNumber` | int | no |
| `LineText` | nvarchar(4000) | no |

### `compliance.ExtractRun` (table)

One recorded, checked run of an extract (docs/specifications/extract-controls.md). After a run leaves GENERATING only its approval fields may change (trigger below). The CHECK constraints name every IS NOT NULL explicitly, because a CHECK passes when its condition is UNKNOWN.

| Column | Type | Nullable |
|---|---|---|
| `ExtractRunId` | bigint | no |
| `ExtractTypeCode` | varchar(30) | no |
| `ReportingPeriod` | varchar(20) | no |
| `PeriodStartDate` | date | no |
| `ParametersJson` | nvarchar(1000) | no |
| `SourceBatchId` | bigint | no |
| `CensusSnapshotId` | int | yes |
| `ExtractStatusCode` | varchar(15) | no |
| `ValidationStatusCode` | varchar(15) | yes |
| `ApprovalStatusCode` | varchar(15) | no |
| `LineCount` | int | yes |
| `DataRowCount` | int | yes |
| `ContentSha256` | binary(32) | yes |
| `GeneratorVersion` | varchar(10) | no |
| `RequestedBy` | nvarchar(128) | no |
| `RequestedByLogin` | nvarchar(128) | no |
| `GeneratedAtUtc` | datetime2(3) | no |
| `CompletedAtUtc` | datetime2(3) | yes |
| `ErrorMessage` | nvarchar(2048) | yes |
| `ApprovedBy` | nvarchar(128) | yes |
| `ApprovedAtUtc` | datetime2(3) | yes |
| `ApprovalNote` | nvarchar(400) | yes |

### `compliance.MeasureDefinition` (table)

Registry of governed measures (docs/specifications/report-catalog.md R6): every leadership measure has one definition, owner, grain, inclusion rule, as-of behavior and lineage. IsAssumption marks a definition this project chose and an owner must approve.

| Column | Type | Nullable |
|---|---|---|
| `MeasureCode` | varchar(40) | no |
| `MeasureName` | nvarchar(100) | no |
| `Definition` | nvarchar(600) | no |
| `Unit` | varchar(10) | no |
| `OwnerDepartmentCode` | varchar(30) | no |
| `Grain` | nvarchar(100) | no |
| `InclusionRule` | nvarchar(400) | no |
| `AsOfBehavior` | varchar(15) | no |
| `SourceLineage` | nvarchar(400) | no |
| `IsAssumption` | bit | no |
| `SortOrder` | tinyint | no |
| `CreatedAtUtc` | datetime2(3) | no |
| `UpdatedAtUtc` | datetime2(3) | no |

### `compliance.vw_IPEDS_12MonthEnrollment` (view)

EDUCATIONAL SIMULATION of the IPEDS 12-month Enrollment component; not an IPEDS submission (docs/specifications/ipeds-measure-mapping.md). Unduplicated headcount and attempted credit hours per academic year (1 July to 30 June). Sections: BY_STATUS and TOTAL.

| Column | Type | Nullable |
|---|---|---|
| `ReportingPeriod` | char(9) | no |
| `Section` | varchar(9) | no |
| `AttendanceStatus` | varchar(9) | no |
| `StudentCategory` | varchar(10) | no |
| `Headcount` | int | yes |
| `CreditHours` | decimal(9,1) | yes |

### `compliance.vw_IPEDS_Completions` (view)

EDUCATIONAL SIMULATION of the IPEDS Completions component; not an IPEDS submission (docs/specifications/ipeds-measure-mapping.md). Awards dated 1 July to 30 June by 6-digit CIP code and award level, and unduplicated completers by level and in total.

| Column | Type | Nullable |
|---|---|---|
| `ReportingPeriod` | varchar(25) | no |
| `Section` | varchar(19) | no |
| `CipCode` | varchar(7) | yes |
| `AwardLevel` | varchar(3) | yes |
| `AwardCount` | int | yes |

### `compliance.vw_IPEDS_FallEnrollment` (view)

EDUCATIONAL SIMULATION of the IPEDS Fall Enrollment component; not an IPEDS submission (docs/specifications/ipeds-measure-mapping.md). Aggregates included students of each fall term's census snapshot under the current rule version. Cells with no students are omitted. Sections: PART_A (attendance x category x residency group), PART_B (attendance x age band), TOTAL.

| Column | Type | Nullable |
|---|---|---|
| `ReportingPeriod` | varchar(10) | no |
| `Section` | varchar(6) | no |
| `AttendanceStatus` | varchar(10) | yes |
| `StudentCategory` | varchar(10) | yes |
| `ResidencyGroup` | varchar(13) | no |
| `AgeBand` | varchar(11) | no |
| `Headcount` | int | yes |

### `compliance.vw_IPEDS_StudentFinancialAid` (view)

EDUCATIONAL SIMULATION of the IPEDS Student Financial Aid component; not an IPEDS submission (docs/specifications/ipeds-measure-mapping.md). Group 1: the 12-month population of the aid year. Group 2: full-time ENTERING students included in that year's fall census snapshot. Aid counted: ACCEPTED awards, at their accepted amount.

| Column | Type | Nullable |
|---|---|---|
| `ReportingPeriod` | char(9) | no |
| `StudentGroup` | varchar(7) | no |
| `AidType` | varchar(20) | no |
| `RecipientCount` | int | yes |
| `TotalAmount` | decimal(14,2) | yes |
| `AverageAmount` | decimal(14,0) | yes |

### `compliance.vw_TwelveMonthStudent` (view)

The IPEDS-aligned 12-month population (docs/specifications/ipeds-measure-mapping.md): one row per student and academic year (1 July to 30 June) with at least one REGISTERED or WITHDRAWN section in a term starting in that year. Attendance status and category come from the student's first such term (project assumption); full-time uses the current census rule.

| Column | Type | Nullable |
|---|---|---|
| `IdNumber` | int | no |
| `AcademicYear` | char(9) | no |
| `FirstTermCode` | varchar(10) | no |
| `CreditHours` | decimal(7,1) | yes |
| `AttendanceStatus` | varchar(9) | no |
| `StudentCategory` | varchar(10) | no |

## security

Supporting tables for roles, masking and row-level security.

### `security.ManagedRole` (table)

The roles security.usp_GrantRoleMembership may add members to (docs/architecture/security-model.md). Fixed database roles and role_security_admin are never listed: db_owner manages security admins.

| Column | Type | Nullable |
|---|---|---|
| `RoleName` | nvarchar(128) | no |
| `Purpose` | nvarchar(400) | no |
| `DataClass` | varchar(30) | no |
| `CreatedAtUtc` | datetime2(3) | no |
| `UpdatedAtUtc` | datetime2(3) | no |

### `security.StudentPseudonym` (table)

Random surrogate keys for masked and Power BI outputs (docs/architecture/security-model.md). Keys are assigned in random order by security.usp_AssignStudentPseudonyms, so StudentKey and MaskedStudentId cannot be derived from the SIS ID without reading this table, which no managed role can.

| Column | Type | Nullable |
|---|---|---|
| `IdNumber` | int | no |
| `StudentKey` | int | no |
| `MaskedStudentId` | char(8) | no |
| `AssignedAtUtc` | datetime2(3) | no |

### `security.UserProgramScope` (table)

Programs each program coordinator may see in the census roster (row-level security, docs/architecture/security-model.md). Changed only through security.usp_SetProgramScope.

| Column | Type | Nullable |
|---|---|---|
| `UserName` | nvarchar(128) | no |
| `ProgramCode` | varchar(20) | no |
| `GrantedBy` | nvarchar(128) | no |
| `GrantedAtUtc` | datetime2(3) | no |

### `security.fn_ProgramScopePredicate` (function)

Row-level security predicate for program coordinators (docs/architecture/security-model.md). A row is visible unless the caller is a member of role_program_coordinator without scope for the row's program. Members of any other role are not filtered: their grants decide what they may read.

| Column | Type | Nullable |
|---|---|---|
| `IsVisible` | int | no |

### `security.vw_RolePermissionMatrix` (view)

Deployed permissions of every managed role (role_*), for review and for the permissions test that compares them with the specified matrix (docs/architecture/security-model.md).

| Column | Type | Nullable |
|---|---|---|
| `RoleName` | sysname | no |
| `PermissionState` | nvarchar(60) | yes |
| `PermissionName` | nvarchar(128) | yes |
| `ClassDesc` | nvarchar(60) | yes |
| `SecurableName` | nvarchar(257) | yes |

### `security.vw_StudentMasked` (view)

Masked student dimension for leadership, IR and Power BI (docs/architecture/security-model.md): a random surrogate key and attributes only; no SIS ID, name, birth date or contact value. AgeBand is the student's age band today, in the IPEDS Fall Enrollment bands.

| Column | Type | Nullable |
|---|---|---|
| `StudentKey` | int | no |
| `MaskedStudentId` | char(8) | yes |
| `ProgramCode` | varchar(20) | yes |
| `EntryTermCode` | varchar(10) | yes |
| `StudentStatus` | varchar(20) | yes |
| `ResidencyCode` | varchar(20) | yes |
| `AgeBand` | varchar(11) | no |

## bi

Masked star schema for Power BI.

### `bi.DataAsOf` (view)

One row for the Power BI data-as-of and refresh-status indicators: the last successful nightly run, the source watermarks it reached, the latest census snapshot and validation run, and the time this view was read (the refresh time in import mode).

| Column | Type | Nullable |
|---|---|---|
| `LastSuccessfulRunId` | bigint | yes |
| `LastSuccessfulRunEndedAtUtc` | datetime2(3) | yes |
| `SlateWatermarkUtc` | datetime2(3) | yes |
| `J1WatermarkUtc` | datetime2(3) | yes |
| `DirectoryWatermarkUtc` | datetime2(3) | yes |
| `LatestCensusCaptureUtc` | datetime2(3) | yes |
| `LatestValidationRunId` | bigint | yes |
| `ReadAtUtc` | datetime2(7) | no |

### `bi.DimDataQualityRule` (view)

Power BI data-quality rule dimension.

| Column | Type | Nullable |
|---|---|---|
| `RuleCode` | varchar(40) | no |
| `Description` | nvarchar(400) | no |
| `EntityName` | varchar(40) | no |
| `Severity` | varchar(10) | no |
| `OwnerDepartment` | nvarchar(100) | no |
| `IsActive` | bit | no |

### `bi.DimDate` (view)

Power BI date dimension, 1 July 2024 to 30 June 2028 (the synthetic calendar's academic years). AcademicYear is the July-June year; TermCode is the term whose dates contain the day, if any.

| Column | Type | Nullable |
|---|---|---|
| `Date` | date | yes |
| `TermCode` | varchar(10) | yes |
| `DateKey` | int | yes |
| `CalendarYear` | int | yes |
| `MonthNumber` | int | yes |
| `MonthName` | nvarchar(30) | yes |
| `AcademicYear` | varchar(25) | no |

### `bi.DimDepartment` (view)

Power BI department dimension: the offices that own measures, rules and exceptions.

| Column | Type | Nullable |
|---|---|---|
| `DepartmentCode` | varchar(30) | no |
| `DepartmentName` | nvarchar(100) | no |

### `bi.DimExceptionReason` (view)

Power BI exception reason dimension.

| Column | Type | Nullable |
|---|---|---|
| `ExceptionReasonCode` | varchar(40) | no |
| `Description` | nvarchar(400) | no |
| `Category` | varchar(20) | no |
| `DefaultSeverity` | varchar(10) | no |
| `OwnerDepartment` | nvarchar(100) | no |
| `BlocksProcessing` | bit | no |

### `bi.DimProgram` (view)

Power BI program dimension with academic division (the program's department).

| Column | Type | Nullable |
|---|---|---|
| `ProgramCode` | varchar(20) | no |
| `ProgramName` | nvarchar(150) | no |
| `CredentialLevel` | varchar(20) | no |
| `CipCode` | char(7) | no |
| `RequiredCredits` | decimal(5,1) | no |
| `IpedsAwardLevel` | varchar(3) | no |
| `DivisionCode` | varchar(30) | no |
| `DivisionName` | nvarchar(100) | no |
| `IsActive` | bit | no |

### `bi.DimStudent` (view)

Power BI student dimension: masked (random surrogate key, attributes only).

| Column | Type | Nullable |
|---|---|---|
| `StudentKey` | int | no |
| `MaskedStudentId` | char(8) | yes |
| `ProgramCode` | varchar(20) | yes |
| `EntryTermCode` | varchar(10) | yes |
| `StudentStatus` | varchar(20) | yes |
| `ResidencyCode` | varchar(20) | yes |
| `AgeBand` | varchar(11) | no |

### `bi.DimTerm` (view)

Power BI term dimension, with whether the term has a census snapshot (current rule version).

| Column | Type | Nullable |
|---|---|---|
| `TermCode` | varchar(10) | no |
| `TermName` | nvarchar(50) | no |
| `TermType` | varchar(10) | no |
| `AcademicYear` | char(9) | no |
| `StartDate` | date | no |
| `CensusDate` | date | no |
| `EndDate` | date | no |
| `HasCensusSnapshot` | bit | yes |
| `TermSortKey` | int | yes |

### `bi.FactAccountBalance` (view)

Student account balances and aging buckets as of today. Grain: student.

| Column | Type | Nullable |
|---|---|---|
| `StudentKey` | int | yes |
| `AsOfDate` | date | yes |
| `NetBalance` | decimal(38,2) | yes |
| `CurrentAmount` | decimal(38,2) | no |
| `Days001To030` | decimal(38,2) | no |
| `Days031To060` | decimal(38,2) | no |
| `Days061To090` | decimal(38,2) | no |
| `Days091Plus` | decimal(38,2) | no |
| `CreditBalance` | decimal(38,2) | yes |

### `bi.FactAidAward` (view)

Financial aid award facts. Grain: award (student, term and fund).

| Column | Type | Nullable |
|---|---|---|
| `AwardId` | bigint | no |
| `StudentKey` | int | yes |
| `AidYear` | char(9) | no |
| `TermCode` | varchar(10) | no |
| `FundCode` | varchar(15) | no |
| `FundSource` | varchar(15) | yes |
| `FundType` | varchar(10) | yes |
| `AwardStatus` | varchar(10) | no |
| `OfferedAmount` | decimal(12,2) | no |
| `AcceptedAmount` | decimal(12,2) | no |
| `DisbursedAmount` | decimal(12,2) | no |

### `bi.FactApplicationFunnel` (view)

Applicant funnel counts. Grain: entry term, program, application status and student type (aggregate; no applicant identity).

| Column | Type | Nullable |
|---|---|---|
| `TermCode` | varchar(10) | yes |
| `ProgramCode` | varchar(20) | yes |
| `ApplicationStatus` | varchar(20) | no |
| `StudentType` | varchar(20) | no |
| `ApplicationCount` | int | yes |

### `bi.FactCensusEnrollment` (view)

Census enrollment facts from snapshots (current rule version). Grain: student and term.

| Column | Type | Nullable |
|---|---|---|
| `CensusSnapshotId` | int | no |
| `TermCode` | varchar(10) | no |
| `StudentKey` | int | yes |
| `ProgramCode` | varchar(20) | yes |
| `CensusCredits` | decimal(5,1) | no |
| `AttendanceIntensity` | varchar(10) | yes |
| `EntryStatus` | varchar(10) | yes |
| `ResidencyCode` | varchar(20) | yes |
| `IsCensusIncluded` | bit | no |
| `ExclusionReason` | varchar(30) | yes |

### `bi.FactCourseOutcome` (view)

Course outcome counts. Grain: term, subject and the student's program (aggregate).

| Column | Type | Nullable |
|---|---|---|
| `TermCode` | varchar(10) | no |
| `SubjectCode` | varchar(6) | no |
| `ProgramCode` | varchar(20) | yes |
| `AttemptedSections` | int | yes |
| `GradedSections` | int | yes |
| `SuccessfulSections` | int | yes |
| `AttemptedCredits` | decimal(38,1) | yes |

### `bi.FactDataQualityResult` (view)

Data-quality rule results for every validation run (trend). Grain: validation run and rule.

| Column | Type | Nullable |
|---|---|---|
| `ValidationRunId` | bigint | no |
| `BatchId` | bigint | no |
| `RuleCode` | varchar(40) | no |
| `RecordsEvaluated` | int | no |
| `RecordsFailed` | int | no |
| `RunDate` | date | yes |

### `bi.FactIntegrationException` (view)

Integration exceptions (codes and ages only). Grain: exception.

| Column | Type | Nullable |
|---|---|---|
| `ExceptionId` | bigint | no |
| `ExceptionReasonCode` | varchar(40) | no |
| `ExceptionStatusCode` | varchar(30) | no |
| `Severity` | varchar(10) | no |
| `OccurrenceCount` | int | no |
| `IsActiveState` | bit | no |
| `CreatedDate` | date | yes |
| `AgeDays` | int | yes |

### `bi.FactIntegrationRun` (view)

Nightly integration runs with their reconciliation counts. Grain: run.

| Column | Type | Nullable |
|---|---|---|
| `BatchId` | bigint | no |
| `BatchStatusCode` | varchar(20) | no |
| `StartedAtUtc` | datetime2(3) | no |
| `EndedAtUtc` | datetime2(3) | yes |
| `RecoveryOfBatchId` | bigint | yes |
| `SourceEligible` | int | yes |
| `Created` | int | yes |
| `Matched` | int | yes |
| `Unchanged` | int | yes |
| `Rejected` | int | yes |
| `Pending` | int | yes |
| `IsBalanced` | bit | yes |
| `RunDate` | date | yes |
| `DurationSeconds` | int | yes |

### `bi.FactJobStep` (view)

Pipeline step executions for the Job Health page. Grain: step attempt.

| Column | Type | Nullable |
|---|---|---|
| `BatchStepId` | bigint | no |
| `BatchId` | bigint | no |
| `ProcessName` | varchar(100) | no |
| `StepName` | varchar(100) | no |
| `StepOrder` | smallint | no |
| `AttemptNumber` | smallint | no |
| `BatchStepStatusCode` | varchar(20) | no |
| `StartedAtUtc` | datetime2(3) | no |
| `EndedAtUtc` | datetime2(3) | yes |
| `RowsAffected` | int | yes |
| `DurationSeconds` | int | yes |
