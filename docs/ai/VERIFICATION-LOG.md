# Verification log

AI-generated code is treated as untrusted until it is independently checked. Each row records what
was produced, how it was checked, and what the check found. "Found" entries are defects caught by
the checks before commit.

## 2026-10-04: Part 1 foundation

Environment: macOS 15 on arm64; Docker Desktop 29.4 with Rosetta; SQL Server 2022 RTM-CU24-GDR
(16.0.4250.1) in Docker; .NET SDK 10.0.203; SqlPackage 170.5.96; Python 3.12; ODBC Driver 18.7.1.1.

| Artifact | Check | Result |
|---|---|---|
| SourceSystems and CampusDataOps SQL projects | `dotnet build` with T-SQL warnings treated as errors | 0 warnings, 0 errors |
| Both DACPACs | SqlPackage publish, then a second publish of the unchanged DACPACs | **Found:** every `IN (...)` and `BETWEEN` check constraint was dropped and re-created on each publish, because the engine stores them normalized and DacFx reports drift. **Fix:** constraints rewritten in explicit `OR`/range form. **Re-check:** second publish makes no object changes |
| Reference seed | Counts before and after a redeploy, including `MAX(UpdatedAtUtc)` | Identical, so the redeploy is idempotent and touches no rows |
| Source table keys | Design review of reseeding | **Found:** `IDENTITY` child keys would keep counting up after a delete-and-reload, so reseeds would not be byte-identical. **Fix:** generator assigns all source keys |
| Term calendar | Printed the instructional terms | **Found:** string comparison of term codes (`'2026SP' > '2026FA'`) dropped Spring and Summer 2026. **Fix:** date-based registration window |
| Source load | `make seed` into SQL Server | 61,000+ rows in 21 tables loaded in one transaction, and every key, foreign key and check constraint accepted them |
| Python ODBC connectivity | Connection from pyodbc | **Found:** Homebrew's `msodbcsql18` pulled in OpenSSL 4 and repointed the `openssl` alias, which ODBC Driver 18 cannot load. **Fix:** Makefile prefers keg-only `openssl@3` through `DYLD_LIBRARY_PATH` on macOS; system packages unchanged |
| Smoke test | `make smoke`; then run with a deliberately broken expectation | Passes on the real database and leaves no audit rows. The broken copy exits 1 and names the failing check |
| Unit tests | `pytest -m "not db"`: 74 tests | All pass. **Mutation check:** a planted census-date drift and a non-fictional phone prefix each made the expected test fail; both reverted |
| Database tests | `make test-db`: 10 tests | **Found:** landing procedure errors were never written to `audit.ErrorLog`, because `ERROR_PROCEDURE()` returns a schema-qualified name on SQL Server 2017+ while the guard compared it with `OBJECT_NAME(@@PROCID)`. **Fix:** compare against the schema-qualified name. **Re-check:** all 10 pass |
| Refactor of the academic simulation | Dataset fingerprint before and after | Unchanged (`194df81b…382c` at seed 20260901, scale 1.0), so behaviour is identical |
| Python style | `ruff check`, `ruff format --check` | Clean. `PLR2004` is ignored for generator probability literals, with the reason recorded in `pyproject.toml` |
| SQL style | `sqlfluff lint database` (T-SQL) | Clean. Four layout rules are excluded with reasons in `.sqlfluff`. RF01 is suppressed in one seed block whose correlated `EXCEPT` references SQLFluff cannot resolve |
| Repository hygiene | `pre-commit run --all-files` (includes gitleaks) | All hooks pass. **Found:** the hooks rewrote `BLUEPRINT.md` Markdown line breaks; the file was restored and excluded |
| CI workflow | YAML parse; `uv lock --check` | Valid. The workflow itself was **not** run here; first proof will be the GitHub Actions run on push |

## Part 1 hand-off checks (clean clone)

