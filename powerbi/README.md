# Power BI project (PBIP)

> **Status: not yet opened in Power BI Desktop.** Power BI Desktop runs only on Windows and this
> repository was built on macOS. Everything here is text that was generated and checked on the
> Mac. Report pages and screenshots are pending a Windows session:
> [docs/powerbi/WINDOWS-BUILD-STEPS.md](../docs/powerbi/WINDOWS-BUILD-STEPS.md).

| Path | What it is | How it was checked |
|---|---|---|
| `CampusDataOps.SemanticModel/definition/tables/*.tmdl` | One import table per `bi` view | Generated from the deployed views' metadata by `tools/generate_tmdl.py`; `tests/python/test_powerbi_db.py` fails if they drift |
| `CampusDataOps.SemanticModel/definition/tables/Measures.tmdl` | Measures, built from `dax/Measures.dax` | `tests/python/test_powerbi_model.py`: every measure, table and column reference resolves |
| `CampusDataOps.SemanticModel/definition/relationships.tmdl` | Star-schema relationships | Same test: every column exists |
| `CampusDataOps.SemanticModel/definition/roles/` | Power BI roles ([dax/RLS-Roles.md](dax/RLS-Roles.md)) | Same test: filters name existing columns |
| `CampusDataOps.Report/` | A report stub with one empty page | **Not checked.** Desktop may reject it; the Windows steps include a fallback |
| `themes/campus-theme.json` | Colour theme | Not checked |
| `screenshots/` | Masked, aggregate screenshots | **Pending a Windows session** |

The model connects through two parameters, `SqlServer` (default `localhost,1433`) and
`Database` (default `CampusDataOps`), and imports only the masked `bi` schema. The refresh
login should be a member of `role_ir_analyst` and nothing else.

Regenerate the TMDL after changing a `bi` view or `dax/Measures.dax`:

```bash
make powerbi-model
```
