# Runbook: nightly integration

**Owner:** Data Operations · **Schedule:** daily 02:00 server time (UTC in the container)
**Job:** SQL Server Agent `CampusDataOps - Nightly Integration`
**Specification:** [integration-controls.md](../specifications/integration-controls.md)

## What the job does

| Step | What happens | Normal result |
|---|---|---|
| START | Opens a `NIGHTLY_INTEGRATION` run in `audit.BatchRun` | One RUNNING run |
| LOAD | Lands changed rows from Slate-Sim, J1-Sim and Directory-Sim, one landing batch each | Three SUCCEEDED child batches (`ParentBatchId` = the run) |
| STAGE | Standardizes the latest landed rows | Rows written only for changed records |
| DATA_QUALITY | Runs every active `dq.Rule` | One `dq.ValidationRun` |
| MATCH | Raises validation exceptions, evaluates identity, raises identity exceptions | New decisions only for new or changed applications |
| QUEUE | Approves resolved exceptions for retry and queues ready applications | One live queue row per ready application |
| PROCESS | Writes queued rows to J1-Sim, one transaction each | All attempted rows SUCCEEDED |
| RECONCILE | One outcome per eligible application; checks J1-Sim | `IsBalanced = 1` |
| NOTIFY | Publishes the summary and closes the run | Run SUCCEEDED |

The job stops at the first failed step; the run is then FAILED and nothing later runs.

## Run it

```bash
make agent-install
```

```bash
make agent-run
```

`make agent-run` starts the job, waits for it and fails if it fails. To run the same procedures
without Agent (local development, tests):

```bash
make nightly
```

## Check the result

```sql
-- The latest runs and their reconciliation.
SELECT TOP (5) br.BatchId, br.RecoveryOfBatchId, br.BatchStatusCode, br.StartedAtUtc, br.EndedAtUtc,
       rr.SourceEligible, rr.Created, rr.Matched, rr.Unchanged, rr.Rejected, rr.Pending,
       rr.TargetConfirmed, rr.IsBalanced
FROM audit.BatchRun AS br
LEFT JOIN integration.ReconciliationResult AS rr ON rr.BatchId = br.BatchId
WHERE br.ProcessName = 'NIGHTLY_INTEGRATION'
ORDER BY br.BatchId DESC;

-- Steps of one run.
SELECT bs.StepName, bs.AttemptNumber, bs.BatchStepStatusCode, bs.RowsAffected, bs.StartedAtUtc, bs.EndedAtUtc
FROM audit.BatchStep AS bs
WHERE bs.BatchId = @BatchId
ORDER BY bs.StepOrder, bs.AttemptNumber;
```

Or from the shell:

```bash
uv run python -m campus_ops.cli run-summary --batch 15
```

A healthy run has status SUCCEEDED, `IsBalanced = 1`, and
`SourceEligible = Unchanged + Matched + Created + Rejected + Pending` (the database rejects a
summary that does not add up).

## Daily checks

1. The latest run SUCCEEDED and is balanced.
2. `Rejected` is explained by open exceptions: work them with the
   [exception reconciliation runbook](exception-reconciliation.md).
3. `Pending` is normally 0 after a successful run. A non-zero value means queued or retryable
   writes: check `integration.OutboundStudentQueue` for `FAILED_RETRYABLE` rows.
4. Review new data-quality failures by owner:

   ```sql
   SELECT RuleCode, Severity, OwnerDepartment, RecordsEvaluated, RecordsFailed, PassRate
   FROM dq.vw_DataQualityScorecard
   WHERE RecordsFailed > 0
   ORDER BY Severity, RuleCode;
   ```

## If the job failed

Follow the [failed-job recovery runbook](failed-job-recovery.md). Do not start a fresh run until
the cause is understood; a fresh run is safe (every step is idempotent) but it leaves the failed
run unexplained.

## Expected findings on the synthetic dataset

On the default seed the first run creates 247 people, matches 51 existing people and rejects 27
applications (22 review-only matches, 1 ambiguous match, 2 inactive programs, 1 missing program,
1 unknown term). Students created by the integration then show as `DIR_ACTIVE_STUDENT_ACCOUNT`
failures until IT provisions accounts, which the simulator does not model.
