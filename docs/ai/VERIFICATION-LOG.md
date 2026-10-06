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

### GitHub Actions (PR #2 and merge to `main`)

The extended workflow needed two fixes before it passed; both failures were in test tooling,
not in the database code.

| Run | Commit | Result |
|---|---|---|
| PR run 37388369351 | `1453c55` | **Found:** 12 of 72 tSQLt tests errored: "INSERT failed because the following SET options have incorrect settings: 'QUOTED_IDENTIFIER'". CI uses the classic ODBC `sqlcmd`, which defaults `QUOTED_IDENTIFIER` OFF (go-sqlcmd, used locally, defaults it ON). Test procedures keep the setting they were created with, and inserts into tables with filtered indexes or persisted computed columns require it ON. Reproduced locally by creating `QueueTests` with the setting OFF. **Fix** (`212109a`): every `sqlcmd` call passes `-I` |
| PR run 37388992282 | `212109a` | All 72 tSQLt tests passed. **Found:** the JUnit export then failed: the classic `sqlcmd` refuses `-h -1` with `-y 0`. **Fix** (`69e7185`): keep `-y 0` and strip the header by keeping output from the first line that starts with `<`; verified locally that the file parses with 72 tests |
| PR run [37389693378](https://github.com/saiff7/campus-data-hub/actions/runs/37389693378) | `69e7185` | All 4 checks green: lint and unit tests, secret scan, DACPAC build, and the disposable SQL Server job, in which bootstrap, the idempotent rerun, the Python database tests (including the end-to-end pipeline scenarios), tSQLt, the results upload, the SQL Server Agent job, the Python pipeline rerun and the smoke test all succeeded |
| `main` run [37391850922](https://github.com/saiff7/campus-data-hub/actions/runs/37391850922) | merge commit `844c212` | Same 4 checks and the same steps, all green |

This confirms on Linux what had only been verified locally: SQL Server Agent was running in the
CI container in time for `make agent-run`, the pinned tSQLt download verified and installed, and
the full pipeline ran and reconciled on a disposable server.

### Not verified here

- SqlPackage still needs the .NET 8 build override on this machine (see Part 1); CI uses the
  current .NET 10 build directly.

## 2026-10-05 to 2026-10-06: Part 3 reports, compliance and security

Environment as Part 2, plus `Microsoft.SqlServer.Dacpacs.Master` 160.2.8 (catalog view
references). NCES 2024-25 IPEDS survey packages (Fall Enrollment, 12-month Enrollment for
public 2-year institutions, Completions and Student Financial Aid) were read on 2026-10-05.
They were extracted locally from the PDFs, because a summarizing fetch returned vague text.

| Artifact | Check | Result |
|---|---|---|
| Credential landing | Deploy onto the Part 2 database, then `make nightly` | **Found:** 0 of 139 credentials landed, because the J1-Sim watermark had already passed every credential's timestamp. An entity added to an existing source never receives its history, and a fresh environment would hide this. **Fix:** read every credential until the first one lands (the hash comparison keeps that safe), and never move the batch watermark below the previous one. **Re-check:** 139 landed; the rerun landed 0; the watermark was unchanged |
| Census snapshot constraint | tSQLt `ApplyConstraint` test | **Found:** an excluded row with a NULL reason was accepted. Comparisons with NULL are UNKNOWN, and a `CHECK` passes on UNKNOWN. **Fix:** `IS NOT NULL` stated explicitly; the same care was taken in every later `CHECK` |
| Test design | First census tests | **Found:** a `SetUp` that both fakes a view and inserts into it compiles before the fake exists (error 4406), even with `SetFakeViewOn`. **Fix:** inserts moved to helper procedures |
| SQL lint | `sqlfluff` after the first report commit | **Found:** a check filtered through `tail` hid AM04 findings, and one commit went in with lint failing (the Part 2 lesson, repeated). **Fix:** the findings were fixed in the same unpushed commit; from then on lint was judged only by its exit code, before each commit |
| Real census capture | Seven historical terms | Captured with `CaptureLagDays` from 20 to 750 days (late captures by design; ADR-003 and the runbook say so); checksums verify |
| Reports on the seed | Control invariants | Aid offered = `core` total (4,963,250.00); aging net = `core` net (2,319,491.20); the bucket invariant holds for all 1,796 students; earned ≤ attempted for all 4,540 progress rows |
| Report tests | Mutation: credits applied newest-first; D grades not earned | Each was caught by exactly the expected test; both restored by redeploy |
| Extract runs | All eleven types on the seed | Every reconciliation, subtotal and rule control passes. WARNINGs are genuine: fall headcount grows 135% from 2024FA (the partial first year) against a 20% limit |
| Extract checksum | SQL `ContentSha256` against Python SHA-256 of the exported bytes | 13 of 13 runs equal; a value with accents, an en dash, commas and quotes also matched |
| Extract procedures | tSQLt and review | **Found:** `OUTPUT` parameters are not returned when a procedure raises an error, so a caller could not learn a failed run's id. **Fix:** the scheduler looks up the FAILED run. **Found (review):** an `INSERT ... EXEC` around generation would fail on its `ROLLBACK` (error 3915). **Fix:** a quiet flag instead |
| Prior-period controls | Census schedule on real data | **Found (design):** summer was compared with spring, producing spurious warnings. **Fix:** a term period compares with the previous term of the same type; tSQLt test added |
| Row-level security and tSQLt | `make test-sql` after adding the policy | **Found:** the policy schema-binds the snapshot rows table, so tSQLt cannot rename (fake) it (error 15336). An aborted `NoTransaction` test then left test doubles in place, including a core view replaced by a table. **Repair:** a stale rename-log entry was removed and `tSQLt.UndoTestDoubles` run; real data intact (32 batches, 7 snapshots). **Fix:** tests drop the policy inside their own transaction (the helper refuses outside one); refusal tests moved to a class that never fakes that table |
| Security tests | Lint and first run | **Found:** SQLFluff cannot parse `EXECUTE AS`/`REVERT`, so impersonation runs in dynamic batches with their own TRY/CATCH. **Found:** metadata visibility hides other users from a security admin, so an existence pre-check refused valid grants; removed, and `ALTER ROLE` reports, audited |
| Security model | Mutation: a stray `GRANT` on `staging`; the policy turned off | Matrix test failed, then the row-level security test failed (3 rows instead of 2); both restored. The DDL trigger recorded the stray `GRANT` and `REVOKE` with the login |
| Schedule CLI | Review | **Found:** `run-schedule` would exit 0 on failure, because the procedure raises after its result set and pyodbc reports that only on the next result set. **Fix:** drain the result sets; exit 1 |
| Python export | `test_extract_contracts.py` (15), `test_extracts_db.py` (15) | Pass. Census reproducibility end to end: after a late source correction and a nightly run, live census credits changed; the census report, the IPEDS Fall Enrollment SHA-256 and the snapshot verification did not |
| Data-quality additions | Nightly run on the seed | `CRED_EARNED_CREDITS` and `STU_STATUS_CONSISTENT` evaluate 139 credentials and 2,062 students and find no failures: genuine, not tuned. Two Part 2 tests needed `staging.CredentialAwarded` faked |
| Power BI model | `test_powerbi_model.py`, `test_powerbi_db.py`; mutation: a bad DAX column | Pass; the mutation was caught. **Not opened in Power BI Desktop** |
| Agent jobs | `make agent-run` for all four jobs | All succeed in the container |

## Part 3 hand-off checks (clean clone)

The data volume was deleted (`make clean CONFIRM=1`), the branch was cloned into a new
directory and only `.env` was copied in.

| Check | Result |
|---|---|
| `make bootstrap`, then again | Exit 0 in 46 s and 33 s |
| `make lint` | Exit 0 |
| `make test`, `make test-db`, `make test-sql` | 100, 35 and 131 tests pass |
| `make agent-install` and `make agent-run` for each job | Four jobs created; nightly, census and compliance, daily and weekly all succeed |
| `make nightly`, `make extracts`, `make smoke` | Reconciled; the census schedule's second run does nothing; smoke passes. 25 extract runs: 19 PASSED, 6 WARNING, 0 failed controls; 7 snapshots |

### Not verified here

- GitHub Actions has not yet run the extended workflow; it needs a push.
- The Power BI semantic model, report pages, role checks and screenshots need Power BI Desktop
  on Windows ([steps](../powerbi/WINDOWS-BUILD-STEPS.md)). The traceability matrix marks them
  "pending Windows session".
- The IPEDS definitions were read from the packages for 4-year institutions and program
  reporters, which share a glossary with the public 2-year academic-reporter package. IR must
  confirm them against that package.
- SqlPackage still needs the .NET 8 build override on this machine (see Part 1).
