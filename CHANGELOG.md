# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); milestones are tagged `v0.1-foundation`,
`v0.2-integration`, `v0.3-reporting` and `v1.0-release`.

## [Unreleased] - Part 1: foundation

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
