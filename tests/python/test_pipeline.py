"""Unit tests for the pipeline sequencing helpers (no database)."""

import pytest

from campus_ops.pipeline import RESET_SCRIPT, STEPS, _batches, steps_from


def test_recovery_resumes_at_the_named_step_and_runs_the_rest_in_order() -> None:
    assert steps_from("PROCESS") == ("PROCESS", "RECONCILE", "NOTIFY")
    assert steps_from("LOAD") == STEPS


def test_an_unknown_recovery_step_is_rejected() -> None:
    with pytest.raises(ValueError, match="unknown pipeline step"):
        steps_from("PUBLISH")


def test_scripts_split_on_go_lines_only() -> None:
    script = "SELECT 1;\nGO\n  go  \nSELECT 'GOAL';\nGO"
    assert _batches(script) == ["SELECT 1;", "SELECT 'GOAL';"]


def test_the_reset_script_refuses_to_run_without_confirmation() -> None:
    text = RESET_SCRIPT.read_text(encoding="utf-8")
    assert "$(ConfirmReset)" in text
    assert "THROW 50900" in text
