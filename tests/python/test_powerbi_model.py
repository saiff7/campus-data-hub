"""Static checks of the Power BI semantic model (TMDL) that run without Power BI Desktop.

The model has not been opened in Desktop (docs/powerbi/WINDOWS-BUILD-STEPS.md); these tests catch
what can be caught here: every DAX reference resolves, relationships and role filters name real
columns, every table is referenced by the model, and no direct identifier is modelled.
"""

import re
from pathlib import Path

POWERBI = Path(__file__).resolve().parents[2] / "powerbi"
DEFINITION = POWERBI / "CampusDataOps.SemanticModel" / "definition"
IDENTIFIERS = {"IdNumber", "BirthDate", "Email", "Phone", "FirstName", "LastName", "AddressLine1"}


def _tables() -> dict[str, set[str]]:
    tables = {}
    for path in (DEFINITION / "tables").glob("*.tmdl"):
        text = path.read_text()
        name = re.match(r"table (\S+)", text).group(1)  # type: ignore[union-attr]
        tables[name] = {
            m.group(1).strip("'") for m in re.finditer(r"^\tcolumn ('[^']+'|\S+)", text, re.M)
        }
    return tables


def _measures() -> dict[str, str]:
    text = (DEFINITION / "tables" / "Measures.tmdl").read_text()
    found = {}
    for m in re.finditer(r"^\tmeasure ('[^']+'|\S+) =(.*?)(?=^\t\t\w+:)", text, re.M | re.S):
        found[m.group(1).strip("'")] = m.group(2)
    return found


def test_every_measure_in_the_dax_file_is_in_the_model() -> None:
    dax = (POWERBI / "dax" / "Measures.dax").read_text()
    names = {
        m.group(1).strip()
        for m in re.finditer(r"^([A-Z][^=\n/]*?)\s*=", dax, re.M)
        if not m.group(1).startswith("//")
    }
    assert names == set(_measures())


def test_every_dax_reference_resolves() -> None:
    tables, measures = _tables(), _measures()
    for name, expression in measures.items():
        for table, column in re.findall(r"\b([A-Z]\w+)\[([^\]]+)\]", expression):
            assert column in tables.get(table, set()), f"{name}: {table}[{column}] does not exist"
        bare = re.sub(r"\b[A-Z]\w+\[[^\]]+\]", "", expression)
        for ref in re.findall(r"\[([^\]]+)\]", bare):
            assert ref in measures, f"{name}: measure [{ref}] does not exist"


def test_relationships_and_role_filters_name_existing_columns() -> None:
    tables = _tables()
    relationships = (DEFINITION / "relationships.tmdl").read_text()
    pairs = re.findall(r"(?:fromColumn|toColumn): (\w+)\.(\w+)", relationships)
    assert pairs
    for table, column in pairs:
        assert column in tables[table], f"{table}.{column}"
    for role in (DEFINITION / "roles").glob("*.tmdl"):
        for table, rule in re.findall(r"tablePermission (\w+) = (.+)", role.read_text()):
            assert table in tables, role.name
            for column in re.findall(r"\[(\w+)\]", rule):
                assert column in tables[table], f"{role.name}: {table}[{column}]"


def test_the_model_references_every_table_and_role() -> None:
    model = (DEFINITION / "model.tmdl").read_text()
    assert set(re.findall(r"^ref table (\S+)", model, re.M)) == set(_tables())
    roles = {
        re.match(r"role ('[^']+'|\S+)", p.read_text()).group(1)  # type: ignore[union-attr]
        for p in (DEFINITION / "roles").glob("*.tmdl")
    }
    assert set(re.findall(r"^ref role (.+)$", model, re.M)) == roles


def test_no_direct_identifier_is_modelled() -> None:
    for table, columns in _tables().items():
        for column in columns:
            assert not any(i.lower() in column.lower() for i in IDENTIFIERS), f"{table}.{column}"


def test_tmdl_is_tab_indented() -> None:
    for path in DEFINITION.rglob("*.tmdl"):
        for number, line in enumerate(path.read_text().splitlines(), 1):
            assert not line.startswith(" "), f"{path.name}:{number} is indented with spaces"
