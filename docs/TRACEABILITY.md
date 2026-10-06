# Traceability matrix

From each job requirement in the [blueprint](../BLUEPRINT.md) to the feature that answers it and
the evidence that it works. "Pending Windows session" marks Power BI work that needs Power BI
Desktop, which does not run on macOS ([steps](powerbi/WINDOWS-BUILD-STEPS.md)).

## Job requirement → feature → evidence

| Job requirement | Project feature | Test or documentation evidence |
|---|---|---|
| Strong T-SQL: joins, CTEs, window functions, set-based logic | Matching, reconciliation, census capture, FIFO aging (`reporting.fn_StudentAccountAging`), cumulative GPA (`reporting.vw_AcademicProgress`), IPEDS aggregates | tSQLt `MatchTests`, `ReconciliationTests`, `CensusTests`, `ReportingTests`, `ComplianceTests` |
| Recurring reports for departments | Six specified reports (R1 to R6) and eleven extract types on Agent schedules | [report-catalog.md](specifications/report-catalog.md); `ReportingTests`; `test_extracts_db.py` (every type against its contract) |
| Turn a request into a precise specification | A specification for each report, written before its SQL: owner, grain, populations, as-of behavior, measures, lineage, security class, controls, limitations | [report-catalog.md](specifications/report-catalog.md); commit history (specifications committed first) |
| Slate-to-SIS integration | Incremental landing, staging, nightly pipeline, idempotent outbound queue (Part 2) | `test_pipeline_db.py`; [nightly-integration runbook](runbooks/nightly-integration.md) |
| Deterministic record matching | Ordered rules, stored evidence, constraints against unsafe auto-merges (Part 2) | `MatchTests`; [matching-rules.md](specifications/matching-rules.md) |
| Exception reconciliation | Governed exception lifecycle; masked worklist with audited drill-through | `ExceptionTests`, `ReportingTests` (masking, drill-through audit); [exception runbook](runbooks/exception-reconciliation.md) |
| Data-quality controls | Eighteen metadata rules with owners, scorecard and dispositions | `DataQualityTests`, `AcademicConsistencyTests`; [data-quality-rules.md](specifications/data-quality-rules.md) |
| IPEDS reporting | Four IPEDS-aligned aggregate extracts (educational simulations) with NCES citations or labelled assumptions | [ipeds-measure-mapping.md](specifications/ipeds-measure-mapping.md); `ComplianceTests`; `test_extracts_db.py` |
| Reproducible institutional numbers | Immutable, rule-versioned census snapshots with checksums | [ADR-003](decisions/ADR-003-census-snapshots.md); `CensusTests`; `test_census_reporting_is_reproducible_after_the_source_changes` |
| Role-based access to student and financial data | Eight least-privilege roles, raw layers denied, masking, program-scoped row-level security, access and permission auditing | [security-model.md](architecture/security-model.md); `SecurityTests` (matrix equality, per-role probes, row-level security, audit) |
| Automated scheduling | Four SQL Server Agent jobs | `make agent-run` for each job in CI; [operations handbook](OPERATIONS-HANDBOOK.md) |
| Power BI reporting | `bi` star schema with data-as-of status; PBIP/TMDL model with measures and roles | `BiTests`, `test_powerbi_model.py`, `test_powerbi_db.py`. **Pages and screenshots: pending Windows session** |
| Execution-plan tuning | Planned for Part 4 | Not started |
| Version control, CI and deployment | SQL projects, DACPACs, GitHub Actions with a disposable SQL Server | [validate.yml](../.github/workflows/validate.yml); verification log |
| Operating documentation | Runbooks, operations handbook, data dictionary, glossary, ADRs | [docs/](.) |
| Responsible AI assistance | Every AI-assisted step logged and independently verified | [PROMPT-LOG.md](ai/PROMPT-LOG.md), [VERIFICATION-LOG.md](ai/VERIFICATION-LOG.md) |

## Part 3 acceptance criteria

| Criterion | Evidence | Status |
|---|---|---|
| Every metric has an owner, grain, inclusion rules, as-of behavior and source lineage | `compliance.MeasureDefinition` (leadership measures); [report-catalog.md](specifications/report-catalog.md) (report measures); [ipeds-measure-mapping.md](specifications/ipeds-measure-mapping.md) | Done |
| Reports run only through stable views and procedures and return consistent control totals | `reporting` and `compliance` objects; roles denied raw layers (`SecurityTests`); every extract's reconciliation controls pass on the seed (`test_extracts_db.py`) | Done |
| Census reports stay reproducible after underlying records change | `test_census_reporting_is_reproducible_after_the_source_changes`: the live data changes, but the census report and the IPEDS Fall Enrollment checksum do not | Done |
| Department users can access only their approved data products | `SecurityTests`: deployed permissions equal the matrix; each role reads its products and gets error 229 on raw layers and other departments' products; row-level security test | Done |
| Public dashboard screenshots contain no direct identifiers | The model imports only the masked `bi` schema (`test_no_direct_identifier_is_modelled`, `SecurityTests` column check); screenshot review checklist in the Windows steps | **Pending Windows session** (screenshots) |
| Extracts include batch ID, reporting period, generated time, row count, checksum and validation status | `compliance.ExtractRun`; manifest keys (`test_extract_contracts.py`); SQL checksum equals Python SHA-256 for every run | Done |

## Part 3 deliverables

| Deliverable | Where | Status |
|---|---|---|
| Six report specifications and SQL datasets | `docs/specifications/report-catalog.md`; `database/CampusDataOps.Database/reporting/` | Done |
| Immutable census snapshots | `compliance.CensusSnapshot*`; ADR-003 | Done |
| Four IPEDS-aligned aggregate mock extracts | `compliance.vw_IPEDS_*`; extract types `IPEDS_*` | Done |
| Extract-run manifest and control-total validation | `compliance.ExtractRun`, `ExtractControlTotal`; `campus-ops export` | Done |
| Custom roles and permissions test matrix | `Security/Roles`, `Security/Permissions`; `SecurityTests` | Done |
| Masked demo views and audit events | `security.vw_StudentMasked`, `reporting.vw_ExceptionWorklist`, `bi`; `audit.AccessEvent`, `audit.PermissionChangeEvent` | Done |
| Power BI project with seven report pages | Semantic model, measures and roles in `powerbi/` (text, statically tested) | Model done; **pages pending Windows session** |
| SQL Agent schedules for recurring extracts | `automation/sql-agent/03` to `05` | Done |
| Operations handbook and data dictionary | `docs/OPERATIONS-HANDBOOK.md`, `docs/DATA-DICTIONARY.md` | Done |
