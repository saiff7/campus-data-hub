# IPEDS-aligned measure mapping

**Owner:** Institutional Research
**Implements:** `compliance.vw_IPEDS_*` views and extract types `IPEDS_FE`, `IPEDS_E12`, `IPEDS_C` and
`IPEDS_SFA`

> **Educational simulation.** These extracts borrow the structure of four IPEDS survey
> components to show how institution-level aggregates can be traced to student-level records
> and checked with control totals. They are **not** IPEDS submissions and are not ready to
> submit. The synthetic source has no sex, gender or race/ethnicity data, so every IPEDS
> breakdown that needs them is left out. NCES collects aggregate institution-level data, so
> the student-level working detail stays internal (the census snapshot and the extract run's
> control totals) and only aggregates leave the database.

## Sources

Each rule below either cites one of these documents or is labelled **Assumption: requires IR
approval**. The citations refer to the 2024-25 survey materials as read on 2026-10-05.

| Ref | Document |
|---|---|
| [EF] | NCES, *2024-25 Survey Materials: Fall Enrollment* (overview, instructions and glossary). <https://nces.ed.gov/Ipeds/use-the-data/download-survey-material/2024/fall%20enrollment/package_6_74.pdf> |
| [E12] | NCES, *2024-25 Survey Materials: 12-month Enrollment for public 2-year institutions*. <https://nces.ed.gov/Ipeds/use-the-data/download-survey-material/2024/12-month%20enrollment/package_9_110.pdf> |
| [C] | NCES, *2024-25 Survey Materials: Completions*. <https://nces.ed.gov/Ipeds/use-the-data/download-survey-material/2024/completions/package_10_80.pdf> |
| [SFA] | NCES, *2024-25 Survey Materials: Student Financial Aid*. <https://nces.ed.gov/ipeds/use-the-data/download-survey-material/2024/student%20financial%20aid/package_7_18.pdf> |

The [EF] and [SFA] packages read were variants for other institution types or reporting
calendars (4-year degree-granting, and full-year-cohort program reporters). The definitions
used here appear in their shared glossary. Before relying on any of this, IR must confirm the
rules against the package for a public 2-year academic-year reporter.

## Institution profile used

| Item | Value | Basis |
|---|---|---|
| Calendar | Semester, academic-year reporter | Simulator design; [EF] overview defines academic reporters |
| Level | Undergraduate only | J1-Sim programs are certificates and associate degrees |
| Degree/certificate-seeking | Every J1-Sim student is in a program, so all are degree/certificate-seeking. Non-degree applicants are never integrated | Simulator design |

## IPEDS_FE: Fall Enrollment (mock)

**Period:** a fall term code, for example `2026FA`. **Source:** the fall term's census snapshot
(current rule version). It does not read live data.

| Rule | Implementation | Basis |
|---|---|---|
| Count date | Academic reporters count enrollment as of the institution's official fall reporting date or October 15. This project uses the term's census date as the official reporting date | [EF] overview; using census as the official date is an **Assumption: requires IR approval** |
| Full-time | 12 or more semester credits | [EF] glossary, "Full-time student" |
| Part-time | Fewer than 12 semester credits | [EF] glossary, "Part-time student" |
| Student category | `ENTERING` when the entry term is this fall or the summer before it; otherwise `CONTINUING` | [EF] glossary counts students who first attended in the prior summer as first-time in fall. The source cannot tell first-time from transfer-in students, so `ENTERING` merges the two: **Assumption: requires IR approval** |
| Residency group | `INTERNATIONAL` residency is reported as a proxy for U.S. Nonresident | [EF] defines U.S. Nonresident by visa status. Residency code is not visa status: **Assumption: requires IR approval** |
| Age bands | Under 18, 18-19, 20-21, 22-24, 25-29, 30-34, 35-39, 40-49, 50-64, 65 and over, as of the count date | [EF] Part B categories and "report student age as of the official fall reporting date". [EF] requires Part B only in odd-numbered years; this extract always produces it |
| Not produced | Race/ethnicity and gender (Part A breakdowns), retention, student-to-faculty ratio, distance education | No source data |

**Columns:** `ReportingPeriod, Section, AttendanceStatus, StudentCategory, ResidencyGroup, AgeBand, Headcount`.
`Section` is `PART_A` (attendance × category × residency group), `PART_B` (attendance × age band)
or `TOTAL`.

**Controls:** `PART_A` sum = `TOTAL`; `PART_B` sum = `TOTAL`; `TOTAL` = the snapshot's included
student count, which is computed independently; prior-fall change within threshold (warning).

## IPEDS_E12: 12-month Enrollment (mock)

**Period:** an academic year `YYYY-YYYY`, meaning 1 July of the first year to 30 June of the
second. **Source:** `core` enrollment data. The period has closed before the extract is due, so
the extract run's stored rows are the record.

