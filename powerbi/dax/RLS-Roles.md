# Power BI roles

> **Status: not yet opened in Power BI Desktop.** These roles are defined in TMDL
> (`CampusDataOps.SemanticModel/definition/roles/`) and checked statically by
> `tests/python/test_powerbi_model.py`. They take effect only after the Windows build steps in
> [docs/powerbi/WINDOWS-BUILD-STEPS.md](../../docs/powerbi/WINDOWS-BUILD-STEPS.md).

Power BI roles are separate from the SQL Server roles in
[docs/architecture/security-model.md](../../docs/architecture/security-model.md).

| Role | Filter | Purpose |
|---|---|---|
| `Leadership` | none | Cabinet and IR: every page, all programs |
| `Division - <name>` (five roles) | `DimProgram[DivisionCode] = "<code>"`; `FactAidAward` and `FactAccountBalance` hidden (`FALSE()`) | A division lead sees census, funnel and course outcomes for the division's programs only, and no student financial facts |

## How storage mode affects enforcement

| Storage mode | Who SQL Server sees | What enforces viewer access |
|---|---|---|
| **Import** (this model) | The refresh identity only: a login in `role_ir_analyst` | Power BI roles above, applied by the Power BI service to each viewer. SQL roles and SQL row-level security limit only what the refresh can load, never what a viewer sees |
| **DirectQuery, shared credential** | One identity for every viewer | Power BI roles, as for import. SQL row-level security is evaluated once for the shared identity |
| **DirectQuery with single sign-on** (Microsoft Entra ID) | Each viewer's own identity | SQL Server roles and `security.ProgramScopePolicy` apply per viewer. Needs Azure SQL or SQL Server with Entra ID authentication, which the local container cannot provide, so it is documented, not built |

Consequences for this project:

- The refresh identity is a member of `role_ir_analyst`. It reads only the masked `bi` schema, so
  no SIS ID, name, birth date or contact value can enter the model, whatever the Power BI roles
  say.
- Program coordinators use the SQL roster (`reporting.vw_ProgramCensusRoster`), where SQL Server
  row-level security applies. The Power BI division roles are a separate, coarser control and
  are not a substitute for it.
- Role membership is assigned in the Power BI service, not in this repository. Test roles in
  Desktop with **Modeling > View as**.
