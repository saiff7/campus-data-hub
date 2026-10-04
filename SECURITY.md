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

- Part 1 deploys and seeds as `sa` against a local container. Least-privilege database roles,
  curated views and access auditing are introduced in Part 3.
- `CAMPUS_DB_TRUST_SERVER_CERTIFICATE=true` is for the container's self-signed certificate only.
  Connections always request encryption.
- The project demonstrates controls informed by FERPA and GLBA obligations. It does not claim
  compliance with either.

## Reporting a vulnerability

Please report suspected vulnerabilities privately through GitHub's
"Report a vulnerability" (private security advisory) on this repository rather than in a public issue.