| Rule | Implementation | Basis |
|---|---|---|
| Reporting period | Terms whose start date falls between 1 July and 30 June | [E12]: "All institutions must use the July 1 - June 30 reporting period" |
| Unduplicated headcount | Each student counted once for the period | [E12] overview |
| Enrolled | At least one `REGISTERED` or `WITHDRAWN` section in a term of the period. Dropped sections do not count | **Assumption: requires IR approval** (the source has no course-level census for summer and spring in this extract) |
| Attendance status and category | Taken from the student's first term in the period: full-time at 12 or more credits in that term; `ENTERING` when that term is the entry term | **Assumption: requires IR approval** |
| Instructional activity | Credit hours attempted: the sum of credits of counted sections | [E12] Part B: instructional activity reported in credit hours. NCES estimates FTE for 4-year institutions only, so no FTE is produced |
| Not produced | Race/ethnicity and gender breakdowns, dual-enrollment (high school) counts | No source data |

**Columns:** `ReportingPeriod, Section, AttendanceStatus, StudentCategory, Headcount, CreditHours`.

**Controls:** full-time + part-time = total; total credit hours = the sum over counted sections in
`core`; the 12-month total must be **at least** the fall census headcount in the same academic
year. That last check is cited: [E12] says "The 12-month unduplicated count must be equal or
greater than the corresponding prior year fall enrollment". It **fails** (not warns) when broken.

## IPEDS_C: Completions (mock)

**Period:** an academic year `YYYY-YYYY`, meaning awards dated between 1 July and 30 June.

| Rule | Implementation | Basis |
|---|---|---|
| Reporting period | `AwardedDate` between 1 July of the first year and 30 June of the second | [C] overview |
| Field of study | The program's 6-digit CIP code (`NN.NNNN`) | [C] collects by 6-digit CIP and award level |
| Award level | Associate degree → level `3`. A certificate of at least 30 but fewer than 60 semester credits → level `2`. A certificate of 9–29 semester credits → level `1b`. These come from `reference.AcademicProgram.RequiredCredits` | [C] award-level definitions |
| Awards | One count per credential (first major only; the source has no second majors) | [C] |
| Completers | Unduplicated students earning any award in the period, in total and by award level | [C] "All Completers": count each student once |
| Not produced | Race/ethnicity and gender, distance-education flags | No source data |

**Columns:** `ReportingPeriod, Section, CipCode, AwardLevel, AwardCount`. `Section` is `AWARDS`
(per CIP and level), `COMPLETERS_BY_LEVEL` (CIP `ALL`) or `COMPLETERS_TOTAL`.

**Controls:** `AWARDS` sum = credentials in `core.vw_Credential` for the period, counted
independently; completers ≤ awards; prior-year change within threshold (warning).

## IPEDS_SFA: Student Financial Aid (mock)

**Period:** an aid year `YYYY-YYYY`.

| Rule | Implementation | Basis |
|---|---|---|
| Group 1 | Every undergraduate enrolled during the aid year: the `IPEDS_E12` population for the same academic year | [SFA] Group 1, all undergraduates; using the 12-month population is an **Assumption: requires IR approval** |
| Group 2 | Full-time `ENTERING` students included in the fall census snapshot of the aid year | [SFA] Group 2 is full-time, first-time degree/certificate-seeking students. Treating `ENTERING` as first-time inherits the Fall Enrollment **Assumption** |
| Aid counted | Awards with status `ACCEPTED` in the aid year; the amount is `AcceptedAmount` | [SFA] counts students "awarded (and who accepted)" aid |
| Federal Pell Grant | Fund `PELL` | [SFA] |
| Federal loans to students | Funds `DIRECT_SUB` and `DIRECT_UNSUB`. PLUS and other loans not made to the student are excluded (none exist in the source) | [SFA]: include Subsidized and Unsubsidized Direct Loans; "Do not include PLUS loans" |
| Any grant or scholarship | Funds `PELL`, `SEOG`, `MASSGRANT` and `INST_SCHOL` (`reference.AidFund.FundType = 'GRANT'`) | [SFA] grant categories; classifying institutional scholarships as grant aid follows [SFA] |
| Average amount | Total amount ÷ recipients, rounded to whole dollars | [SFA] averages are amount ÷ students |
| Not produced | Net price, military benefits, income bands, Groups 3 and 4 | No source data |

**Columns:** `ReportingPeriod, StudentGroup, AidType, RecipientCount, TotalAmount, AverageAmount`.
For every group a `COHORT` row gives the group size.

**Controls:** for each aid type, recipients ≤ cohort; Group 2 cohort ≤ Group 1 cohort; Group 1
Pell total = accepted Pell for Group 1 students, summed independently from `core.vw_AidAward`.

## Approval

Every IPEDS extract run starts with approval status `PENDING`. An `role_ir_analyst` member
other than the requester approves it with `compliance.usp_ApproveExtract`. A run that failed
validation cannot be approved ([extract-controls.md](extract-controls.md)).
