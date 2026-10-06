# Security policy

## Data policy

- This repository contains **only synthetic data**. No real student, applicant, employee or
  financial record may be committed, loaded into a shared environment, or used in screenshots.
- Generated emails use the reserved `example.com` domain, phones use the fictional `555-0100`
  to `555-0199` range, and no Social Security or other government identifier is modelled.
  `tests/python/test_safe_identifiers.py` enforces these rules on every run.
- Even synthetic direct identifiers (names, birth dates, emails) are kept out of logs and public
  screenshots. Python logs record counts, batch identifiers and dataset fingerprints only.

## Secrets

- Local secrets live in `.env`, which is git-ignored. `.env.example` documents the variables with
  no values.
- CI generates a throwaway SQL Server password at runtime and masks it; no repository secrets are
  required for the validation workflow.
- `sqlcmd` receives the password through `SQLCMDPASSWORD`, never on its command line. SqlPackage has
  no equivalent, so during `make deploy` the password is visible in the local process list.
- Pre-commit runs `gitleaks` and `detect-private-key`; CI scans the full Git history with gitleaks.

## Known limitations of the local environment

- Developers deploy, seed and run the pipeline as `sa` against a local container. People and
  reports use the eight least-privilege roles in
  [docs/architecture/security-model.md](docs/architecture/security-model.md): `SELECT` or
  `EXECUTE` on curated objects only, with `landing`, `staging` and `core` denied. The deployed
  permissions are tested against the specified matrix. A production integration service would
  also need `EXECUTE` on `J1Sim.usp_ReceiveAdmittedApplicant` in the source database; that
  cross-database grant is not modelled here.
- Exception worklists, data-quality results and match evidence store identifiers and codes, not
  names, birth dates or contact values. Engine messages in `audit.ErrorLog` can quote values; only
  `role_auditor` (schema-wide `SELECT` on `audit`) and `db_owner` can read that table.
- Masked outputs (`security.vw_StudentMasked`, `bi`) use random surrogate keys. Only
  `db_owner` can read the key table `security.StudentPseudonym`.
- Extract generation, export and approval, exception drill-through and security administration
  are recorded in `audit.AccessEvent`. Every permission or role-membership change is recorded in
  `audit.PermissionChangeEvent` by a database DDL trigger, including changes made outside the
  procedures.
- `sample-output/` may hold only aggregate extracts copied with `campus-ops export --public`,
  which refuses student-level types and shows counts of 1 to 4 as `<5`.
- Power BI imports only the masked `bi` schema, through a login in `role_ir_analyst`. Power BI
  roles are separate from SQL roles; see `powerbi/dax/RLS-Roles.md`.
- `Scripts/reset_operational_data.sql` deletes all operational history and exists for development
  and tests only. It is not part of the DACPAC and refuses to run without explicit confirmation.
- tSQLt is installed only into development and CI databases. Its installation enables CLR on the
  local container (`PrepareServer.sql`); the download is verified against a pinned SHA-256.
- `CAMPUS_DB_TRUST_SERVER_CERTIFICATE=true` is for the container's self-signed certificate only.
  Connections always request encryption.
- The project demonstrates controls informed by FERPA and GLBA obligations. It does not claim
  compliance with either.

## Reporting a vulnerability

Please report suspected vulnerabilities privately through GitHub's
"Report a vulnerability" (private security advisory) on this repository rather than in a public issue.