The database volume was deleted (`make clean CONFIRM=1`), the branch was cloned into a new
directory, and only `.env` was copied in.

| Acceptance criterion | Evidence | Result |
|---|---|---|
| A clean clone can start SQL Server, build DACPACs, deploy, generate source data and pass smoke tests | `make bootstrap` in the fresh clone | **First attempt found a defect:** in a long directory path, uv's console-script launcher becomes a `/bin/sh` trampoline and macOS SIP strips `DYLD_LIBRARY_PATH`, so the OpenSSL fix never reached Python. **Fix:** the Makefile runs `python -m`. **Re-run from a new clean clone:** exit 0 in 35 s (image already pulled) |
| Re-running setup is idempotent | Second `make bootstrap` | Exit 0 in 23 s, 0 schema objects created, altered or dropped, smoke test passed, dataset fingerprint unchanged |
| Every table has a primary key, appropriate types, nullability, defaults and documented purpose | SQL project build; `docs/architecture/erd.md`; table comments for non-obvious rules | 21 source tables and 9 CampusDataOps tables, each with a primary key and UTC audit timestamps |
| Synthetic data contains deliberate edge cases but no real student data | `test_edge_cases.py`, `test_safe_identifiers.py`, smoke test edge-case checks | 6 edge cases present; all emails `@example.com`; all phones `555-01xx`; no SSN-shaped values |
| Tests pass | `make test`, `make test-db`, `make lint` in the clean clone | 74 + 10 tests pass; Ruff, Ruff format and SQLFluff clean; no audit rows left behind |
| Secrets are absent from Git history | `gitleaks git` over all commits; `git log --all --name-only` | No leaks in 7 commits; `.env` never committed |

### Not verified here

- The GitHub Actions workflow has not run yet; it needs a push to GitHub.
- SqlPackage was run through its bundled .NET 8 build on the installed .NET 10.0.7 runtime, because
  the .NET 10 build needs runtime 10.0.11. Updating the .NET SDK removes the need for the override.

## 2026-10-04 to 2026-10-05: Part 2 integration and reconciliation

Environment as Part 1, plus tSQLt 1.0.8083.3529 (SHA-256 `af841f35…4f50`) installed into the
local CampusDataOps database.

