# Runbook: failed-job recovery

**Owner:** Data Operations
**Applies to:** a FAILED `NIGHTLY_INTEGRATION` run, whether started by Agent or `make nightly`

Every step works from database state and is idempotent, so a recovery can resume at any step
without duplicating students, exceptions or queue rows. Recovery is always explicit: an operator
opens a recovery run, which records who approved it and which steps it skipped.

## 1. Find the failed run and step

Agent job history names the step and shows the first part of the message:

```sql
SELECT TOP (12) h.step_id, h.step_name, h.run_status, h.run_date, h.run_time, h.message
FROM msdb.dbo.sysjobhistory AS h
JOIN msdb.dbo.sysjobs AS j ON j.job_id = h.job_id
WHERE j.name = N'CampusDataOps - Nightly Integration'
ORDER BY h.instance_id DESC;
```

The audit tables hold the full story:

```sql
SELECT TOP (1) br.BatchId, br.BatchStatusCode, br.StartedAtUtc, br.EndedAtUtc
FROM audit.BatchRun AS br
WHERE br.ProcessName = 'NIGHTLY_INTEGRATION'
ORDER BY br.BatchId DESC;

SELECT bs.StepName, bs.AttemptNumber, bs.BatchStepStatusCode, bs.StartedAtUtc, bs.EndedAtUtc
FROM audit.BatchStep AS bs WHERE bs.BatchId = @FailedBatchId ORDER BY bs.StepOrder, bs.AttemptNumber;

SELECT e.ErrorLogId, e.BatchStepId, e.ErrorNumber, e.ErrorProcedure, e.ErrorLine, e.ErrorMessage, e.LoggedAtUtc
FROM audit.ErrorLog AS e
WHERE e.BatchId = @FailedBatchId
   OR e.BatchId IN (SELECT br.BatchId FROM audit.BatchRun AS br WHERE br.ParentBatchId = @FailedBatchId)
ORDER BY e.ErrorLogId;
```

The earliest error is usually the cause; later ones are the step reporting it.

## 2. Common causes

| Failed step | Typical cause | Fix |
|---|---|---|
| LOAD | A source database is offline or unreachable | Restore access. The failed landing batch did not advance its watermark, so the next load reads the same rows again |
| PROCESS | J1-Sim refused writes (read-only maintenance window, inactive program, closed term); error 50300 summarizes, the per-row cause is logged before it | Fix the cause; failed rows are `FAILED_RETRYABLE` and are retried. After `MaxAttempts` they become `FAILED_PERMANENT` with an `OUTBOUND_WRITE_FAILURE` exception |
| RECONCILE or NOTIFY | Error 50401: the run did not reconcile | Do not simply rerun. Investigate with the [exception reconciliation runbook](exception-reconciliation.md), step 5 |
| Any | Error 50500: a step ran without a RUNNING run, or 50502: a step ran out of order | Start the job from step 1 or open a recovery run |

## 3. Open a recovery run

Choose the step to resume at, normally the step that failed:

```sql
EXEC integration.usp_OpenRecoveryRun @FailedBatchId = 27, @ResumeAtStepCode = 'PROCESS';
```

This creates a new RUNNING run with `RecoveryOfBatchId = 27` and records the earlier steps as
`SKIPPED`. A failed run can be recovered once; if the recovery also fails, recover the recovery
run.

## 4. Resume

With Agent, start the job at the same step (Agent steps find the single RUNNING run):

```sql
EXEC msdb.dbo.sp_start_job @job_name = N'CampusDataOps - Nightly Integration', @step_name = N'PROCESS';
```

Without Agent, the CLI opens the recovery run and runs the remaining steps in one command:

```bash
make recover FAILED_BATCH=27 AT=PROCESS
```

## 5. Confirm

1. The recovery run is SUCCEEDED and its reconciliation is balanced (see the
   [nightly runbook](nightly-integration.md)).
2. No application was written twice:

   ```sql
   SELECT r.SourceApplicationId, COUNT(*) AS Writes
   FROM SourceSystems.J1Sim.IntegrationReceipt AS r
   GROUP BY r.SourceApplicationId
   HAVING COUNT(*) > 1;
   ```

   This must return no rows.
3. Record the incident (symptom, evidence, cause, fix) in the operations log.

## Rehearsed example

Verified on 2026-10-05 against the local container (recorded in
[VERIFICATION-LOG.md](../ai/VERIFICATION-LOG.md)): SourceSystems was set READ_ONLY to simulate an
SIS maintenance window. Agent run 27 failed at PROCESS with error 50300; `audit.ErrorLog` held
the cause, error 3906 from `J1Sim.usp_ReceiveAdmittedApplicant`, tied to the batch and step; the
queue row was `FAILED_RETRYABLE`. After `ALTER DATABASE SourceSystems SET READ_WRITE`, recovery
run 31 (LOAD through QUEUE skipped) wrote the record on attempt 2, reconciled, and closed the
application's exception, with exactly one J1-Sim receipt for the application.
