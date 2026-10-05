"""Synthetic data must be unmistakably fake: reserved email domain, reserved phone range and
nothing shaped like a Social Security number."""

import re
from dataclasses import fields

from campus_ops.generators.common import FAKE_EMAIL_DOMAIN
from campus_ops.generators.dataset import LOAD_ORDER, SourceDataset
from campus_ops.generators.records import DirectoryAccount, J1Person, SlateContactPoint

FICTIONAL_PHONE = re.compile(r"^\d{3}-555-01\d{2}$")
SSN_SHAPE = re.compile(r"\b\d{3}-?\d{2}-?\d{4}\b")
SENSITIVE_FIELD_NAMES = re.compile(r"ssn|social|tax_?id|passport|license", re.IGNORECASE)


def _all_strings(dataset: SourceDataset) -> list[str]:
    return [
        value
        for row_type in LOAD_ORDER
        for row in dataset.rows(row_type)
        for value in row.values()
        if isinstance(value, str)
    ]


def test_every_email_uses_the_reserved_domain(dataset: SourceDataset) -> None:
    emails = [p.email for p in dataset.rows(J1Person) if p.email]
    emails += [
        c.contact_value for c in dataset.rows(SlateContactPoint) if c.contact_type == "EMAIL"
    ]
    emails += [a.user_principal_name for a in dataset.rows(DirectoryAccount)]
    assert emails
    assert all(email.lower().endswith(f"@{FAKE_EMAIL_DOMAIN}") for email in emails)


def test_every_phone_is_in_the_fictional_range(dataset: SourceDataset) -> None:
    phones = [p.phone for p in dataset.rows(J1Person) if p.phone]
    phones += [
        c.contact_value for c in dataset.rows(SlateContactPoint) if c.contact_type == "PHONE"
    ]
    assert phones
    assert [p for p in phones if not FICTIONAL_PHONE.match(p)] == []


def test_no_value_looks_like_a_social_security_number(dataset: SourceDataset) -> None:
    assert [value for value in _all_strings(dataset) if SSN_SHAPE.search(value)] == []


def test_no_table_has_a_government_identifier_column() -> None:
    names = [f.name for row_type in LOAD_ORDER for f in fields(row_type)]  # type: ignore[arg-type]
    assert [name for name in names if SENSITIVE_FIELD_NAMES.search(name)] == []
