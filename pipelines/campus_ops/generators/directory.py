"""Directory-Sim accounts. Students get accounts keyed to their SIS IdNumber; staff and
service accounts are included so that "not a student" is distinguishable from "orphan"."""

import random
from dataclasses import dataclass, field
from datetime import datetime, timedelta

from campus_ops.generators.common import (
    AS_OF,
    FAKE_EMAIL_DOMAIN,
    FIRST_NAMES,
    LAST_NAMES,
    at_noon,
    fake_uuid,
    random_datetime,
)
from campus_ops.generators.records import (
    DirectoryAccount,
    DirectoryAccountStatusHistory,
    DirectoryGroupMembership,
    J1Person,
    J1Student,
)

STAFF_ACCOUNTS = 40
SERVICE_ACCOUNTS = 5
# A small share of active students have no account yet, as happens in real provisioning lag.
ACTIVE_WITHOUT_ACCOUNT_SHARE = 0.02
DISABLED_SHARE = {"ACTIVE": 0.0, "INACTIVE": 0.7, "WITHDRAWN": 0.7, "GRADUATED": 0.5}


@dataclass(slots=True)
class DirectoryData:
    accounts: list[DirectoryAccount] = field(default_factory=list)
    groups: list[DirectoryGroupMembership] = field(default_factory=list)
    history: list[DirectoryAccountStatusHistory] = field(default_factory=list)
    _sam_names: set[str] = field(default_factory=set)

    def _unique_sam(self, first: str, last: str) -> str:
        base = "".join(ch for ch in f"{first[0]}{last}".lower() if ch.isalnum())[:16]
        candidate, suffix = base, 1
        while candidate in self._sam_names:
            suffix += 1
            candidate = f"{base}{suffix}"
        self._sam_names.add(candidate)
        return candidate

    def add_account(
        self,
        rng: random.Random,
        *,
        first: str,
        last: str,
        employee_id: str | None,
        account_type: str,
        is_enabled: bool,
        created: datetime,
        group_names: tuple[str, ...],
    ) -> DirectoryAccount:
        guid = fake_uuid(rng)
        sam = self._unique_sam(first, last)
        disabled_at = (
            None if is_enabled else random_datetime(rng, created + timedelta(days=1), AS_OF)
        )
        account = DirectoryAccount(
            account_guid=guid,
            sam_account_name=sam,
            user_principal_name=f"{sam}@{FAKE_EMAIL_DOMAIN}",
            employee_id=employee_id,
            display_name=f"{first} {last}",
            account_type=account_type,
            is_enabled=is_enabled,
            when_created_utc=created,
            created_at_utc=created,
            updated_at_utc=disabled_at or created,
        )
        self.accounts.append(account)
        for group_name in group_names:
            self.groups.append(
                DirectoryGroupMembership(
                    group_membership_id=len(self.groups) + 1,
                    account_guid=guid,
                    group_name=group_name,
                    added_at_utc=created,
                    created_at_utc=created,
                    updated_at_utc=created,
                )
            )
        self.history.append(
            DirectoryAccountStatusHistory(
                account_status_history_id=len(self.history) + 1,
                account_guid=guid,
                is_enabled=True,
                reason="ACCOUNT_CREATED",
                changed_at_utc=created,
                created_at_utc=created,
            )
        )
        if disabled_at is not None:
            self.history.append(
                DirectoryAccountStatusHistory(
                    account_status_history_id=len(self.history) + 1,
                    account_guid=guid,
                    is_enabled=False,
                    reason="STUDENT_NOT_ENROLLED",
                    changed_at_utc=disabled_at,
                    created_at_utc=disabled_at,
                )
            )
        return account


def build_directory(
    rng: random.Random, j1_people: list[J1Person], students: list[J1Student]
) -> DirectoryData:
    data = DirectoryData()
    people = {p.id_number: p for p in j1_people}
    for student in students:
        status = student.student_status
        if status == "ACTIVE" and rng.random() < ACTIVE_WITHOUT_ACCOUNT_SHARE:
            continue
        person = people[student.id_number]
        enabled = rng.random() >= DISABLED_SHARE[status]
        groups = ("grp-all-students", f"grp-program-{student.program_code.lower()}")
        if status == "ACTIVE":
            groups += ("grp-wifi-students",)
        data.add_account(
            rng,
            first=person.first_name,
            last=person.last_name,
            employee_id=str(student.id_number),
            account_type="STUDENT",
            is_enabled=enabled,
            created=at_noon(student.matriculation_date + timedelta(days=1)),
            group_names=groups,
        )
    staff_window = (datetime(2018, 1, 1), datetime(2026, 6, 1))
    for number in range(1, STAFF_ACCOUNTS + 1):
        data.add_account(
            rng,
            first=rng.choice(FIRST_NAMES),
            last=rng.choice(LAST_NAMES),
            employee_id=f"E{number:05d}",
            account_type="STAFF",
            is_enabled=rng.random() >= 0.1,
            created=random_datetime(rng, *staff_window),
            group_names=("grp-all-staff",),
        )
    for number in range(1, SERVICE_ACCOUNTS + 1):
        data.add_account(
            rng,
            first="svc",
            last=f"integration{number}",
            employee_id=None,
            account_type="SERVICE",
            is_enabled=True,
            created=random_datetime(rng, *staff_window),
            group_names=("grp-service-accounts",),
        )
    return data
