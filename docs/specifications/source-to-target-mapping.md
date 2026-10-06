# Source-to-target mapping

This specification traces every source entity to its CampusDataOps targets. The **Status**
column states what exists today.

## Lineage columns on every landing row

| Column | Meaning | Source |
|---|---|---|
| `BatchId` | Landing batch that received the row | `landing.usp_BeginLandingBatch` output |
| `SourceSystemCode` | `SLATE_SIM`, `J1_SIM` or `DIRECTORY_SIM` | `reference.SourceSystem` |
| `SourceRecordId` | Immutable source key, as text (persisted computed column) | Source primary key |
| `SourceUpdatedAtUtc` | Latest `UpdatedAtUtc` across the source rows combined into this row; drives the watermark | Source rows |
| `IngestedAtUtc` | Time the platform wrote the row (UTC) | `SYSUTCDATETIME()` |
| `RecordHash` | SHA-256 of the business columns, compared with the latest landed version of the key | Loader |
| `RequestId` | The extract view the row was read through, for example `landing.vw_SourceSlateApplicant` | Loader |

## Implemented in Part 1

| Source | Target | Rule | Status |
|---|---|---|---|
| Python generator (`campus-ops load-sources`) | All 21 `SourceSystems` tables | Full replacement in one transaction; deterministic for a given seed and scale | Implemented |
| `reference_seed.sql` | `reference.SourceSystem`, `BatchStatus`, `BatchStepStatus`, `AcademicTerm`, `ProgramCrosswalk`, `ExceptionReason` | Insert missing and update changed rows on every publish; never delete | Implemented |
| `J1Sim.AcademicTerm` | `reference.AcademicTerm` | Must be identical; verified by `smoke_test.sql` and `test_reference_alignment.py` | Implemented (verification) |
| `J1Sim.AcademicProgram` | `reference.ProgramCrosswalk.J1ProgramCode` | Every crosswalk row matches an SIS program with the same CIP code and active flag | Implemented (verification) |

## Implemented in Part 2: source → landing

