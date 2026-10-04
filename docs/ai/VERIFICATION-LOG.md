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
| End-to-end bootstrap | `make clean CONFIRM=1` followed by `make bootstrap` | Recorded in the Part 1 hand-off, below |

## Part 1 hand-off checks

Recorded after the final end-to-end run (see the commit that adds this section).
