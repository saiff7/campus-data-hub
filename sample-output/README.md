# Sample output

Public copies of **aggregate** extracts only, written by `campus-ops export --public`
([extract-controls.md](../docs/specifications/extract-controls.md#public-copies)). Every count
from 1 to 4 is shown as `<5`. Each CSV has a manifest with its lineage, its control totals and
the SHA-256 of both the suppressed file and its source run. Student-level extracts can never be
written here; the export refuses them.

Produced on 2026-10-06 from the deterministic seed (20260901, scale 1.0) after the nightly run
and the extract schedules. Every record behind these numbers is synthetic. The IPEDS-aligned
files are **educational simulations, not IPEDS submissions**: no sex or race/ethnicity
breakdowns, and the assumptions are listed in
[ipeds-measure-mapping.md](../docs/specifications/ipeds-measure-mapping.md).

`ipeds_fe_2025FA` is marked `WARNING`. Its headcount grew 135% from 2024FA, the partial first
year of the synthetic data, which is more than the 20% prior-period limit. The warning is
recorded in the manifest, not hidden.
