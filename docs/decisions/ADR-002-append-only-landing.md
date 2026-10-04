# ADR-002: Landing data is append-only

- **Status:** Accepted
- **Date:** 2026-10-04
- **Context owner:** Data Operations

## Context

CampusDataOps receives data from three systems it does not control. Records change after they
are first sent: applicants correct their email, the Registrar fixes a birth date, a student's
status changes. The platform must be able to:

1. Explain exactly what a source said at the time a decision was made (a match, an exception or a
   census count).
2. Rerun a failed or questioned batch and get the same result.
3. Reproduce historical reports after the source has moved on.
4. Detect when a source resends unchanged data, so reruns do not create duplicate students,
   exceptions or outbound messages.

If landing tables were updated in place (overwrite with the latest source value), the platform
would lose the evidence behind earlier decisions. Reconciliation would then compare against
values that no longer match what was processed.

## Decision

Landing tables are **append-only**. Each load inserts new rows tagged with `BatchId`,
`SourceSystemCode`, `SourceRecordId`, `SourceUpdatedAt`, `IngestedAt` and a SHA-256 `RecordHash`
of the business columns. Landing rows are never updated or deleted by pipeline code.

- A row whose `SourceRecordId` and `RecordHash` already exist is counted as **unchanged** and is not
  inserted again. Rows read must equal inserted + unchanged + rejected;
  `landing.usp_EndLandingBatch` refuses to close a successful batch that does not balance.
- Cleanup (standardization, typing, deduplication) happens in `staging`, which keeps the original
  value next to the standardized one. Nothing is silently corrected in landing.
- The incremental watermark advances only when a batch succeeds and never moves backwards. Both
  rules are enforced in the database (`usp_EndLandingBatch`, `CK_audit_BatchRun_WatermarkForward`),
  not only in Python.
- Only one batch per source can be `RUNNING` at a time, enforced by the filtered unique index
  `UX_audit_BatchRun_OneRunningPerProcess`.

## Consequences

**Positive**

- Every downstream decision can be traced to the exact landed row and batch.
- Reruns are safe: duplicate deliveries are recognized by hash rather than re-inserted.
- Census snapshots (Part 3) can be tied to the batches they were built from.

**Negative**

- Storage grows with every change. Mitigation: retention rules by batch age, documented with the
  operations handbook in Part 3; the synthetic volumes here are small.
- Queries for "current" source state need a latest-row-per-key pattern. Mitigation: staging
  carries the current standardized row, so reports never read landing directly.
- Correcting a bad load means landing a new corrected batch, not editing history. This is
  deliberate, because the bad batch stays visible for audit.

## Alternatives considered

| Alternative | Why rejected |
|---|---|
| Overwrite landing in place | Destroys the evidence for earlier matches, exceptions and census counts |
| Temporal (system-versioned) landing tables | Keeps history, but records platform time rather than batch identity. Hash-based unchanged detection would still be needed, and it complicates bulk loads |
| Change Data Capture on the sources | The real sources are vendor systems the college cannot instrument; the simulation must not assume database-level access |
