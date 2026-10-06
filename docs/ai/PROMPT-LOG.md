# Prompt log

Summarized intent of each AI-assisted session, the files it affected and the human decisions that
shaped it. Verification evidence is in [VERIFICATION-LOG.md](VERIFICATION-LOG.md).

## 2026-10-04: Part 1 foundation (Claude Code, Claude Opus 5.5)

| Step | Human request or decision | AI output |
|---|---|---|
| 1 | Read BLUEPRINT.md; summarize the architecture; list Part 1 files and machine prerequisites; create nothing yet | Summary, file list and tool check (found sqlpackage, sqlcmd and ODBC Driver 18 missing) |
| 2 | Owner installed tools; chose repository name `campus-data-hub` everywhere and the MIT license; asked for an implementation plan before any files | Plan with design decisions, file list, build order and open questions |
| 3 | Owner: "do what's best". Accepted defaults: Ruff instead of Black, a feature branch with step commits, and a workaround for the SqlPackage .NET runtime mismatch instead of changing the machine | Implementation of Part 1 on branch `feat/part-1-foundation` |

### Files affected

`docker-compose.yml`, `Makefile`, `campus-data-hub.sln`, `database/**`, `pipelines/campus_ops/**`,
`tests/python/**`, `.github/workflows/validate.yml`, `.pre-commit-config.yaml`, `.sqlfluff`,
`pyproject.toml`, `uv.lock`, root documents and `docs/**`. `BLUEPRINT.md` was not modified.

### Deviations from the blueprint, with reasons

| Blueprint | Implemented | Reason |
|---|---|---|
| `CampusDataOps.sln` | `campus-data-hub.sln` | Owner decision: one name everywhere |
| Ruff + Black | Ruff for lint and format | Ruff's formatter is Black-compatible; one tool and one version |
| `pipelines/scripts/generate_synthetic_sources.py` | `campus-ops` console command | A wrapper script would duplicate the CLI |
| JSON fixtures in `tests/fixtures/` | Edge cases generated in code with fixed identifiers | Nothing consumes JSON fixtures until Part 2 loaders exist |
| `Pre-Deployment.sql` | Not created | No pre-deployment action is needed yet; an empty script would be a placeholder |
| Generators: people, academics, financial_aid, student_accounts, edge_cases | Also `admissions.py`, `directory.py`, `calendar.py`, `common.py`, `records.py`, `dataset.py` | One module per source domain plus shared building blocks |
| Status values as strings | `reference.BatchStatus` and `reference.BatchStepStatus` lookup tables with foreign keys | Blueprint guardrail against magic status strings |

## 2026-10-04 to 2026-10-05: Part 2 integration and reconciliation (Claude Code, Claude Opus 5.5)

| Step | Human request or decision | AI output |
|---|---|---|
| 1 | Read BLUEPRINT.md, the verification log and the README; present the Part 2 plan; write nothing until approved | Plan with four decisions, ten invariants, an object-level change list, a test plan, build order and an acceptance-criteria-to-evidence table |
| 2 | Owner: "go", accepting the recommendations: T-SQL loaders through a database reference, a pinned and checksum-verified tSQLt download, the `core` layer deferred to Part 3, and `READMIT_STUDENT` for returning former students | Implementation on branch `feat/part-2-integration` in small commits, specifications first |
| 3 | Owner approved the specific download of `tSQLt_V1.0.8083.3529.zip` (668,138 bytes, tsqlt.org) before it happened | Download, SHA-256 recorded in the Makefile, spike proving tSQLt works under Rosetta and can fake the cross-database views |

### Files affected

`database/CampusDataOps.Database/**` (landing, staging, integration, dq, audit and reference
objects; seeds; smoke test; reset script), `database/SourceSystems.Database/J1Sim/**` (import
interface and receipt table), `database/CampusDataOps.Tests/**`, `automation/sql-agent/**`,
`pipelines/campus_ops/{db,pipeline,cli,source_writer}.py`, `tests/python/test_pipeline*.py`,
`Makefile`, `.sqlfluff`, `.gitignore`, `.github/workflows/validate.yml`, `README.md`,
`CHANGELOG.md`, `SECURITY.md` and `docs/**`. `BLUEPRINT.md` was not modified.

### Deviations from the blueprint, with reasons

| Blueprint | Implemented | Reason |
|---|---|---|
| `pipelines/campus_ops/loaders/*.py`, `batch.py`, `watermarks.py` | T-SQL loaders (`landing.usp_Load*`, `usp_RunLandingLoad`) and `pipeline.py` | The SQL Server Agent job runs inside the container, which has no Python; Python calls the same procedures |
| `CampusDataOps.Tests.sqlproj` | tSQLt test classes as scripts in `database/CampusDataOps.Tests/Tests/` | tSQLt objects must never ship in the CampusDataOps DACPAC |
| `core` tables and procedures in the integration flow | Deferred to Part 3; matching uses `staging.Person` | Reports are the first consumer of `core` |
| `integration.usp_CreateIntegrationExceptions` | `usp_RaiseValidationExceptions`, `usp_RaiseIdentityExceptions`, `usp_RecordExceptionConditions` | One set-based procedure owns raise, refresh, resolve and reopen; callers only describe conditions |
| `staging.usp_StageJ1Students`, `vw_NormalizedApplicant`, `vw_NormalizedPerson` | `usp_StageJ1People` plus one procedure per J1-Sim entity; normalized values stored in staging tables | Normalizing once and storing the result keeps functions out of match joins |
| `integration.MatchCandidate` only | Adds `MatchEvaluation` | Ties candidates and decisions to the run and source version they came from |
| `integration.ReconciliationResult` only | Adds `ReconciliationDetail` and `ReconciliationEntityCount` | Record and entity levels requested by the Part 2 prompt |
| `dq.IssueDisposition`; checks for duplicates, enrollment and cross-system consistency | Disposition deferred to Part 3; adds `dq.RuleExecution` and `usp_CheckApplicantRules`, `usp_CheckFinancialAidPeriods`, `usp_CheckAccountControlTotals` | Pass rates need evaluated counts; the Part 2 rule list needs applicant, aid-period and detail-to-total checks; disposition belongs with the Part 3 dashboard |
| Matching hierarchy row 4 "candidate requiring review" | New exception reason `POSSIBLE_MATCH_REVIEW` | No existing reason described a review-only match |
| `04_create_alerts_operators.sql` | Not created; NOTIFY fails the step when a run does not reconcile | Database Mail and operators are configured with the Part 3 alerts |
| `landing.*Raw` for six entities | Adds `J1AccountTransactionRaw` and `J1AccountControlTotal` | J1-Sim has no balance table; detail-to-total reconciliation needs source-side totals |
