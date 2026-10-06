# ADR-001: Deterministic, explainable person matching

- **Status:** Accepted
- **Date:** 2026-10-04
- **Context owner:** Data Operations, with the Registrar

## Context

Admitted Slate-Sim applicants must become J1-Sim students. Some applicants are already J1-Sim
people: former students reapplying, or people who were in the SIS but never enrolled. Linking an
applicant to the wrong SIS person merges two people's education records, which is a privacy
incident and is expensive to undo. Creating a second record for an existing person is cheaper
to fix but still causes duplicate transcripts, aid and billing.

The data contains the cases that make this hard: twins who share a family email and birth date,
applicants who supply an SIS ID that belongs to someone else, and SIS duplicates that share name,
birth date and address.

## Decision

Match with an **ordered set of exact rules** on normalized values (crosswalk, SIS ID, email plus
birth date), auto-processing only a **unique** result. Name plus birth date plus postal code is
**review-only**. Multiple candidates, or rules that point to different people, create an exception
for a person to decide. Every decision stores the rule, candidate count, evidence flags, decision
type, actor and time. The rules are specified in
[matching-rules.md](../specifications/matching-rules.md).

The safety rule is enforced by a database `CHECK` constraint on `integration.MatchDecision`, not
only by procedure logic.

## Consequences

**Positive**

- Every outcome can be explained in one sentence from stored columns.
- Ambiguous and conflicting records cannot auto-merge, even if a procedure is changed incorrectly.
- Rules are testable with small fixtures; tSQLt covers each row of the decision table.

**Negative**

- Some true matches go to review that a fuzzy matcher would have accepted: typos in names or
  emails, a move to a new postal code. This is a deliberate trade of analyst time for safety.
- Normalization is intentionally narrow (case and whitespace only), so formatting differences in
  names are not reconciled automatically.

## Alternatives considered

| Alternative | Why rejected |
|---|---|
| Weighted or probabilistic scoring | Produces an unexplained number; a threshold silently decides merges, and the blueprint forbids storing only a score |
| Fuzzy name matching (Soundex, edit distance) for automatic merges | Raises false merges for families and common names; acceptable later only as a review aid |
| Email alone | Shared family emails are in the data; email is not a unique personal identifier |
| Always create a new person | Duplicates every returning student and pushes the problem to the Registrar |
