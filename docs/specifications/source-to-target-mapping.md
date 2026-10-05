# Source-to-target mapping

This specification traces every source entity to its CampusDataOps targets. The **Status**
column states what exists today. Mappings marked *Specified* are the agreed design that Part 2
implements; they are written first so the code can be reviewed against them.

## Lineage columns on every landing row

| Column | Meaning | Source |
|---|---|---|
| `BatchId` | Landing batch that received the row | `landing.usp_BeginLandingBatch` output |
| `SourceSystemCode` | `SLATE_SIM`, `J1_SIM` or `DIRECTORY_SIM` | `reference.SourceSystem` |
| `SourceRecordId` | Immutable source key, as text | Source primary key |
| `SourceUpdatedAt` | Source `UpdatedAtUtc`; drives the watermark | Source row |
| `IngestedAt` | Time the platform wrote the row (UTC) | `SYSUTCDATETIME()` |
| `RecordHash` | SHA-256 of the business columns, used to classify rows as new or unchanged | Loader |
| `RequestId` | Loader request or file identifier | Loader |

## Implemented in Part 1

| Source | Target | Rule | Status |
|---|---|---|---|
| Python generator (`campus-ops load-sources`) | All 21 `SourceSystems` tables | Full replacement in one transaction; deterministic for a given seed and scale | Implemented |
| `reference_seed.sql` | `reference.SourceSystem`, `BatchStatus`, `BatchStepStatus`, `AcademicTerm`, `ProgramCrosswalk`, `ExceptionReason` | Insert missing and update changed rows on every publish; never delete | Implemented |
| `J1Sim.AcademicTerm` | `reference.AcademicTerm` | Must be identical; verified by `smoke_test.sql` and `test_reference_alignment.py` | Implemented (verification) |
| `J1Sim.AcademicProgram` | `reference.ProgramCrosswalk.J1ProgramCode` | Every crosswalk row matches an SIS program with the same CIP code and active flag | Implemented (verification) |

## Specified for Part 2: source → landing

Incremental selection for every table: `UpdatedAtUtc > PreviousWatermarkUtc` (or all rows when
the watermark is NULL), and the reached watermark is the maximum `UpdatedAtUtc` read.

| Source tables | Landing target | Grain | `SourceRecordId` |
|---|---|---|---|
| `SlateSim.Person` + primary `Address` + primary `ContactPoint` (EMAIL, PHONE) + `ExternalIdentifier` (SIS_ID) | `landing.SlateApplicantRaw` | One row per applicant person per batch | `PersonId` |
| `SlateSim.Application` + `ApplicationProgram` (ranks 1-3) + `ExportQueue` | `landing.SlateApplicationRaw` | One row per application per batch | `ApplicationId` |
| `J1Sim.Person` + `J1Sim.Student` | `landing.J1PersonRaw` | One row per SIS person per batch | `IdNumber` |
| `J1Sim.Enrollment` + `CourseSection` + `FinalGrade` | `landing.J1EnrollmentRaw` | One row per enrollment per batch | `EnrollmentId` |
| `J1Sim.FinancialAidAward` | `landing.J1FinancialAidRaw` | One row per award per batch | `AwardId` |
| `DirectorySim.DirectoryAccount` + `GroupMembership` | `landing.DirectoryAccountRaw` | One row per account per batch | `AccountGuid` |

## Specified for Part 2: landing → staging → core

| Landing | Staging | Core | Key transformations |
|---|---|---|---|
| `SlateApplicantRaw` | `staging.Applicant` | `core.Applicant`, `core.Person` | Trim and case-normalize names; lower-case and validate email; normalize phone to digits; keep raw values alongside standardized values |
| `SlateApplicationRaw` | `staging.Applicant` (application columns) | `core.Applicant` | Map program through `reference.ProgramCrosswalk`; validate entry term against `reference.AcademicTerm` |
| `J1PersonRaw` | `staging.Person` | `core.Person`, `core.Student` | Same name and email normalization; preserve SIS `IdNumber` |
| `J1EnrollmentRaw` | `staging.Enrollment` | `core.Enrollment`, `core.CourseSection` | Typed credits and statuses |
| `J1FinancialAidRaw` | `staging.FinancialAidAward` | `core.FinancialAidAward` | Amount invariants re-checked as data-quality rules |
| `DirectoryAccountRaw` | `staging.DirectoryAccount` | (identity checks only) | Parse `EmployeeId` to `IdNumber` where numeric |

Matching from `staging.Applicant` to `core.Person` follows the ordered rules in
[BLUEPRINT.md](../../BLUEPRINT.md#matching-hierarchy). Its specification will be written up in
`matching-rules.md` before Part 2 implementation starts.

## Edge cases and expected handling

| Edge case | Source evidence | Expected Part 2 outcome |
|---|---|---|
| `DUPLICATE_SIS_PERSON` | J1 9000001 and 9000002 share name, birth date and address | `DUPLICATE_SIS_PERSON` data-quality finding for the Registrar |
| `AMBIGUOUS_MATCH` | Applicant email + birth date match J1 9000011 and 9000012 | `AMBIGUOUS_MATCH` exception; never auto-merged |
| `MISSING_PROGRAM` | Admitted application with no `ApplicationProgram` row | `MISSING_REQUIRED_FIELD` exception |
| `INVALID_TERM` | Entry term `2031FA` absent from `reference.AcademicTerm` | `INVALID_ENTRY_TERM` exception |
| `MALFORMED_EMAIL` | `casey.rivera@@example.com` | `INVALID_CONTACT_FORMAT`, non-blocking |
| `ORPHAN_DIRECTORY_ACCOUNT` | Student account with `EmployeeId` 9000099 and no SIS person | `ORPHAN_DIRECTORY_ACCOUNT` finding for IT Identity Services |
