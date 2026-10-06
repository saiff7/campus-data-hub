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

## 2026-10-05 to 2026-10-06: Part 3 reports, compliance and security (Claude Code, Claude Opus 5.5)

| Step | Human request or decision | AI output |
|---|---|---|
| 1 | Read the verification and prompt logs; start Part 3 on a new branch from `main` | Branch `feat/part-3-reporting`; a plan with four decisions (D1 IPEDS demographics, D2 Power BI on macOS, D3 `core` as views, D4 T-SQL Agent jobs with Python file delivery), invariants, an object list and a build order. Nothing written before approval |
| 2 | Owner: "go", accepting D1, D3 and D4. D2 changed: build everything checkable on the Mac (star-schema views, tSQLt, `Measures.dax`, `RLS-Roles.md`, TMDL/PBIP text marked "not yet opened in Power BI Desktop"), write `docs/powerbi/WINDOWS-BUILD-STEPS.md`, do not block `v0.3-reporting` on screenshots, and mark them "pending Windows session" in the traceability matrix | Implementation in small commits, specifications first. NCES 2024-25 survey materials were read and cited in the IPEDS mapping; anything not confirmable was labelled an assumption |

### Files affected

`database/CampusDataOps.Database/**` (landing and staging for credentials; `core`, `reporting`,
`compliance`, `security`, `bi`, `audit` and `dq` objects; seeds; the smoke and reset scripts),
`database/CampusDataOps.Tests/**`, `automation/sql-agent/**`, `pipelines/campus_ops/{cli.py,extracts/**}`,
`tests/python/test_{extract_contracts,extracts_db,powerbi_model,powerbi_db,reference_alignment}.py`,
`powerbi/**`, `sample-output/**`, `docs/**`, `Makefile`, `.sqlfluff`,
`.github/workflows/validate.yml`, `README.md`, `CHANGELOG.md` and `SECURITY.md`. `BLUEPRINT.md` was
not modified.

### Deviations from the blueprint, with reasons

| Blueprint | Implemented | Reason |
|---|---|---|
| `core` tables and `usp_Upsert*` procedures | `core` views over staging | Decision D3: staging already holds one current standardized row per entity; snapshots provide reproducibility |
| `usp_GenerateIPEDSExtract` and per-domain Python extract modules | One `compliance.usp_GenerateExtract` with a builder per type, and one Python export module with typed contracts | Every extract gets the same run record, checksum, controls, approval and audit |
| `tests/contracts/*.schema.json` | `campus_ops.extracts.contracts` (typed columns) | The contracts are checked against the database headers and every exported value |
| `security.fn_UserDataScope`, `StudentDataPolicy` | `fn_ProgramScopePredicate`, `ProgramScopePolicy`, an eighth role `role_program_coordinator` | The blueprint asks for one justified scenario: coordinators limited to their own programs |
| Power BI star schema in `reporting` | Separate `bi` schema | One schema-level grant for the Power BI identity, and a column test over the whole schema |
| `02_create_recurring_reports_job.sql`, `03_create_weekly_dq_job.sql` | `03_create_daily_reports_job.sql`, `04_create_weekly_quality_job.sql`, `05_create_census_compliance_job.sql`; `02` is now a generic run-and-wait script | Part 2 already used `02` for the runner; a census job was needed for snapshots |
| PowerShell wrappers | Not created | Make, the CLI and Agent cover the same operations; no Windows host runs the platform |
| Power BI project with seven pages and screenshots | Semantic model, measures and roles as tested text; pages and screenshots pending a Windows session | Owner decision D2: Power BI Desktop does not run on macOS |
| Security administrators manage membership through a procedure | The procedure, plus `ALTER` on each department role for `role_security_admin` | The procedure borrows no privilege, so audits record the real caller |
