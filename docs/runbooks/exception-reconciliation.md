# Runbook: exception reconciliation

**Owner:** Data Operations, with Admissions, the Registrar and IT Identity Services by reason
**Specification:** [integration-controls.md](../specifications/integration-controls.md),
[matching-rules.md](../specifications/matching-rules.md)

Every application that the nightly run could not write to J1-Sim has at least one exception
explaining why. This runbook covers working them to closure. All changes go through stored
procedures, which record who did what, when and why in `integration.ExceptionAction`.

## 1. Read the worklist

```sql
SELECT ExceptionId, ExceptionReasonCode, Severity, OwnerDepartment, ExceptionStatusCode, AssignedTo,
       ApplicationId, DetailCode, CurrentDecisionType, CandidateCount, AgeDays, RemediationGuidance
FROM integration.vw_OpenExceptionWorklist
ORDER BY CASE Severity WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2 ELSE 3 END, AgeDays DESC;
```

The worklist shows identifiers and codes only. Look up names, birth dates or contact values in
`staging.Applicant` and `staging.Person` only when the decision requires them, and do not copy
them into notes.

## 2. Take ownership

```sql
EXEC integration.usp_TransitionException
    @ExceptionId = 42, @ToStatusCode = 'ASSIGNED', @AssignedTo = N'analyst.one',
    @ReasonText = N'Taking ownership', @ExpectedFromStatusCode = 'OPEN';
```

`@ExpectedFromStatusCode` makes the call fail if someone else changed the exception since you
read the worklist.

## 3. Resolve by reason

| Reason | Who fixes it | How |
|---|---|---|
| `MISSING_REQUIRED_FIELD`, `INVALID_PROGRAM`, `INVALID_ENTRY_TERM`, `DUPLICATE_APPLICATION`, `INVALID_CONTACT_FORMAT` | Admissions in Slate-Sim (or the Registrar for the crosswalk or term calendar) | Mark `AWAITING_SOURCE_CORRECTION`. When the corrected record is loaded, the next run resolves the exception automatically and retries the application |
| `AMBIGUOUS_MATCH`, `POSSIBLE_MATCH_REVIEW`, `IDENTITY_CONFLICT` | An authorized analyst with the Registrar | Decide identity with `integration.usp_ResolveExceptionMatch` (below). Direct `RESOLVED` is refused for these reasons |
| `ALREADY_MATRICULATED` | Registrar | Confirm whether this is a readmission or program change; correct the application in Slate-Sim (for example withdraw it), which closes the exception |
| `OUTBOUND_WRITE_FAILURE` | Data Operations | Read the error (step 4), fix the cause, then mark `RESOLVED`; the next run resets the queue row and retries |
| `RECONCILIATION_COUNT_MISMATCH` | Data Operations | Investigate the batch (step 5) before the next run |

### Identity decisions

Look at the stored candidates and evidence for the current decision:

```sql
SELECT mc.RuleCode, mc.CandidateIdNumber, mc.MatchedOnSisId, mc.MatchedOnEmail, mc.MatchedOnBirthDate,
       mc.MatchedOnName, mc.MatchedOnPostalCode
FROM integration.MatchDecision AS d
JOIN integration.MatchCandidate AS mc ON mc.MatchEvaluationId = d.MatchEvaluationId
WHERE d.ApplicationId = @ApplicationId AND d.IsCurrent = 1
ORDER BY mc.RuleCode, mc.CandidateIdNumber;
```

Then record the decision, naming either the person or a new person:

```sql
EXEC integration.usp_ResolveExceptionMatch
    @ExceptionId = 42, @MatchedIdNumber = 9000011, @Note = N'Confirmed by Admissions call 2026-10-05';

EXEC integration.usp_ResolveExceptionMatch
    @ExceptionId = 43, @ConfirmNewPerson = 1, @Note = N'Different person; confirmed by birth certificate on file';
```

For `AMBIGUOUS_MATCH` and `POSSIBLE_MATCH_REVIEW` the person must be one of the stored
candidates. A J1-Sim ID number already linked to a different Slate-Sim person is refused.

## 4. What happens next (automatic)

| Run step | Exception status |
|---|---|
| QUEUE | `RESOLVED` → `RETRY_READY` (blocking reasons) or `CLOSED` (others) |
| PROCESS | `RETRY_READY` → `REPROCESSED` when J1-Sim accepts the write |
| RECONCILE | `REPROCESSED` → `CLOSED` once J1-Sim is confirmed |

If the condition comes back before the retry, the exception reopens (`OPEN`) with its history.

To read the cause of an outbound write failure:

```sql
SELECT q.QueueId, q.ActionCode, q.QueueStatusCode, q.AttemptCount, q.MaxAttempts, e.ErrorNumber, e.ErrorMessage, e.LoggedAtUtc
FROM integration.OutboundStudentQueue AS q
JOIN audit.ErrorLog AS e ON e.ErrorLogId = q.LastErrorLogId
WHERE q.ApplicationId = @ApplicationId;
```

## 5. Investigating a reconciliation mismatch

```sql
SELECT EntityCode, LandedKeyCount, StagedKeyCount, IsBalanced
FROM integration.ReconciliationEntityCount WHERE BatchId = @BatchId;

SELECT d.ApplicationId, d.OutcomeCode, d.TargetIdNumber, d.IsTargetConfirmed
FROM integration.ReconciliationDetail AS d
WHERE d.BatchId = @BatchId AND d.IsTargetConfirmed = 0;

SELECT t.*
FROM integration.vw_J1TargetStudent AS t
JOIN integration.OutboundStudentQueue AS q ON q.IdempotencyKey = t.IdempotencyKey
WHERE q.ApplicationId = @ApplicationId;
```

An unconfirmed row stays unreconciled and is checked again by every run until J1-Sim agrees.
Resolve the mismatch exception with a note explaining the cause.

## Closing without processing

An exception can be closed when no reprocessing is wanted (for example a non-blocking contact
issue the applicant cannot fix). The closure holds while the application is unchanged; if
Slate-Sim later changes the application and the condition is still present, a new exception is
raised.

```sql
EXEC integration.usp_TransitionException
    @ExceptionId = 44, @ToStatusCode = 'CLOSED', @ReasonText = N'Applicant has no other email address';
```
