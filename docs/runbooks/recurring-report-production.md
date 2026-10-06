# Runbook: recurring report production

**Owner:** Data Operations (schedules and delivery) with Institutional Research (IPEDS review)
**Applies to:** the DAILY, WEEKLY and CENSUS extract schedules and on-demand extracts
([extract-controls.md](../specifications/extract-controls.md))

Every report leaves the database as an **extract run**: stored CSV lines, a SHA-256 and control
totals. Files are written only from a stored run, never from a fresh query, so what was reviewed
is exactly what is delivered.

## 1. Daily check (after the 06:00 job)

```sql
-- Today's runs and their status
SELECT r.ExtractRunId, r.ExtractTypeCode, r.ReportingPeriod, r.ExtractStatusCode, r.ValidationStatusCode,
       r.ApprovalStatusCode, r.DataRowCount, r.ErrorMessage
FROM compliance.ExtractRun AS r
WHERE r.GeneratedAtUtc >= CAST(SYSUTCDATETIME() AS DATE)
ORDER BY r.ExtractRunId;

-- Every control that did not pass
SELECT r.ExtractTypeCode, r.ReportingPeriod, c.ControlCode, c.ExpectedValue, c.ActualValue, c.PriorValue,
       c.ChangePct, c.OutcomeCode, c.Note
FROM compliance.ExtractControlTotal AS c
JOIN compliance.ExtractRun AS r ON r.ExtractRunId = c.ExtractRunId
WHERE c.OutcomeCode <> 'PASS' AND r.GeneratedAtUtc >= DATEADD(DAY, -7, SYSUTCDATETIME())
ORDER BY r.ExtractRunId, c.ControlCode;
```

| Finding | Action |
|---|---|
| Agent job failed | Job history names the failed item; `compliance.ExtractRun.ErrorMessage` holds the error. Fix the cause, then rerun the job (`make agent-run JOB="..."`). The other items in the schedule still ran |
| `ExtractStatusCode = FAILED` | The builder raised an error; the run has no rows. A census extract fails this way when the term has no snapshot yet (`52130`) |
| `ValidationStatusCode = FAILED` | A reconciliation, subtotal or rule control failed. **Do not deliver.** The report disagrees with its independent total; open an incident and investigate the named control. A failed run cannot be approved |
| `ValidationStatusCode = WARNING` | Either a rule could not be checked (no expected value, for example no fall snapshot yet) or a value changed more than the limit against the prior period. Read the note. Deliver only after the owner confirms the change is real, and record that in the approval note |
| Nothing ran | Check the nightly run first: extracts refuse to run while a nightly run is `RUNNING` (`52105`) or before any run has succeeded (`52104`) |

## 2. Census and IPEDS (after the 05:00 census job)

1. The census job captures a snapshot for each term whose census date has passed. Confirm the
   snapshot and its lag:

   ```sql
   SELECT s.TermCode, s.CensusDate, s.CapturedAtUtc, s.CaptureLagDays, s.PopulationCount, s.IncludedCount
   FROM compliance.CensusSnapshot AS s ORDER BY s.CensusDate DESC;
   EXEC compliance.usp_VerifyCensusSnapshot @CensusSnapshotId = <id>;
   ```

   A `CaptureLagDays` above 1 means the snapshot reflects data at capture time, not on the census
   date. Note it in the census memo; do not recapture (ADR-003).
2. A snapshot is never corrected in place. If the census rule itself must change, add a new
   `CENSUS-n` version in `compliance/Seed/compliance_seed.sql`, make it current, deploy, and let
   the next capture create new snapshots beside the old ones.
3. IPEDS-aligned extracts are **educational simulations**. Review the WARNING notes against
   [ipeds-measure-mapping.md](../specifications/ipeds-measure-mapping.md) before approving.

## 3. Approve

A member of `role_ir_analyst` who did not request the run approves or rejects it:

```sql
EXEC compliance.usp_ApproveExtract @ExtractRunId = <id>, @Decision = 'APPROVED',
     @Note = N'Fall growth explained by the new Nursing cohort.';
```

The requester cannot approve their own run (`52114`), and a failed run cannot be approved
(`52113`). Decisions are final and audited; to change one, generate a new run.

## 4. Deliver

```bash
make export RUN=<id>
```

This writes `out/extracts/<type>_<period>_run<id>.csv` and `.manifest.json`, but only when the
file's SHA-256 equals the stored one and the header matches the contract. Send the CSV together
with its manifest. The recipient can check the file with `shasum -a 256` against the manifest's
`sha256`. Only aggregate types may be published:

```bash
make export RUN=<id> PUBLIC=1
```

This writes a copy to `sample-output/extracts/` with counts of 1 to 4 shown as `<5`.
Student-level types are refused.

## 5. On demand

```bash
uv run campus-ops generate-extract --type ACCOUNT_AGING --period 2026-09-30
```

The caller must belong to the type's access role (`reference.ExtractType.AccessRoleName`).
Every generation and export is in `audit.AccessEvent`.
