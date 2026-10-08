# Power BI: Windows build steps

Power BI Desktop runs only on Windows, and Part 3 was built on macOS. The semantic model
(`powerbi/CampusDataOps.SemanticModel`) was generated and checked as text on the Mac but has
**not yet been opened in Power BI Desktop**. These steps finish the Power BI work on a Windows
laptop: open or rebuild the model, build the seven report pages, check the numbers against SQL,
and capture masked screenshots. Part 3 was tagged `v0.3-reporting` without them; the
traceability matrix marks them **pending Windows session** until these steps are done.

Plan on about half a day. Record every error message exactly as shown, including the ones you
work around, for the verification log (step 10).

## 1. Prerequisites

- Windows 10 or 11 with the current Power BI Desktop (Microsoft Store or download).
- In Power BI Desktop, **File > Options and settings > Options > Preview features**: turn on
  **Power BI Project (.pbip) save option** and **Store semantic model using TMDL format**, then
  restart Desktop. (The names of these options change between releases; search for "PBIP" and
  "TMDL".)
- Git, to clone the repository on the Windows machine.
- A running CampusDataOps database with data, from step 2.

## 2. Make the database reachable

Choose one option.

**Option A (recommended): run the platform on Windows under WSL2.**

1. Install WSL2 (Ubuntu) and Docker Desktop with WSL integration turned on.
2. In the Ubuntu shell, install the same tools as the README prerequisites: .NET SDK,
   SqlPackage, uv, `mssql-tools18` (sqlcmd) and ODBC Driver 18.
3. Clone the repository inside the WSL file system (not under `/mnt/c`), copy `.env.example` to
   `.env`, set `MSSQL_SA_PASSWORD`, then run:

   ```bash
   make bootstrap
   ```

   ```bash
   make nightly
   ```

   ```bash
   make extracts
   ```

   Docker Desktop forwards port 1433 to Windows, so Power BI connects to `localhost,1433`.

**Option B: connect to the Mac over the local network.** The container publishes port 1433 on
every interface of the Mac. Use the Mac's LAN address, for example `192.168.1.20,1433`, and
allow port 1433 in the macOS firewall. The container uses a self-signed certificate, so Power BI
will offer an unencrypted connection. Accept that only on a private network, and only because
every record is synthetic.

Either way, run `make nightly` and `make extracts` (the CENSUS schedule captures the census
snapshots) before refreshing. Without them, the census measures are blank.

## 3. Create the refresh login (masked data only)

The model must refresh as a login that belongs to `role_ir_analyst` and nothing else. That role
can read the masked `bi` schema but no raw layer. Choose a password yourself and do not commit
it. Run as `sa` (sqlcmd or SSMS):

```sql
CREATE LOGIN [powerbi_refresh] WITH PASSWORD = N'<choose a strong password>', CHECK_POLICY = ON;
GO
USE [CampusDataOps];
CREATE USER [powerbi_refresh] FOR LOGIN [powerbi_refresh];
EXEC [security].[usp_GrantRoleMembership]
    @UserName = N'powerbi_refresh', @RoleName = N'role_ir_analyst', @TicketReference = N'PBI-SETUP';
```

Check it: `SELECT TOP (1) * FROM bi.DimStudent;` must succeed for `powerbi_refresh`, and
`SELECT TOP (1) * FROM staging.Person;` must fail with error 229.

## 4. Open the project

