"""Extract delivery: writes stored extract runs to CSV files with manifests.

The database builds, checks and stores every extract run; this package only reads a stored run
through compliance.usp_GetExtractForExport and writes its exact bytes. See
docs/specifications/extract-controls.md.
"""
