# Report catalog

**Owner:** Institutional Research (catalog), with each report owned by the department named below
**Implements:** `reporting` views, table-valued functions and `usp_Report*` procedures; the
recurring deliveries run through extract runs ([extract-controls.md](extract-controls.md))

Each report below was specified before its SQL was written. Entries marked **Assumption** are
business definitions this project had to choose. A real Registrar, Financial Aid office, Bursar
or Institutional Research office would have to approve them before relying on the numbers.

Rules shared by every report:

- Reports read only `core` views, `compliance` snapshot tables and `reference` tables. They never
  read `landing`, `staging` directly or the source databases, and department roles cannot read
  those schemas ([security-model.md](../architecture/security-model.md)).
- Every amount is in US dollars. Every count is a count of distinct students unless stated.
- "Today" means the server's UTC date. The synthetic data was generated as of 2026-09-01
  (`AS_OF` in the business glossary), so reports run later still describe the data at that date.
- Student-level reports carry the SIS `IdNumber` and are classified **Confidential: student
  record** (FERPA-informed). Aggregate outputs are **Internal: aggregate**. Neither class may be
  copied to `sample-output/` except aggregate extracts with small-cell suppression
  ([extract-controls.md](extract-controls.md#public-copies)).

## R1. Enrollment census extract

| Field | Specification |
|---|---|
| Owner and audience | Registrar (owner); Enrollment Management and Institutional Research |
| Purpose | The official term headcount and credit load, fixed at census, used for state and federal reporting and for leadership counts |
| Objects | `reporting.vw_EnrollmentCensus`; `reporting.usp_ReportEnrollmentByTerm @TermCode, @IncludeExcluded = 0`; extract type `ENROLLMENT_CENSUS` |
| Grain | One row per student per term. Each J1-Sim student has one active program (a simulator simplification), so this is also student-term-program |
| Population | Every student with at least one enrollment row in the term |
| Included at census | Students with more than 0 credits enrolled at census (below) |
| Excluded, kept with a reason | `DROPPED_BEFORE_CENSUS`: every section was dropped or withdrawn on or before the census date. `REGISTERED_AFTER_CENSUS`: every counted section was added after the census date. `NO_STUDENT_RECORD`: the person has enrollments but no student record (also a data-quality failure) |
| Section counted at census | Registered on or before the end of the census date, and either still `REGISTERED` or changed to `DROPPED`/`WITHDRAWN` after the census date. **Assumption:** the source keeps only the current status and the time it last changed, so a section whose status changed after census is treated as `REGISTERED` at census |
| Measures | `CensusCredits`: sum of credit hours of counted sections. `AttendanceIntensity`: `FULL_TIME` at 12.0 or more credits, else `PART_TIME`; the threshold is stored with the rule version (12 credits is the IPEDS undergraduate full-time definition; applying it to summer terms is an **Assumption**). `EntryStatus`: `ENTERING` if the student's entry term is this term, or this is a fall term and the entry term is the summer immediately before it; else `CONTINUING`. `AgeAtCensus`: whole years on the census date. `ResidencyCode` as recorded |
| As-of behavior | Read only from an immutable census snapshot ([ADR-003](../decisions/ADR-003-census-snapshots.md)). If the term has no snapshot for the current rule version, the procedure raises an error rather than falling back to live data |
| Lineage | `J1Sim.Enrollment`, `CourseSection`, `Student`, `Person` → `landing.J1EnrollmentRaw`, `J1PersonRaw` → `staging.Enrollment`, `staging.Person` → `core.vw_StudentTermEnrollmentAtCensus` → `compliance.CensusSnapshotEnrollment` → report |
| Security class | Confidential: student record. Roles: `role_enrollment_reporter`, `role_ir_analyst` (masked star schema only) |
| Schedule and delivery | Captured by the Agent census job once the census date has passed; CSV extract with manifest |
| Controls | Included rows = snapshot `IncludedCount`. Sum of `CensusCredits` = snapshot `CreditTotal`. Full-time + part-time = included. The snapshot checksum still verifies |
| Known limitations | No intra-day status history (above). Transfer-in students cannot be told apart from first-time students in J1-Sim, so `ENTERING` covers both |

## R2. Financial aid packaging report

| Field | Specification |
|---|---|
| Owner and audience | Financial Aid (owner); Student Accounts; Institutional Research |
| Purpose | Shows what was offered, accepted, paid and cancelled per fund, so packaging and disbursement can be reconciled before term close |
| Objects | `reporting.vw_FinancialAidPackaging`; `reporting.usp_ReportAidByAcademicYear @AidYear`; extract type `AID_PACKAGING` |
| Grain | One row per student, aid year and fund (terms within the aid year are summed) |
| Population | Every staged award, in every status |
| Measures | `OfferedAmount`: sum of offered amounts in every status. `AcceptedAmount`: sum of accepted amounts (only `ACCEPTED` awards carry one). `DisbursedAmount`: sum of disbursed amounts. `CancelledAmount`: offered amount of `CANCELLED` awards. `DeclinedAmount`: offered amount of `DECLINED` awards. `RemainingAmount`: accepted minus disbursed (accepted aid not yet paid). `AwardCount`: number of term awards summed into the row. `FundSource` and `FundType` come from `reference.AidFund` |
| As-of behavior | Current state after the last successful nightly run. Not snapshot-based. Each extract run records the source batch it read |
| Lineage | `J1Sim.FinancialAidAward` → `landing.J1FinancialAidRaw` → `staging.FinancialAidAward` → `core.vw_AidAward` → report |
| Security class | Confidential: student financial record (GLBA-informed). Role: `role_financial_aid_reporter` |
| Schedule and delivery | Daily operational extract for the current aid year |
| Controls | The sums of offered, accepted and disbursed equal the same sums over `core.vw_AidAward` for the aid year. `RemainingAmount` is never negative. Prior-run change thresholds per [extract-controls.md](extract-controls.md) |
| Known limitations | No disbursement dates or transaction-level aid history in the source, so "remaining" is not split into scheduled and overdue |

## R3. Student account aging report

| Field | Specification |
|---|---|
| Owner and audience | Student Accounts (owner); Financial Aid; leadership in aggregate only |
| Purpose | Shows how much each student owes and how long it has been due, for collections and for holds |
| Objects | `reporting.fn_StudentAccountAging(@AsOfDate)`; `reporting.vw_StudentAccountAging` (as of today); `reporting.usp_ReportAccountAging @AsOfDate = today`; extract type `ACCOUNT_AGING` |
| Grain | One row per student with at least one transaction posted on or before the as-of date |
| Measures | `NetBalance`: sum of every amount posted on or before the as-of date (charges and refunds positive, payments and aid credits negative; adjustments either sign). **Debits** are positive amounts; their due date is `DueDate`, or `PostedDate` when the source has none (refunds and adjustments). **Credits** (negative amounts) are applied to debits oldest due date first, then by transaction id. **Assumption:** first-in-first-out application, because the source does not record which charge a payment paid. Each debit's unpaid remainder is aged by days past due on the as-of date into the governed buckets in `reference.AgingBucket`: `CURRENT` (not yet due, ≤ 0 days), `D001_030`, `D031_060`, `D061_090` and `D091_PLUS`. `CreditBalance`: credits left over after every debit is paid, shown as a positive amount |
| Invariant | `CURRENT + D001_030 + D031_060 + D061_090 + D091_PLUS − CreditBalance = NetBalance` for every row |
| As-of behavior | Parameterized as-of date; transactions posted after it are ignored |
| Lineage | `J1Sim.StudentAccountTransaction` → `landing.J1AccountTransactionRaw` → `staging.AccountTransaction` → `core.vw_AccountTransaction` → report |
| Security class | Confidential: student financial record. Role: `role_student_accounts_reporter` |
| Schedule and delivery | Daily operational extract as of the run date |
| Controls | Sum of `NetBalance` = sum of `core.vw_AccountTransaction` amounts posted on or before the as-of date (detail-to-total). The row invariant holds for every row. Separately, the `ACCT_DETAIL_TO_TOTAL` data-quality rule checks staged detail against source control totals |
| Known limitations | First-in-first-out is a simplification. No payment plans or holds in the source |

## R4. Academic progress report

| Field | Specification |
|---|---|
| Owner and audience | Academic Affairs (owner); Registrar; advising |
| Purpose | Shows attempted and earned credits, grade point averages, academic standing and completion markers, for advising and standing reviews |
| Objects | `reporting.vw_AcademicProgress`; `reporting.usp_ReportAcademicOutcomes @TermCode`; extract type `ACADEMIC_PROGRESS` |
| Grain | One row per student per term in which the student has at least one section that was not dropped |
| Measures | `AttemptedCredits`: credits of `REGISTERED` and `WITHDRAWN` sections. `EarnedCredits`: credits of sections graded D or better (grade points ≥ 1.00). `GpaCredits`: credits of sections whose grade carries grade points (W and I do not). `QualityPoints`: sum of grade points × credits. `TermGpa`: quality points ÷ GPA credits, rounded to 2 decimals; NULL when there are no GPA credits. `Cumulative*`: the same measures over this and every earlier term. `AcademicStanding` from `reference.AcademicStandingRule` on the cumulative GPA: `GOOD_STANDING` at 2.00 or above, `ACADEMIC_PROBATION` below 2.00, `NOT_EVALUATED` without GPA credits (**Assumption**: thresholds and the absence of a minimum-credits rule). `GradesPending`: the term has `REGISTERED` sections without a grade. `RequiredCredits` of the student's program. `IsCompletionEligible`: cumulative earned credits ≥ required credits. `HasCredential`: a credential in the program was awarded in or before this term |
| As-of behavior | Current state after the last successful nightly run. A term in progress shows pending grades and a NULL term GPA |
| Lineage | `J1Sim.Enrollment`, `FinalGrade`, `CredentialAwarded` → landing → `staging.Enrollment`, `staging.CredentialAwarded` → `core.vw_Enrollment`, `core.vw_Credential` → report |
| Security class | Confidential: student record. Role: `role_enrollment_reporter` |
| Schedule and delivery | Weekly extract for the current term |
| Controls | Sum of `AttemptedCredits` = credits of non-dropped enrollments in `core.vw_Enrollment` for the term. `EarnedCredits ≤ AttemptedCredits` for every row. Cumulative values never decrease across a student's terms |
| Known limitations | Course repeats are all counted; the source has no repeat policy. Transfer credit is not in the source |

## R5. Applicant integration exception worklist

| Field | Specification |
|---|---|
| Owner and audience | Data Operations (owner); Admissions analysts who correct Slate-Sim |
| Purpose | Shows analysts what is blocked, why, for how long and what they may do next, without exposing applicant identity in the list itself |
| Objects | `reporting.vw_ExceptionWorklist` (masked list); `reporting.usp_GetExceptionDetail @ExceptionId, @AccessReason` (drill-through); extract type `EXCEPTION_WORKLIST` |
| Grain | One row per active exception (`OPEN`, `ASSIGNED`, `AWAITING_SOURCE_CORRECTION`, `RESOLVED`, `RETRY_READY`) |
| Masked identity | `ApplicantInitials` (first letters of standardized first and last name), `BirthYear`, `MaskedEmail` (first character of the local part, then `***@domain`). No full name, birth date, phone, address or SIS ID |
| Measures | `AgeDays` since the exception was created. `CandidateCount` from the current match decision. `PermittedNextStatuses`: allowed transitions from `reference.ExceptionStatusTransition`, comma-separated. Owner and remediation come from `reference.ExceptionReason` |
| Drill-through | The detail procedure returns the raw and standardized applicant values and the candidate SIS ID numbers. It requires a non-empty access reason and writes an `audit.AccessEvent` on every call, including refused ones |
| As-of behavior | Live; reflects the latest pipeline run |
| Lineage | `integration.IntegrationException`, `MatchDecision`, `staging.Applicant` → `integration.vw_OpenExceptionWorklist` → report |
| Security class | List: Internal, masked. Drill-through: Confidential. Role: `role_integration_service` (Data Operations analysts and the pipeline service) |
| Schedule and delivery | Daily extract of the masked list. Drill-through on demand only, never extracted |
| Controls | Row count = active exceptions in `integration.IntegrationException`. No masked column may contain the full standardized first or last name, which is tested |
| Known limitations | Initials and birth year can still identify someone in a very small group. The list is for internal staff only, never for public copies |

## R6. Leadership KPI dataset

| Field | Specification |
|---|---|
| Owner and audience | Institutional Research (owner); the President's cabinet and the board |
| Purpose | Gives every leadership number one stable definition and one source, so different decks show the same counts |
| Objects | `reporting.vw_LeadershipKPI`; extract type `LEADERSHIP_KPI`; every measure is registered in `compliance.MeasureDefinition` |
| Grain | One row per term and measure |
| Measures | See the table below. Every measure row has an owner, unit, inclusion rule, as-of behavior and lineage in `compliance.MeasureDefinition` |
| As-of behavior | `DataStatus` is `FINAL` for census-based measures read from a snapshot, `NO_SNAPSHOT` (value NULL) when the term has none yet, and `CURRENT` for measures computed from current data |
| Security class | Internal: aggregate. Role: `role_ir_analyst` |
| Schedule and delivery | Daily extract; the Power BI Executive Overview page |
| Controls | `CENSUS_HEADCOUNT` equals the snapshot's included count. `YIELD_RATE` is between 0 and 1. Prior-period change thresholds |
| Known limitations | No retention, graduation-rate or demographic measures (the source has no sex or race/ethnicity) |

| Measure | Definition | Unit | Source | Data status |
|---|---|---|---|---|
| `APPLICATIONS` | Applications for the entry term with status `SUBMITTED` or later (not `STARTED`) | count | `core.vw_Application` | CURRENT |
| `ADMITS` | Applications whose status is `ADMITTED` or `DEPOSITED` | count | `core.vw_Application` | CURRENT |
| `DEPOSITS` | Applications whose status is `DEPOSITED` | count | `core.vw_Application` | CURRENT |
| `YIELD_RATE` | `DEPOSITS ÷ ADMITS`; NULL when there are no admits | ratio | derived | CURRENT |
| `CENSUS_HEADCOUNT` | Students included at census | count | snapshot | FINAL |
| `CENSUS_FTE` | Census credits ÷ 15. **Assumption:** a term FTE divisor of 15 credits. IPEDS estimates FTE from 12-month credit hours (see the IPEDS mapping), which is a different measure | FTE | snapshot | FINAL |
| `FULL_TIME_SHARE` | Full-time included students ÷ included students | ratio | snapshot | FINAL |
| `AID_RECIPIENTS` | Students with an `ACCEPTED` award in the term | count | `core.vw_AidAward` | CURRENT |
| `OUTSTANDING_BALANCE` | Sum of positive net balances on the earlier of the term end date and today, from `reporting.fn_StudentAccountAging` | USD | `core.vw_AccountTransaction` | CURRENT |
| `COURSE_SUCCESS_RATE` | Sections graded C or better (grade points ≥ 2.00) ÷ sections with any final grade, including W, F and I; NULL until grades exist | ratio | `core.vw_Enrollment` | CURRENT |
| `COMPLETIONS` | Credentials awarded with the term as their award term | count | `core.vw_Credential` | CURRENT |

## IPEDS-aligned mock extracts

Four aggregate extracts (`IPEDS_FE`, `IPEDS_E12`, `IPEDS_C` and `IPEDS_SFA`) are specified in
[ipeds-measure-mapping.md](ipeds-measure-mapping.md). They are educational simulations and are
not ready to submit.

## Supporting operational extract

`DQ_SCORECARD` (weekly, owner Data Operations): one row per data-quality rule from the latest
validation run, with records evaluated, records failed and pass rate. It adds no definitions
beyond [data-quality-rules.md](data-quality-rules.md).
