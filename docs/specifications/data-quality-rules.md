# Data-quality rules

**Owner:** Data Operations (suite), with each rule owned by the department named below
**Implements:** `dq.usp_RunDataQualitySuite` and the `dq.usp_Check*` procedures
**Metadata:** `dq.Rule`, seeded by `dq/Seed/dq_rule_seed.sql`

Rules are metadata-driven. `dq.Rule` holds each rule's description, entity, severity, owner,
effective date, active flag, expected condition and remediation guidance. The check procedures
implement the logic, evaluate only rules that are active and effective, and write:

- one `dq.RuleResult` row per failing record (record key and a non-personal detail code), and
- one `dq.RuleExecution` row per rule with the number of records evaluated and failed, which is
  what the scorecard's pass rate uses.

The suite runs once per pipeline run inside one transaction, so a run's results are complete or
absent. Running it again for the same batch returns the existing run instead of duplicating it.

Data-quality findings measure the data; they do not block processing. Blocking is done by
integration exceptions ([integration-controls.md](integration-controls.md)). Some applicant
checks deliberately appear in both places: the exception drives the work queue, and the rule
feeds trend reporting.

## Rules

| Rule code | Entity (record key) | Severity | Owner | Fails when |
|---|---|---|---|---|
| `APP_REQUIRED_FIELDS` | Application (`ApplicationId`) | HIGH | Admissions | An eligible application lacks first name, last name, birth date, entry term or first program choice |
| `APP_EMAIL_FORMAT` | Application | LOW | Admissions | An email is present but invalid under the normalization rules |
| `APP_PHONE_FORMAT` | Application | LOW | Admissions | A phone is present but does not normalize to 10 digits |
| `APP_PROGRAM_VALID` | Application | HIGH | Admissions | An eligible application's program is absent from the crosswalk or inactive |
| `APP_TERM_VALID` | Application | HIGH | Admissions | An eligible application's entry term is unknown or closed for admission |
| `APP_DUPLICATE_APPLICATION` | Application | MEDIUM | Admissions | Two or more eligible applications share a Slate-Sim person and entry term |
| `SIS_DUPLICATE_PERSON` | SIS person (`IdNumber`) | HIGH | Registrar | Two or more J1-Sim people share normalized first and last name, birth date and postal code |
| `ENR_STUDENT_EXISTS` | Enrollment (`EnrollmentId`) | HIGH | Registrar | The enrollment's person has no staged student record |
| `ENR_TERM_VALID` | Enrollment | HIGH | Registrar | The section's term is not in `reference.AcademicTerm` |
| `ENR_GRADE_STATUS` | Enrollment | MEDIUM | Registrar | A grade is posted on a `DROPPED` enrollment, or a `WITHDRAWN` enrollment has a grade other than `W` |
| `AID_PERIOD_VALID` | Aid award (`AwardId`) | HIGH | Financial Aid | The award's term is unknown, or its aid year differs from the term's academic year |
| `AID_DISBURSED_ENROLLED` | Aid award | MEDIUM | Financial Aid | Money was disbursed for a term in which the student has no `REGISTERED` enrollment |
| `DIR_ACTIVE_STUDENT_ACCOUNT` | Student (`IdNumber`) | MEDIUM | IT Identity Services | An `ACTIVE` student has no enabled `STUDENT` directory account |
| `DIR_ORPHAN_ACCOUNT` | Directory account (`AccountGuid`) | MEDIUM | IT Identity Services | A `STUDENT` account's `EmployeeId` is missing, non-numeric or not a J1-Sim person |
| `ACCT_DETAIL_TO_TOTAL` | Student account term (`IdNumber|TermCode`) | HIGH | Student Accounts | Staged transaction count or amount differs from the source control total captured at load |
| `INT_CROSSWALK_PRESENT` | Application | HIGH | Data Operations | An application was written to J1-Sim but has no source crosswalk row |

## Notes on specific rules

**`ACCT_DETAIL_TO_TOTAL`.** J1-Sim stores transactions but no account balance, so there is no
stored total to compare against. Instead, each J1-Sim landing load also captures the source's own
count and sum of transactions for every student-term it touches
(`landing.J1AccountControlTotal`). The rule compares the latest captured total with the staged
detail. Besides load defects, this catches transactions deleted at the source, which an
incremental watermark load cannot otherwise see, whenever the same student-term changes again.

**`SIS_DUPLICATE_PERSON`.** Uses the same normalized values as matching rule 4. Detail code
`GROUP:<lowest IdNumber>` ties the members of one group together.

**`AID_DISBURSED_ENROLLED`.** Checks for a `REGISTERED` enrollment in the award's term. This is a
data-consistency rule, not a Title IV eligibility determination.

## Added in Part 3

| Rule code | Entity (record key) | Severity | Owner | Fails when |
|---|---|---|---|---|
| `CRED_EARNED_CREDITS` | Credential (`CredentialAwardedId`) | HIGH | Registrar | The student had not earned the program's required credits (graded D or better, in terms starting no later than the award term) when the credential was awarded. Detail `EARNED_<n>_OF_<required>` |
| `STU_STATUS_CONSISTENT` | Student (`IdNumber`) | MEDIUM | Registrar | A `GRADUATED` student has no credential (`GRADUATED_NO_CREDENTIAL`), or a `WITHDRAWN` student is still `REGISTERED` in a term that has not ended (`WITHDRAWN_FUTURE_REGISTRATION`) |

On the default seed both rules evaluate every record (139 credentials and 2,062 students) and find
no failures. The generator awards credentials only after completion, so these rules guard
against future source drift rather than reporting planted cases.

## Issue disposition

An owner records a decision about a failure with `dq.usp_RecordIssueDisposition`:
`FIX_IN_SOURCE`, `ACCEPTED_EXCEPTION` (which requires a review date) or `FALSE_POSITIVE`, always
with a note. Each new decision supersedes the current one, and earlier decisions are kept.
`dq.vw_CurrentDataQualityIssues` shows the current disposition beside each failure. A
disposition annotates a failure; it never removes it from the scorecard or the pass rate.
