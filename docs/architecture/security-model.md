# Security model

**Owner:** Data Operations (implementation) and the institution's security office (approval)
**Implements:** `database/CampusDataOps.Database/security/**`, the grant scripts, `security.*`
procedures, `audit.AccessEvent`, `audit.PermissionChangeEvent` and the database DDL trigger

This project shows controls informed by FERPA (education records are disclosed only to school
officials with a legitimate educational interest) and by the GLBA safeguards expected of Title IV
institutions. It does **not** claim compliance with either. A portfolio repository cannot be
compliant; only an institution's operated environment can.

## Principles

1. **Curated objects only.** Department roles get `SELECT` or `EXECUTE` on named `reporting`,
   `compliance`, `security` or `bi` objects. Nobody in a role has rights on base tables.
2. **Explicit denial of raw layers.** Every managed role is denied `SELECT`, `INSERT`, `UPDATE`
   and `DELETE` on the `landing`, `staging` and `core` schemas. Reports still work because their
   views and procedures are owned by `dbo` (ownership chaining), so the caller needs rights only
   on the object they call. A grant mistake on a raw schema cannot expose data, because `DENY`
   overrides any grant.
3. **Roles, not users.** Grants go to roles in the DACPAC. People and service accounts become
   members through `security.usp_GrantRoleMembership`, which only accepts the roles listed in
   `security.ManagedRole` (never `db_owner` or other fixed roles) and records a ticket reference.
4. **Masking for broad audiences.** Leadership, IR and Power BI use `security.vw_StudentMasked`
   and the `bi` star schema. These use a random surrogate `StudentKey` and `MaskedStudentId`
   (`S0000123`), never the SIS ID, name, birth date or contact data. Surrogates come from
   `security.StudentPseudonym`, assigned in random order, so they cannot be derived from the SIS
   ID without access to that table.
5. **Everything sensitive leaves a trace.** Extract generation, export, approval and exception
   drill-through write `audit.AccessEvent`. Every `GRANT`, `DENY`, `REVOKE`, role-membership or
   user change is caught by the database DDL trigger `trg_audit_PermissionChange` and written to
   `audit.PermissionChangeEvent`.

## Roles

| Role | Purpose | Data class |
|---|---|---|
| `role_integration_service` | The pipeline service account and the Data Operations analysts who work exceptions | Confidential (exception drill-through) |
| `role_enrollment_reporter` | Registrar and Enrollment Management | Confidential student record |
| `role_financial_aid_reporter` | Financial Aid | Confidential student financial |
| `role_student_accounts_reporter` | Student Accounts (Bursar) | Confidential student financial |
| `role_ir_analyst` | Institutional Research, leadership analytics and the Power BI dataset | Masked and aggregate only |
| `role_program_coordinator` | Academic program coordinators: masked census roster for **their own programs** (row-level security) | Masked, row-filtered |
| `role_security_admin` | Grants and revokes role membership and program scope; reviews the access logs | Audit metadata |
| `role_auditor` | Read-only review of audit, extract and permission history | Audit metadata |

## Permission matrix

The matrix below is the specification. `security.vw_RolePermissionMatrix` lists the deployed
permissions, and the tSQLt test `SecurityTests.[test deployed permissions equal the
specified matrix]` fails on any difference, including an extra grant.

| Role | Granted | Object |
|---|---|---|
| `role_integration_service` | EXECUTE | `integration.usp_StartPipelineRun`, `integration.usp_RunPipelineStep`, `integration.usp_OpenRecoveryRun`, `integration.usp_TransitionException`, `integration.usp_ResolveExceptionMatch` |
| | EXECUTE | `compliance.usp_CaptureCensusSnapshot`, `compliance.usp_RunScheduledExtracts`, `compliance.usp_GenerateExtract`, `compliance.usp_GetExtractForExport` |
| | SELECT | `reporting.vw_ExceptionWorklist` |
| | EXECUTE | `reporting.usp_GetExceptionDetail` |
| `role_enrollment_reporter` | SELECT | `reporting.vw_EnrollmentCensus`, `reporting.vw_AcademicProgress` |
| | EXECUTE | `reporting.usp_ReportEnrollmentByTerm`, `reporting.usp_ReportAcademicOutcomes`, `compliance.usp_GetExtractForExport` |
| `role_financial_aid_reporter` | SELECT | `reporting.vw_FinancialAidPackaging` |
| | EXECUTE | `reporting.usp_ReportAidByAcademicYear`, `compliance.usp_GetExtractForExport` |
| `role_student_accounts_reporter` | SELECT | `reporting.vw_StudentAccountAging`, `reporting.fn_StudentAccountAging` |
| | EXECUTE | `reporting.usp_ReportAccountAging`, `compliance.usp_GetExtractForExport` |
| `role_ir_analyst` | SELECT | `reporting.vw_LeadershipKPI`, the four `compliance.vw_IPEDS_*` views, `compliance.MeasureDefinition`, `compliance.ExtractRun`, `compliance.ExtractControlTotal`, `compliance.CensusSnapshot`, `security.vw_StudentMasked` |
| | SELECT (schema) | `bi` |
| | EXECUTE | `compliance.usp_GenerateExtract`, `compliance.usp_ApproveExtract`, `compliance.usp_GetExtractForExport`, `compliance.usp_VerifyCensusSnapshot` |
| `role_program_coordinator` | SELECT | `reporting.vw_ProgramCensusRoster` |
| `role_security_admin` | EXECUTE | `security.usp_GrantRoleMembership`, `security.usp_RevokeRoleMembership`, `security.usp_SetProgramScope` |
| | SELECT | `security.UserProgramScope`, `security.vw_RolePermissionMatrix`, `audit.AccessEvent`, `audit.PermissionChangeEvent` |
| `role_auditor` | SELECT (schema) | `audit` |
| | SELECT | `security.vw_RolePermissionMatrix`, `compliance.ExtractRun`, `compliance.ExtractControlTotal`, `compliance.CensusSnapshot`, `dq.vw_DataQualityScorecard` |
| every managed role | DENY SELECT, INSERT, UPDATE, DELETE (schema) | `landing`, `staging`, `core` |

