# Applicant matching rules

**Owner:** Data Operations, with the Registrar as approver of identity decisions
**Implements:** `integration.usp_BuildApplicantMatchCandidates`, `integration.usp_ResolveDeterministicMatches`,
`integration.usp_ResolveExceptionMatch`
**Decision record:** [ADR-001](../decisions/ADR-001-deterministic-matching.md)

This specification decides, for every eligible Slate-Sim application, whether the applicant is an
existing J1-Sim person, a new person, or a case a person must review. Every decision is stored
with the rule that made it, the number of candidates and yes/no evidence flags, so anyone can
see why an applicant matched or failed without rerunning anything.

## Scope

An application is **eligible** for integration when all of these are true in `staging.Applicant`:

| Condition | Column |
|---|---|
| Current Slate-Sim status is `ADMITTED` or `DEPOSITED` | `ApplicationStatus` |
| Slate-Sim has queued it for the `ADMITTED_APPLICANT` export | `ExportQueuedAtUtc IS NOT NULL` |

An eligible application is **matched** only when it has no unresolved blocking validation
exception (see [integration-controls.md](integration-controls.md)) and has not already been
written to J1-Sim. Applications that are not eligible are never matched and are not counted by
reconciliation.

## Normalization (staging)

Normalization happens once, when a row is staged, and the normalized value is stored beside the
raw value. Match joins compare stored normalized columns; they never call functions.

| Value | Rule | Invalid result |
|---|---|---|
| Name (`fn_NormalizeName`) | Trim; collapse internal whitespace to one space; upper-case. Accents and punctuation are kept, so `O'Brien` and `OBrien` do **not** match | Empty becomes NULL |
| Email (`fn_NormalizeEmail`) | Trim; lower-case. Valid only with exactly one `@`, a non-empty local part, a domain that contains a dot and does not start or end with one, no spaces and no consecutive dots | Standardized email is NULL and `IsEmailValid = 0`; the raw value is kept |
| Phone (`fn_NormalizePhone`) | Keep digits only; drop a leading `1` from 11 digits | Anything other than 10 digits is NULL with `IsPhoneValid = 0` |
| Postal code | First five characters when they are five digits | NULL |
| SIS ID claim | The Slate-Sim `SIS_ID` external identifier, converted to an integer when it is exactly seven digits | NULL with `IsSisIdClaimValid = 0` |
| Birth date | Already typed `DATE` in both systems; compared exactly | — |

## Match hierarchy

Rules are evaluated for every application in scope and **all** candidates are stored. The
decision then comes from the highest-priority rule that produced candidates.

| Priority | Rule code | Evidence required | Confidence | Can auto-match |
|---|---|---|---|---|
| 1 | `CROSSWALK` | `integration.SourceCrosswalk` already links this Slate-Sim person to a J1-Sim ID number | `EXACT` | Yes, when unique |
| 2 | `SIS_ID` | Valid SIS ID claim equals a staged J1-Sim `IdNumber` | `EXACT` | Yes, when unique |
| 3 | `EMAIL_DOB` | Normalized email **and** birth date equal | `HIGH` | Yes, when unique |
| 4 | `NAME_DOB_POSTAL` | Normalized first and last name, birth date and five-digit postal code equal | `REVIEW` | **Never** |

Rule 4 is review-only because a shared name, birth date and postal code is exactly what twins or
two family members can have. No institutional policy approving it for automatic use exists in
this project.

## Decision table

Evaluate in order; the first row that applies is the decision.

| # | Situation | Decision type | Exception raised |
|---|---|---|---|
| 1 | Any identity conflict (next section) | `IDENTITY_CONFLICT` | `IDENTITY_CONFLICT` |
| 2 | The highest rule among 1-3 with candidates has two or more | `AMBIGUOUS` | `AMBIGUOUS_MATCH` |
| 3 | The highest rule among 1-3 with candidates has exactly one | `AUTO_MATCH` | — |
| 4 | Rules 1-3 have no candidates and rule 4 has one or more | `REVIEW_REQUIRED` | `POSSIBLE_MATCH_REVIEW` |
| 5 | No rule has candidates | `NEW_PERSON` | — |

An analyst can resolve rows 1, 2 and 4 only through `integration.usp_ResolveExceptionMatch`. That
writes a `MANUAL_MATCH` (a chosen ID number) or `MANUAL_NEW_PERSON` decision recording who decided
and when. For `AMBIGUOUS` and `REVIEW_REQUIRED` the chosen person must be one of the stored
candidates; for `IDENTITY_CONFLICT` it may be any staged J1-Sim person, because the analyst has
established the correct identifier outside the system.

A database `CHECK` on `integration.MatchDecision` enforces the safety rule independently of the
procedures: `AUTO_MATCH` requires exactly one candidate, a matched ID number and a rule of
`CROSSWALK`, `SIS_ID` or `EMAIL_DOB`.

## Identity conflicts

| Conflict code | Meaning |
|---|---|
| `CROSSWALK_TARGET_MISSING` | The crosswalk points to an ID number that is no longer a staged J1-Sim person |
| `SIS_ID_INVALID_FORMAT` | The applicant supplied a SIS ID that is not seven digits |
| `SIS_ID_NOT_FOUND` | The claimed SIS ID is not a J1-Sim person |
| `SIS_ID_BIRTH_DATE_MISMATCH` | The claimed SIS person has a different birth date |
| `SIS_ID_CLAIMED_BY_MULTIPLE` | Two or more Slate-Sim people claim the same SIS ID |
| `RULES_DISAGREE` | The deciding rule found one person, but a lower automatic rule found candidates that do not include that person |

## Re-evaluation

An application in scope is evaluated again when it has no current decision, when its staged
source hash changed since the current decision, or when its current decision is a blocked type
(`AMBIGUOUS`, `REVIEW_REQUIRED`, `IDENTITY_CONFLICT`), because a correction in J1-Sim can clear
those. A new decision row is written only when the result differs from the current decision, so
an unchanged rerun writes nothing. A source change after a manual decision supersedes it: the
analyst decided on values that no longer apply.

Once an application has been written to J1-Sim it is not matched again. Propagating later Slate-Sim
changes to J1-Sim is outside Part 2.

## What happens after a decision

| Decision | J1-Sim state of the person | Outbound action or outcome |
|---|---|---|
| `NEW_PERSON`, `MANUAL_NEW_PERSON` | — | `CREATE_PERSON_STUDENT` |
| `AUTO_MATCH`, `MANUAL_MATCH` | No student record | `CREATE_STUDENT` |
| `AUTO_MATCH`, `MANUAL_MATCH` | Student `INACTIVE`, `WITHDRAWN` or `GRADUATED` | `READMIT_STUDENT` |
| `AUTO_MATCH`, `MANUAL_MATCH` | Student `ACTIVE` | `ALREADY_MATRICULATED` exception; nothing is written |

The crosswalk row linking the Slate-Sim person to the J1-Sim ID number is written in the same
transaction as a successful J1-Sim write, so it always describes a confirmed link.

## Privacy

Match evidence is stored as flags (`MatchedOnSisId`, `MatchedOnEmail`, `MatchedOnBirthDate`,
`MatchedOnName`, `MatchedOnPostalCode`), never as copies of the values. Error messages raised by
the matching procedures contain identifiers only.
