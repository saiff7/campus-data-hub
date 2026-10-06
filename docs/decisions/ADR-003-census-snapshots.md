# ADR-003: Census reporting reads immutable snapshots

- **Status:** Accepted
- **Date:** 2026-10-05
- **Context owner:** Institutional Research and the Registrar

## Context

Census counts are official numbers. Once the Registrar certifies a fall headcount, it goes into
state and federal reports and leadership decks. Source records keep changing after census:
late drops, program changes, corrected birth dates. A report that queries current data
therefore gives a different "census" headcount every time it is run. ADR-002 keeps every landed
version, but rebuilding census-day state from landing history on every report would be slow,
and its correctness would depend on watermark timing.

## Decision

1. `compliance.usp_CaptureCensusSnapshot` copies the census population of one term into
   `compliance.CensusSnapshotEnrollment`, with a header row in `compliance.CensusSnapshot`. The
   header records the term, census date, **rule version**, source nightly batch, the source
   watermark of that batch, capture time and user, counts, credit total, and a SHA-256 checksum
   of the rows.
2. A snapshot is unique per (term, rule version), which a unique constraint enforces. Capturing
   again returns the existing snapshot and writes nothing.
3. Snapshots are immutable. `INSTEAD OF UPDATE, DELETE` triggers on both tables raise an error.
   No role is granted write access, and `compliance.usp_VerifyCensusSnapshot` recomputes the
   checksum to prove the rows are unchanged.
4. Capture is refused before the census date, while a nightly run is `RUNNING`, or if no nightly
   run has ever succeeded.
5. Business rules that change the population (for example, the full-time threshold) live in
   `compliance.CensusRuleVersion`. Changing them means a **new rule version** and a new
   snapshot beside the old one, never a rewrite.
6. Census-based reports, the leadership census measures and the IPEDS Fall Enrollment extract
   read only snapshots. Without a snapshot they raise an error or report `NO_SNAPSHOT`; they
   never fall back to live data.

## Consequences

**Positive**

- A census report gives the same answer next year as it does today.
- Each snapshot names the batch and watermark it was built from, which connects it to the landed
  rows (ADR-002).
- Rule changes are visible as versions, never as silent drift.

**Negative**

- A snapshot captured late reflects data as of its capture, not as of the census date.
  `CaptureLagDays` shows this. For the historical terms in the synthetic dataset, the first
  capture is necessarily late, and the runbook tells IR to note it.
- Storage grows by one row per student per term per rule version. Volumes here are small.
  Retention is covered in the operations handbook.
- Correcting a wrong census needs a new rule version or a documented, approved exception. That
  is deliberate, because certified numbers should be hard to change.

## Alternatives considered

| Alternative | Why rejected |
|---|---|
| Query current data with an as-of filter | Status history is incomplete in the source, and the answer changes as late corrections arrive |
| Rebuild census state from landing history on demand | Correct only if every change was landed before census; slow; hard to explain |
| System-versioned temporal tables on staging | Keeps platform-time history but not certified, rule-versioned populations, and temporal history can be altered by turning versioning off |
