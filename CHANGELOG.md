# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); milestones are tagged `v0.1-foundation`,
`v0.2-integration`, `v0.3-reporting` and `v1.0-release`.

## [Unreleased] - Part 3: reports, compliance and security

### Added

- Specifications before code: a report catalog (six reports), an IPEDS-aligned measure mapping
  with NCES citations or labelled assumptions, extract controls, ADR-003 (census snapshots) and
  the security model with a permission matrix.
- J1-Sim credential awards landed and staged. They are read in full until the first credential
  lands, because the existing watermark had already passed them.
- Conformed `core` views over staging, and governed reporting reference data (departments,
  divisions, the program catalog with IPEDS award levels, aid funds, aging buckets, standing
  rules).
- Immutable, rule-versioned census snapshots with checksums and verification.
- Six report datasets: census, aid packaging, account aging (first-in-first-out), academic
  progress, a masked exception worklist with audited drill-through, and leadership KPIs backed
  by `compliance.MeasureDefinition`.
- Extract runs for eleven types, with exact CSV lines, SHA-256, control totals, two-person
  approval, audited export and immutability; four IPEDS-aligned aggregate mock extracts.
- Eight least-privilege roles with raw layers denied, masked surrogate keys, program-scoped
  row-level security, `audit.AccessEvent` and a permission-change DDL trigger.
- `campus-ops generate-extract`, `export` (with suppressed public copies) and `run-schedule`;
  `make extracts`, `export`, `powerbi-model` and `data-dictionary`.
- Three SQL Server Agent jobs (daily operational reports, weekly quality report, census and
  compliance); `make agent-run JOB=...`.
- Two data-quality rules deferred from Part 2, and issue dispositions.
- A `bi` star schema with data-as-of status, and a PBIP/TMDL semantic model with measures and
  roles, generated and statically tested. **Not yet opened in Power BI Desktop**; report pages
  and screenshots are pending a Windows session (docs/powerbi/WINDOWS-BUILD-STEPS.md).
- tSQLt classes for core, census, reporting, compliance, security, BI and academic consistency
  (131 tests in total); Python extract contract, extract database and Power BI model tests.
- Data dictionary, operations handbook, access-request and recurring-report runbooks, and a
  traceability matrix.

### Changed

- Schema definition files moved to `Security/Schemas/`. The CampusDataOps project references
  the `master` DACPAC for catalog views.
- The Agent run-and-wait script takes a job name (`02_run_agent_job.sql`); `make agent-install`
  installs all four jobs.
- The STAGE step stages credentials and assigns student pseudonyms. The data-quality suite runs
  the academic consistency check. `dq.vw_CurrentDataQualityIssues` shows dispositions.
- CI runs the new Agent jobs and checks a suppressed public export.

## [0.2-integration] - Part 2: integration and reconciliation

### Added

- Append-only landing tables for Slate-Sim, J1-Sim (including account transactions and source
  control totals) and Directory-Sim, loaded incrementally through `landing.vw_Source*` views with
  watermarks and SHA-256 row hashes, one atomic batch per source.
- Staging normalization of applicants, SIS people, directory accounts, enrollments, aid and
  account transactions, keeping raw values beside standardized ones.
- Deterministic matching with stored candidates and evidence flags, a decision table, identity
  conflict detection and database constraints that reject unsafe automatic matches.
- Integration exceptions with a governed lifecycle, an action history whose transitions are
  foreign keys to the allowed set, analyst identity resolution and automatic retry.
- Outbound student queue with idempotency keys, per-row transactions, attempt limits and retry,
  and the simulated J1-Sim import interface `J1Sim.usp_ReceiveAdmittedApplicant` with receipts.
- Record, batch and entity reconciliation with a database-enforced outcome invariant and J1-Sim
  target confirmation.
- Sixteen metadata-driven data-quality rules, a scorecard and a current-issues view.
- Eight-step pipeline orchestration with explicit recovery runs, a SQL Server Agent job, a
  run-and-wait script and Python CLI commands (`nightly`, `recover`, `run-summary`, `reset-ops`).
- tSQLt harness (`make test-sql`, pinned and checksum-verified download) with 72 tests, and 9
  end-to-end pytest scenarios against the deployed databases.
- Specifications (matching rules, integration controls, data-quality rules), ADR-001, Part 2
  ERDs, an updated source-to-target mapping and three runbooks.

### Changed

- `audit.BatchRun` gains `ParentBatchId` and `RecoveryOfBatchId`; `audit.usp_LogError` returns the
  new `ErrorLogId`; batch-start procedures accept the new links.
- ADR-002 amended: unchanged rows are compared with the latest landed version of the key, and
  loads read at or after the watermark.
- Seeding clears J1-Sim integration receipts before replacing simulator data.
- CI runs the tSQLt suite, the end-to-end tests, the Agent job and a pipeline rerun.

### Fixed

- The smoke test's landing round trip used a fixed watermark that the database would reject
  once a later Slate-Sim change had landed.

## Part 1: foundation (merged to `main`)

### Added

- Docker Compose environment for SQL Server 2022 Developer with SQL Server Agent, health check and
  persistent volume.
- `SourceSystems` SQL project modelling Slate-Sim, J1-Sim and Directory-Sim (21 tables).
- `CampusDataOps` SQL project with ten schemas, governed reference tables and idempotent seed,
  `audit.BatchRun`, `audit.BatchStep`, `audit.ErrorLog`, batch logging procedures and landing
  batch-control procedures with control-total and watermark validation.
- Deterministic synthetic data generator (`campus-ops` CLI) with six documented edge cases.
- Post-deployment smoke test, pytest suites (generator, edge cases, safe identifiers, reference
  alignment, database load and procedure behaviour).
- Makefile with one-command `bootstrap`; GitHub Actions validation workflow; pre-commit hooks.
- Architecture, ERD, glossary, source-to-target mapping, ADR-002 and AI usage logs.