| Artifact | Check | Result |
|---|---|---|
| tSQLt under Rosetta | Spike before any Part 2 code: install, fake a cross-database view, spy a procedure, run a `NoTransaction` test of a procedure that rolls back its own transaction | All worked; the approach (fake `landing.vw_Source*` views, spy the J1-Sim adapter, `NoTransaction` for error paths) was adopted |
| ADR-002 unchanged-row rule | Design review while writing the loaders | **Found:** "hash already landed for the key" would skip a value that changes A → B → A, leaving staging on B. **Fix:** compare with the latest landed version; ADR-002 amended; tSQLt regression test |
| Post-deployment seeds | `make deploy` | **Found:** the new seeds redeclared `@NowUtc` in the same batch as the Part 1 seed. **Fix:** `GO` between `:r` includes |
| Rule-disagreement check | `make deploy` | **Found:** error 8124, an aggregate mixing outer and inner columns. **Fix:** rewritten as `NOT EXISTS` |
| Landing and data-quality procedures | Manual runs and tSQLt | **Found:** "Null value is eliminated" warnings from `MAX(CASE …)` pivots and from aggregating after an outer join. **Fix:** ranked joins and aggregate-first. A `go-sqlcmd` client stalled once while a run produced many such warnings; it has not recurred since they were removed. The connection is probable, not proven |
| `make test-sql` | Running a test file with a compile error | **Found:** errors were hidden because sqlcmd writes them to stdout, which the target discarded. **Fix:** output shown and failures stop the target |
| Test design | First tSQLt runs | **Found:** test procedures that insert into multi-table views do not compile, and a test's own `FakeTable` runs after compilation. **Fix:** `SetFakeViewOn` around creation and fakes in `SetUp`. Two further test bugs (an `OUTPUT` parameter read after a throw; a comma-separated helper given a value containing a comma) were fixed in the tests, not the code |
| Recovery run errors | Code review | **Found:** a second recovery of the same run would have been reported as "a RUNNING batch already exists", because the batch-start procedure maps every duplicate-key error to that message. **Fix:** explicit pre-check with its own error |
| Smoke test | Ran the Part 1 version after landing a Slate-Sim change dated 2026-10-05 | **Found:** its fixed 2026-09-01 watermark is refused (error 50014, watermark cannot move backwards). **Fix:** round trip reaches one minute past the last watermark; the new version passes in the same state |
| SQL lint | Clean-clone `make lint` | **Found:** `.sqlfluff` declared one section twice, so sqlfluff exited with a config error without linting. Local checks had filtered output for violation lines and reported nothing, so this went unnoticed from the matching commit onward. **Fix:** merged the section and fixed the 19 hidden findings; lint is now run and judged by exit code |
| Matching safety | Mutation: let two email + birth date candidates auto-match | Three tSQLt tests failed (the ambiguous-match test and two that depend on its exception); restored. Database `CHECK` constraints are tested separately with `tSQLt.ApplyConstraint` |
| tSQLt suite | `make test-sql` | 72 tests, all pass (landing, normalization, staging, matching, exceptions, queue, reconciliation, data quality) |
| Python suites | `make test`, `make test-db` | 78 unit and 19 database tests pass; the 9 new end-to-end scenarios run in about 80 s |
| End-to-end on the default seed | `make nightly` twice from an empty platform | Run 1: 325 eligible, 247 created, 51 matched, 27 rejected, 298 confirmed in J1-Sim, balanced, about 7 s. Run 2: 298 unchanged, 27 rejected, no new decision, exception, queue, crosswalk or J1-Sim row |
| SQL Server Agent | `make agent-install`, `make agent-run` | Nine steps succeed; about 6 s from an empty platform |
| Failure and recovery | SourceSystems set READ_ONLY with a corrected applicant to send | Agent run 27 failed at PROCESS (50300); `audit.ErrorLog` held error 3906 from `J1Sim.usp_ReceiveAdmittedApplicant` against the batch and step; the row was `FAILED_RETRYABLE`. After READ_WRITE, recovery run 31 started at PROCESS by Agent wrote the record on attempt 2, reconciled, and closed the exception (OPEN → RESOLVED → RETRY_READY → REPROCESSED → CLOSED); one J1-Sim receipt for the application |
| Redeploy idempotency | SqlPackage DeployReport against both deployed databases, before and after the lint fixes | Empty reports: no object would be changed |
| Data-quality findings | Scorecard on the default seed | Planted cases found as specified. The generator also produces 36 active students without a directory account and 5 disbursements without a registered enrollment; these are reported as genuine findings in the synthetic data, not tuned away |

## Part 2 hand-off checks (clean clone)

The data volume was deleted (`make clean CONFIRM=1`), the branch was cloned into a new
directory and only `.env` was copied in.

| Check | Result |
|---|---|
| `make bootstrap`, then again | Exit 0 in 45 s and 25 s |
| `make test`, `make test-db`, `make test-sql` | All pass (78, 19 and 72 tests) |
| `make agent-install`, `make agent-run`, `make nightly`, `make smoke` | All pass; the Python rerun reconciles |
| `make lint` | **Failed** on the duplicated config section described above; fixed in the working repository and rerun there: exit 0 with no findings, then deploy, all test suites, the Agent job, a pipeline rerun and smoke passed again |

### Not verified here

- The extended GitHub Actions workflow (tSQLt download, Agent job, pipeline) has not run; it
  needs a push. SQL Server Agent must be running in the CI container before `make agent-run`.
- SqlPackage still needs the .NET 8 build override on this machine (see Part 1).
