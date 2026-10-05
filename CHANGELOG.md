# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); milestones are tagged `v0.1-foundation`,
`v0.2-integration`, `v0.3-reporting` and `v1.0-release`.

## [Unreleased] - Part 2: integration and reconciliation

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
