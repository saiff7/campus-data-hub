# Operations handbook

How CampusDataOps runs day to day: what is scheduled, what to check, who owns what, and where the
detailed procedures are. Everything here runs on synthetic data in a local container. The
retention periods and recovery targets are **assumptions** for a real institution's records
officer and IT office to set.

## Schedule (UTC)

| Time | Agent job | What it does | Runbook |
|---|---|---|---|
| 02:00 daily | `CampusDataOps - Nightly Integration` | Load, stage, data quality, match, queue, process, reconcile, notify | [nightly-integration](runbooks/nightly-integration.md), [failed-job-recovery](runbooks/failed-job-recovery.md) |
| 05:00 daily | `CampusDataOps - Census and Compliance` | Census snapshots for terms past census; census and IPEDS-aligned extracts | [recurring-report-production](runbooks/recurring-report-production.md) |
| 06:00 daily | `CampusDataOps - Daily Operational Reports` | Account aging, aid packaging, exception worklist, leadership KPIs | [recurring-report-production](runbooks/recurring-report-production.md) |
| 07:00 Monday | `CampusDataOps - Weekly Quality Report` | Data-quality scorecard, academic progress | [recurring-report-production](runbooks/recurring-report-production.md) |

The report jobs depend on the nightly run: an extract refuses to run while a nightly run is
`RUNNING` and before any has succeeded. If the nightly run fails, fix and recover it first
(failed-job recovery runbook), then rerun the report jobs with `make agent-run JOB="..."`.

## Morning checklist (Data Operations, about 10 minutes)

1. **Nightly run:** `SELECT TOP (3) BatchId, BatchStatusCode, StartedAtUtc, EndedAtUtc FROM audit.BatchRun WHERE ProcessName = 'NIGHTLY_INTEGRATION' ORDER BY BatchId DESC;`
   The last run is `SUCCEEDED`, and `integration.ReconciliationResult.IsBalanced = 1` for it.
2. **Agent jobs:** every job's last outcome in SQL Server Agent job history is success.
3. **Extracts:** no `FAILED` run, and no `FAILED` validation, since yesterday (queries in the
   recurring report runbook). Each `WARNING` is explained or assigned to its owner.
4. **Exceptions:** `SELECT ExceptionReasonCode, COUNT(*), MAX(AgeDays) FROM reporting.vw_ExceptionWorklist GROUP BY ExceptionReasonCode;`
   Anything older than five days goes to its owning office
   ([exception-reconciliation](runbooks/exception-reconciliation.md)).
5. **Data quality:** `dq.vw_DataQualityScorecard`. A HIGH-severity rule whose failures grew since
   the previous run goes to its owner; owners record dispositions with
   `dq.usp_RecordIssueDisposition`.
6. **Data as of:** `SELECT * FROM bi.DataAsOf;` The last successful run is under 26 hours old.
   Power BI shows the same values on every page.

## Ownership

| Area | Owner | Decides |
|---|---|---|
| Pipeline, schedules, extract delivery | Data Operations | Recovery, reruns, delivery timing |
| Census rules and snapshots | Registrar, with Institutional Research | Census date, full-time threshold, new rule versions |
| IPEDS-aligned extracts and measure definitions | Institutional Research | Approval, assumptions in the IPEDS mapping |
| Report definitions | The owner named in the [report catalog](specifications/report-catalog.md) | Business rules, thresholds |
| Data-quality rules | The owner named in `dq.Rule` | Remediation and dispositions |
| Access | Security office (approves), `role_security_admin` (applies) | [access-request](runbooks/access-request.md) |

## Census calendar

Census dates are 14 days after the start of fall and spring and 7 days after the start of
summer (`reference.AcademicTerm`). The census job captures the snapshot on the first run after
the census date, normally the next morning (`CaptureLagDays = 1`). Registrar staff should finish
census-day corrections before 05:00 UTC on that day. Later corrections change live reports but
never the snapshot ([ADR-003](decisions/ADR-003-census-snapshots.md)).

## Retention (assumption)

| Data | Kept | Reason |
|---|---|---|
| Landing and audit history (`landing`, `audit`) | 7 years, then archived | Evidence for decisions and reruns (ADR-002) |
| Census snapshots, approved extract runs and their controls | Permanently | Official, reproducible numbers |
| Unapproved or failed extract runs | 2 years | Investigation history |
| Exported files in `out/extracts` | 90 days | Delivered copies; the database run is the record |
| `audit.AccessEvent`, `audit.PermissionChangeEvent` | 7 years | Access review evidence |

There is no automated purge yet. Designing one, with a dry-run report and approval, is Part 4
work.

## Backup and recovery (production design; not run locally)

- Full backup nightly after the 02:00 run, and transaction log backups every 15 minutes
  (full recovery model). Backups are encrypted with a certificate stored apart from them; see
  the [security model](architecture/security-model.md).
- Assumed targets: recovery point 15 minutes, recovery time 4 hours.
- After a restore, check `audit.BatchRun` for runs left `RUNNING`, recover them, then
  `EXEC compliance.usp_VerifyCensusSnapshot` for each snapshot.
- The local container keeps its data in the `mssql-data` Docker volume; `make clean CONFIRM=1`
  deletes it. Locally, a fresh `make bootstrap` rebuilds everything from the deterministic seed.

## Deployment

1. Merge to `main` only with the CI checks green (lint, secret scan, DACPAC build, and the
   disposable SQL Server job that bootstraps, runs every test suite and the Agent jobs).
2. `make deploy` publishes both DACPACs with `BlockOnPossibleDataLoss=True`, so a change that
   would drop data stops the deployment.
3. After deploying: `make smoke`; check that `security.vw_RolePermissionMatrix` matches the
   security model (tSQLt `SecurityTests` does this in CI).
4. Rollback means publishing the previous tagged DACPAC. Snapshots and extract runs are data, so
   a rollback never changes them.

## Development-only operations

`make reset-ops CONFIRM=1` deletes all operational data, including census snapshots and extract
runs (it disables their immutability triggers to do so). It exists for tests and local resets
and must never run against a shared environment.
