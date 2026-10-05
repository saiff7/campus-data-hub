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