1. Open `powerbi\CampusDataOps.pbip` in Power BI Desktop.
2. If it opens: **Transform data > Edit parameters**. Set `SqlServer` (`localhost,1433` or the
   Mac's address) and `Database` (`CampusDataOps`).
3. **Refresh**. When asked for credentials, choose **Database** and enter `powerbi_refresh`.
4. Confirm that 18 tables are loaded (17 `bi` tables and `_Measures`) and that Model view shows
   the relationships from `relationships.tmdl`.

### If it does not open

The report folder is a hand-written stub (`CampusDataOps.Report/report.json`) that has never
been loaded. If Desktop rejects the project:

1. Record the exact message.
2. If the message names the **report**: in Desktop, create a blank report and save it as a PBIP
   project in a temporary folder. Copy its `<name>.Report` folder over
   `powerbi/CampusDataOps.Report`, keeping our `definition.pbir`, which points to
   `../CampusDataOps.SemanticModel`. Open `CampusDataOps.pbip` again.
3. If the message names the **semantic model** (a TMDL syntax or property error): fix the
   generator (`powerbi/tools/generate_tmdl.py`) rather than the generated file, so the fix
   survives regeneration. Note the file and line Desktop reports. As a last resort, rebuild the
   model by hand: **Get data > SQL Server**, select every view in the `bi` schema, create the
   relationships listed in `RELATIONSHIPS` in the generator, add each measure from
   `powerbi/dax/Measures.dax`, then save as PBIP over the generated folder.

## 5. Check the numbers against SQL before building pages

Create a temporary table visual, or use **DAX query view**, and compare with sqlcmd. Every pair
must match exactly.

| Power BI | SQL |
|---|---|
| `[Census Headcount]` filtered to term `2025FA` | `SELECT IncludedCount FROM compliance.CensusSnapshot WHERE TermCode = '2025FA';` |
| `[Census FTE]` for `2025FA` | `SELECT MeasureValue FROM reporting.vw_LeadershipKPI WHERE TermCode = '2025FA' AND MeasureCode = 'CENSUS_FTE';` |
| `[Yield Rate]` for `2027FA` | `... MeasureCode = 'YIELD_RATE'` for `2027FA` |
| `[Aid Offered]` for aid year `2025-2026` | `SELECT SUM(OfferedAmount) FROM reporting.vw_FinancialAidPackaging WHERE AidYear = '2025-2026';` |
| `[Outstanding Balance]` | `SELECT SUM(CASE WHEN NetBalance > 0 THEN NetBalance ELSE 0 END) FROM reporting.vw_StudentAccountAging;` |
| `[Open Exceptions]` | `SELECT COUNT(*) FROM reporting.vw_ExceptionWorklist;` |
| `[Last Successful Run (UTC)]` | `SELECT LastSuccessfulRunEndedAtUtc FROM bi.DataAsOf;` |

Record any difference and do not continue until it is explained.

## 6. Build the seven pages

On **every page**, put a card with `[Data As Of Label]` in the top right and a card with
`[Refresh Status]` beside it. Use only aggregate visuals: no table or matrix that lists
individual students, and no `MaskedStudentId` on any page. Apply `powerbi/themes/campus-theme.json`
(**View > Themes > Browse for themes**).

| Page | Visuals | Slicers |
|---|---|---|
| Executive Overview | Cards: `Census Headcount`, `Census FTE`, `Yield Rate`, `Aid Recipients`, `Outstanding Balance`, `Course Success Rate`. Funnel: `Applications`, `Admits`, `Deposits`. Column chart: `Census Headcount` by `DimTerm[TermCode]` (sort by `TermSortKey`) | `DimTerm[AcademicYear]` |
| Enrollment | Stacked column: `Census Headcount` by term and `AttendanceIntensity`. Bar: by `DimProgram[ProgramName]`. Donut: `EntryStatus`. Card: `Full-Time Share` | `DimTerm[TermCode]`, `DimProgram[DivisionName]` |
| Integration Operations | Line: `Applications Processed` and `Applications Rejected` by `DimDate[Date]`. Bar: `Open Exceptions` by `DimExceptionReason[ExceptionReasonCode]`. Card: `Average Open Exception Age (Days)`. Card: `Unbalanced Runs` (must be 0) | `DimDepartment[DepartmentName]` |
| Data Quality | Bar: `Records Failed` by `DimDataQualityRule[RuleCode]`. Line: `Pass Rate` by `DimDate[Date]`. Matrix: `Records Failed` by `DimDataQualityRule[Severity]` and `DimDepartment[DepartmentName]` | `DimDataQualityRule[Severity]` |
| Financial Aid | Clustered column: `Aid Offered`, `Aid Accepted`, `Aid Disbursed` by `FactAidAward[FundCode]`. Card: `Aid Remaining`. Card: `Aid Recipients` | `FactAidAward[AidYear]`, `FactAidAward[FundType]` |
| Student Accounts | Column chart of the five aging buckets (sum of `Days001To030` … `Days091Plus` and `CurrentAmount`). Cards: `Outstanding Balance`, `Balance Over 90 Days`, `Students With a Balance` | none |
| Job Health | Line: `Average Run Seconds` by `DimDate[Date]`. Cards: `Runs`, `Failed Runs`, `Failed Steps`, `Last Successful Run (UTC)`. Bar: average of `FactJobStep[DurationSeconds]` by `StepName` | `FactJobStep[ProcessName]` |

## 7. Check the roles

**Modeling > View as** each role:

- `Leadership`: every page shows the same numbers as without a role.
- `Division - Health Sciences`: Enrollment shows only Nursing and Medical Assisting, and the
  Financial Aid and Student Accounts visuals are empty.

Record the results. Assigning people to roles happens in the Power BI service, not here.

## 8. Capture the screenshots

1. Refresh, then capture each page at 1600 × 900: **File > Export > Export to PDF**, or use the
   Snipping Tool on the page.
2. Before saving each image, check it at full size. It must show **no** names, SIS ID numbers,
   masked student IDs, birth dates, email addresses, phone numbers or addresses. Every number
   must be an aggregate. Retake any screenshot that fails.
3. Save them as `powerbi/screenshots/01-executive-overview.png` through `07-job-health.png`.

## 9. Save and commit

1. **File > Save** (PBIP). Desktop rewrites `CampusDataOps.Report` and may reformat the TMDL.
2. Run the static checks on the result (they also run in CI):

   ```bash
   uv run pytest tests/python/test_powerbi_model.py
   ```

3. If Desktop changed the TMDL, regenerate it with `make powerbi-model` on a machine with the
   database. If any difference remains, make it in the generator, so the generator stays the
   source of truth.
4. Commit the report folder, any model changes and the screenshots on a new branch.

## 10. Update the evidence

- `docs/ai/VERIFICATION-LOG.md`: add a "Power BI Windows session" table with the Desktop
  version, whether the project opened, every error and its fix, the step-5 comparisons, the
  step-7 role checks and the screenshot review.
- `docs/TRACEABILITY.md`: change the "pending Windows session" rows to the new evidence.
- `powerbi/README.md`: replace the status note.