Each source system is landed as one atomic batch by `landing.usp_RunLandingLoad`. Rows are read
through `landing.vw_Source*` views (the only objects that reference the SourceSystems database)
when their source `UpdatedAtUtc` is **at or after** the previous watermark, and are inserted only
when their SHA-256 `RecordHash` (over the row's `FOR JSON` serialization, NULLs included) differs
from the latest landed version of the same key. The reached watermark is the latest
`UpdatedAtUtc` read. See [ADR-002](../decisions/ADR-002-append-only-landing.md).

| Source tables | Landing target | Grain | Key | Status |
|---|---|---|---|---|
| `SlateSim.Person` + primary `Address` + primary EMAIL and PHONE `ContactPoint` + `SIS_ID` `ExternalIdentifier` | `landing.SlateApplicantRaw` | Applicant person version | `PersonId` | Implemented |
| `SlateSim.Application` + `ApplicationProgram` (ranks 1-3) + `ADMITTED_APPLICANT` `ExportQueue` | `landing.SlateApplicationRaw` | Application version | `ApplicationId` | Implemented |
| `J1Sim.Person` + `J1Sim.Student` | `landing.J1PersonRaw` | SIS person version | `IdNumber` | Implemented |
| `J1Sim.Enrollment` + `CourseSection` + `FinalGrade` | `landing.J1EnrollmentRaw` | Enrollment version | `EnrollmentId` | Implemented |
| `J1Sim.FinancialAidAward` | `landing.J1FinancialAidRaw` | Award version | `AwardId` | Implemented |
| `J1Sim.StudentAccountTransaction` | `landing.J1AccountTransactionRaw` | Transaction version | `TransactionId` | Implemented (added in Part 2) |
| `J1Sim.StudentAccountTransaction`, aggregated | `landing.J1AccountControlTotal` | Source count and sum per student-term with a changed transaction | `IdNumber`, `TermCode` | Implemented (added in Part 2) |
| `DirectorySim.DirectoryAccount` + `GroupMembership` (sorted list) | `landing.DirectoryAccountRaw` | Account version | `AccountGuid` | Implemented |

Landing accepts every row as received; validation happens in staging, so landing batches always
report zero rejected rows.

## Implemented in Part 2: landing → staging

Staging holds the current standardized version of each key, raw values beside standardized
values. Normalization rules are in [matching-rules.md](matching-rules.md).

| Landing | Staging | Key transformations | Status |
|---|---|---|---|
| `SlateApplicantRaw` + `SlateApplicationRaw` (latest of each) | `staging.Applicant` (one row per application) | Names trimmed, collapsed and upper-cased; email lower-cased and validated (`EmailStd` is NULL when invalid); phone to 10 digits; postal code to 5 digits; SIS ID claim to an integer when 7 digits; entry term validated against `reference.AcademicTerm` (`TermValidationCode`); first program choice mapped through `reference.ProgramCrosswalk` (`ProgramValidationCode`); missing required fields listed; duplicate eligible applications counted; residency derived from the address; eligibility = `ADMITTED`/`DEPOSITED` and exported; `SourceHash` over the two landed hashes | Implemented |
| `J1PersonRaw` | `staging.Person` | Same name, email, phone and postal normalization; student fields carried with `HasStudentRecord` | Implemented |
| `DirectoryAccountRaw` | `staging.DirectoryAccount` | `EmployeeIdNumber` parsed when `EmployeeId` is 7 digits | Implemented |
| `J1EnrollmentRaw`, `J1FinancialAidRaw`, `J1AccountTransactionRaw` | `staging.Enrollment`, `staging.FinancialAidAward`, `staging.AccountTransaction` | Typed copies; integrity checked by data-quality rules, not corrected | Implemented |

**Deviation:** the conformed `core` layer is deferred to Part 3, where reports first need it.
Matching compares `staging.Applicant` with `staging.Person`, the current standardized J1-Sim
state.

## Implemented in Part 2: staging → integration → J1-Sim

| From | To | Rule | Status |
|---|---|---|---|
| `staging.Applicant` (eligible, unblocked) + `staging.Person` + `integration.SourceCrosswalk` | `integration.MatchEvaluation`, `MatchCandidate`, `MatchDecision` | Ordered deterministic rules and decision table in [matching-rules.md](matching-rules.md) | Implemented |
| `staging.Applicant` validation codes, `MatchDecision` | `integration.IntegrationException`, `ExceptionAction` | Lifecycle in [integration-controls.md](integration-controls.md) | Implemented |
| Ready applications (`MatchDecision` allows processing, not blocked) | `integration.OutboundStudentQueue` | Payload = standardized staging values; action `CREATE_PERSON_STUDENT`, `CREATE_STUDENT` or `READMIT_STUDENT`; SHA-256 idempotency key | Implemented |
| `OutboundStudentQueue` | `J1Sim.Person`, `J1Sim.Student`, `J1Sim.IntegrationReceipt` via `J1Sim.usp_ReceiveAdmittedApplicant` | Phone sent as `NNN-NNN-NNNN`; invalid email sent as NULL; new ID numbers from 8000000; receipt keyed by the idempotency key | Implemented |
| Successful write | `integration.SourceCrosswalk` | `SLATE_SIM` + Slate-Sim `PersonId` → J1-Sim `IdNumber`, in the write's transaction | Implemented |
| Eligible applications, queue, `vw_J1TargetStudent` | `integration.ReconciliationDetail`, `ReconciliationResult`, `ReconciliationEntityCount` | One outcome per application; outcomes add up to eligible; processed rows confirmed in J1-Sim | Implemented |
| Staging and integration tables | `dq.ValidationRun`, `RuleExecution`, `RuleResult` | Sixteen rules in [data-quality-rules.md](data-quality-rules.md) | Implemented |

## Edge cases and observed handling

Observed on the default seed (20260901, scale 1.0) by `tests/python/test_pipeline_db.py`.

| Edge case | Source evidence | Part 2 outcome |
|---|---|---|
| `DUPLICATE_SIS_PERSON` | J1 9000001 and 9000002 share name, birth date and address | `SIS_DUPLICATE_PERSON` data-quality failures for both, detail `GROUP:9000001` |
| `AMBIGUOUS_MATCH` | Applicant email + birth date match J1 9000011 and 9000012 | `AMBIGUOUS` decision, `AMBIGUOUS_MATCH` exception, nothing queued; resolving it with `usp_ResolveExceptionMatch` leads to `CREATE_STUDENT` for the chosen person on the next run |
| `MISSING_PROGRAM` | Admitted application with no `ApplicationProgram` row | `MISSING_REQUIRED_FIELD` exception, detail `PROGRAM`; reconciliation `REJECTED`. Adding the program in Slate-Sim auto-resolves it and the next run writes the student |
| `INVALID_TERM` | Entry term `2031FA` absent from `reference.AcademicTerm` | `INVALID_ENTRY_TERM` exception, detail `UNKNOWN_TERM`; `REJECTED` |
| `MALFORMED_EMAIL` | `casey.rivera@@example.com` | `INVALID_CONTACT_FORMAT` exception (non-blocking); the applicant is written to J1-Sim without an email |
| `ORPHAN_DIRECTORY_ACCOUNT` | Student account with `EmployeeId` 9000099 and no SIS person | `DIR_ORPHAN_ACCOUNT` data-quality failure, detail `NOT_A_J1_PERSON` |

## Known limitations

- Deletions in a source are not detected by watermark loads, except account transactions, whose
  control totals reveal a deletion when the same student-term changes again.
- Once an application is written to J1-Sim, later Slate-Sim changes to it are not propagated.
- One landing watermark per source covers several tables, which assumes source timestamps are
  commit-ordered; the simulator guarantees this.