### Checks inside procedures

`EXECUTE` on a shared procedure is not enough by itself:

- `compliance.usp_GenerateExtract` and `compliance.usp_GetExtractForExport` check the caller
  against `reference.ExtractType.AccessRoleName`. For example, only Student Accounts (or the
  service, or `db_owner`) can generate or export `ACCOUNT_AGING`. A refused call is still
  audited.
- `compliance.usp_ApproveExtract` requires `role_ir_analyst`, and the approver must not be the
  requester (also a `CHECK` constraint).
- `reporting.usp_GetExceptionDetail` requires a non-empty access reason.

### Behavioral tests

As well as the matrix comparison, `SecurityTests` creates users without logins, adds them to
roles and runs `EXECUTE AS USER`. Each role must be able to read its own products and must get
permission error 229 or 230 on landing, staging, core and every other department's products.

## Row-level security: program coordinators

**Scenario.** Program coordinators advise and plan sections for their own programs, such as
Nursing or Welding. They need the census roster (masked student, credit load, attendance
intensity, entry status) for those programs only. Seeing another program's students has no
legitimate educational interest, which is the FERPA test.

**Implementation.**

- `security.UserProgramScope (UserName, ProgramCode)` lists the programs each coordinator may
  see. Rows change only through `security.usp_SetProgramScope`, which only
  `role_security_admin` can run and which writes an `audit.AccessEvent`.
- `security.fn_ProgramScopePredicate(@ProgramCode)` is an inline, schema-bound predicate. It
  allows a row when the caller is not a member of `role_program_coordinator`, or when
  `UserProgramScope` has (current user, program).
- The security policy `security.ProgramScopePolicy` applies the predicate as a **filter** on
  `compliance.CensusSnapshotEnrollment`. No block predicate is needed, because nobody can write
  to the table and triggers make it immutable.

**Why only this one table.** The census roster is the one product shared with a role whose
scope differs per member. Department roles see their whole department's data, which the grants
alone enforce. Applying RLS everywhere would add a predicate to every report query and make
tests and plans harder to reason about, for no gain in protection.

**Operational trade-offs.**

- The predicate runs for every query against the snapshot rows, including reports run by roles
  it does not filter. It is an inline function with an index-supported `EXISTS`, but Part 4
  should measure its cost on the census query.
- A coordinator who belongs to no program sees nothing, not an error. The access-request runbook
  checks the scope after granting the role.
- Known side channel: RLS filter predicates can be probed with crafted queries (for example,
  errors such as divide-by-zero reveal whether a hidden row exists). The coordinator role has
  `SELECT` on one view only, which limits but does not remove this. Microsoft documents the
  risk.
- Members of `db_owner` and `sysadmin` bypass nothing in the predicate itself, but they can turn
  the policy off. That is why every change is caught by the permission-change trigger.

## Power BI and SQL security are separate

See [`powerbi/dax/RLS-Roles.md`](../../powerbi/dax/RLS-Roles.md).

- **Import mode:** the dataset refreshes under one service identity (`role_ir_analyst`). SQL
  roles and SQL RLS apply to that identity only, never to report viewers. Viewer restrictions
  must be Power BI roles defined in the model.
- **DirectQuery with single sign-on:** SQL Server would see each viewer's identity, so SQL roles
  and RLS would apply per viewer. That requires Microsoft Entra ID authentication, which a local
  SQL Server container cannot use. It is documented here but not built.

## Encryption, secrets and retention

| Control | State in this project |
|---|---|
| Encryption in transit | All client connections request `Encrypt=yes` (ODBC Driver 18, sqlcmd `-C` only for the local self-signed certificate). Production must use a trusted certificate and `TrustServerCertificate=no` |
| Encryption at rest (TDE) | Not enabled on the local container. To enable in production: create a master key and certificate in `master`, back the certificate up off-server, create a database encryption key with `AES_256`, then `ALTER DATABASE ... SET ENCRYPTION ON` |
| Backup encryption | `BACKUP DATABASE ... WITH ENCRYPTION (ALGORITHM = AES_256, SERVER CERTIFICATE = ...)`; the certificate backup is stored apart from the backups |
| Secrets | `.env` (git-ignored) locally and GitHub Actions secrets in CI. Gitleaks scans the full history in CI. Nothing in the repository holds a password |
| Sample output | `sample-output/` holds only aggregate, small-cell-suppressed copies of public-safe extracts, produced by `campus-ops export --public` |
| Retention | See the operations handbook: landing and audit history 7 years in this simulation (**Assumption**, to be set by the records officer), census snapshots and approved extracts kept permanently, exported files purged after 90 days |
