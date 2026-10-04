"""Slate-Sim admissions records.

About a fifth of applicants are people the SIS already knows. They are linked by one of
three kinds of evidence, mirroring the matching hierarchy integration will apply: a SIS ID
recorded in the CRM, the same email and birth date, or only name, birth date and postal
code (which integration must treat as review-only).
"""

import random
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta

from campus_ops.generators.calendar import PROGRAMS
from campus_ops.generators.common import (
    AS_OF,
    CITIES,
    FAKE_EMAIL_DOMAIN,
    FIRST_NAMES,
    LAST_NAMES,
    email_local,
    fake_phone,
    fake_street,
    fake_uuid,
    random_date,
    random_datetime,
    weighted_choice,
)
from campus_ops.generators.records import (
    J1Person,
    J1Student,
    SlateAddress,
    SlateApplication,
    SlateApplicationProgram,
    SlateApplicationStatusHistory,
    SlateContactPoint,
    SlateExportQueue,
    SlateExternalIdentifier,
    SlatePerson,
)

KNOWN_PERSON_SHARE = 0.2
MATCH_BASIS_WEIGHTS = (("SIS_ID", 40), ("EMAIL_DOB", 40), ("NAME_DOB_POSTAL", 20))
STATUS_WEIGHTS = (
    ("ADMITTED", 40),
    ("DEPOSITED", 15),
    ("SUBMITTED", 15),
    ("COMPLETE", 10),
    ("DENIED", 8),
    ("WITHDRAWN", 5),
    ("STARTED", 7),
)
STATUS_PATHS = {
    "STARTED": ("STARTED",),
    "SUBMITTED": ("STARTED", "SUBMITTED"),
    "COMPLETE": ("STARTED", "SUBMITTED", "COMPLETE"),
    "ADMITTED": ("STARTED", "SUBMITTED", "COMPLETE", "ADMITTED"),
    "DENIED": ("STARTED", "SUBMITTED", "COMPLETE", "DENIED"),
    "DEPOSITED": ("STARTED", "SUBMITTED", "COMPLETE", "ADMITTED", "DEPOSITED"),
    "WITHDRAWN": ("STARTED", "SUBMITTED", "WITHDRAWN"),
}
EXPORTED_STATUSES = frozenset({"ADMITTED", "DEPOSITED"})
APPLICATION_WINDOW = (datetime(2025, 10, 1), datetime(2026, 5, 1))
ENTRY_TERM_WEIGHTS = (("2027SP", 30), ("2027SU", 10), ("2027FA", 60))
ACTIVE_SLATE_CODES = tuple(p.slate_code for p in PROGRAMS if p.is_active)
INACTIVE_SLATE_CODES = tuple(p.slate_code for p in PROGRAMS if not p.is_active)


@dataclass(frozen=True, slots=True)
class Applicant:
    """Everything needed to create one applicant and one application."""

    person_id: str
    application_id: str
    first_name: str | None
    middle_name: str | None
    last_name: str | None
    birth_date: date | None
    email: str | None
    phone: str | None
    street: str | None
    city: str | None
    postal_code: str | None
    entry_term_code: str | None
    student_type: str
    final_status: str
    program_codes: tuple[str, ...]
    sis_id: str | None
    common_app_id: str | None
    created_at_utc: datetime


@dataclass(slots=True)
class AdmissionsData:
    persons: list[SlatePerson] = field(default_factory=list)
    applications: list[SlateApplication] = field(default_factory=list)
    status_history: list[SlateApplicationStatusHistory] = field(default_factory=list)
    programs: list[SlateApplicationProgram] = field(default_factory=list)
    addresses: list[SlateAddress] = field(default_factory=list)
    contacts: list[SlateContactPoint] = field(default_factory=list)
    identifiers: list[SlateExternalIdentifier] = field(default_factory=list)
    exports: list[SlateExportQueue] = field(default_factory=list)

    def add_applicant(self, rng: random.Random, applicant: Applicant) -> None:
        a = applicant
        moments: list[tuple[str, datetime]] = []
        moment = a.created_at_utc
        for position, status in enumerate(STATUS_PATHS[a.final_status]):
            if position:
                moment += timedelta(days=rng.randint(1, 20), minutes=rng.randint(0, 600))
            moments.append((status, moment))
        times = dict(moments)
        last_change = moments[-1][1]
        decision = times.get("ADMITTED") or times.get("DENIED")

        person_created = a.created_at_utc - timedelta(days=rng.randint(0, 30))
        self.persons.append(
            SlatePerson(
                person_id=a.person_id,
                first_name=a.first_name,
                middle_name=a.middle_name,
                last_name=a.last_name,
                preferred_name=None,
                birth_date=a.birth_date,
                created_at_utc=person_created,
                updated_at_utc=last_change,
            )
        )
        self.applications.append(
            SlateApplication(
                application_id=a.application_id,
                person_id=a.person_id,
                entry_term_code=a.entry_term_code,
                student_type=a.student_type,
                current_status=a.final_status,
                submitted_at_utc=times.get("SUBMITTED"),
                decision_at_utc=decision,
                created_at_utc=a.created_at_utc,
                updated_at_utc=last_change,
            )
        )
        for status, changed in moments:
            self.status_history.append(
                SlateApplicationStatusHistory(
                    application_status_history_id=len(self.status_history) + 1,
                    application_id=a.application_id,
                    status=status,
                    changed_at_utc=changed,
                    created_at_utc=changed,
                )
            )
        for rank, code in enumerate(a.program_codes, start=1):
            self.programs.append(
                SlateApplicationProgram(
                    application_program_id=len(self.programs) + 1,
                    application_id=a.application_id,
                    program_code=code,
                    choice_rank=rank,
                    created_at_utc=a.created_at_utc,
                    updated_at_utc=a.created_at_utc,
                )
            )
        if a.street is not None:
            self.addresses.append(
                SlateAddress(
                    address_id=len(self.addresses) + 1,
                    person_id=a.person_id,
                    address_type="HOME",
                    line1=a.street,
                    line2=None,
                    city=a.city,
                    state_code="MA",
                    postal_code=a.postal_code,
                    country_code="US",
                    is_primary=True,
                    created_at_utc=person_created,
                    updated_at_utc=person_created,
                )
            )
        for contact_type, value in (("EMAIL", a.email), ("PHONE", a.phone)):
            if value is not None:
                self.contacts.append(
                    SlateContactPoint(
                        contact_point_id=len(self.contacts) + 1,
                        person_id=a.person_id,
                        contact_type=contact_type,
                        contact_value=value,
                        is_primary=True,
                        created_at_utc=person_created,
                        updated_at_utc=person_created,
                    )
                )
        for id_type, value in (("SIS_ID", a.sis_id), ("COMMON_APP_ID", a.common_app_id)):
            if value is not None:
                self.identifiers.append(
                    SlateExternalIdentifier(
                        external_identifier_id=len(self.identifiers) + 1,
                        person_id=a.person_id,
                        identifier_type=id_type,
                        identifier_value=value,
                        created_at_utc=a.created_at_utc,
                        updated_at_utc=a.created_at_utc,
                    )
                )
        if a.final_status in EXPORTED_STATUSES and decision is not None:
            queued = decision + timedelta(hours=1)
            self.exports.append(
                SlateExportQueue(
                    export_queue_id=len(self.exports) + 1,
                    application_id=a.application_id,
                    export_type="ADMITTED_APPLICANT",
                    queued_at_utc=queued,
                    exported_at_utc=None,
                    created_at_utc=queued,
                    updated_at_utc=queued,
                )
            )


def _program_choices(rng: random.Random) -> tuple[str, ...]:
    first = (
        rng.choice(INACTIVE_SLATE_CODES) if rng.random() < 0.02 else rng.choice(ACTIVE_SLATE_CODES)
    )
    if rng.random() < 0.3:
        second = rng.choice([code for code in ACTIVE_SLATE_CODES if code != first])
        return (first, second)
    return (first,)


def build_admissions(
    rng: random.Random, count: int, j1_people: list[J1Person], students: list[J1Student]
) -> AdmissionsData:
    data = AdmissionsData()
    student_status = {s.id_number: s.student_status for s in students}
    # Known people are former students or SIS people who never enrolled; active students
    # re-applying would be a different (already matriculated) scenario.
    known_pool = [
        p
        for p in j1_people
        if student_status.get(p.id_number) in (None, "INACTIVE", "WITHDRAWN", "GRADUATED")
    ]
    known = rng.sample(known_pool, k=min(round(count * KNOWN_PERSON_SHARE), len(known_pool)))

    for position in range(count):
        status = weighted_choice(rng, STATUS_WEIGHTS)
        created = random_datetime(rng, *APPLICATION_WINDOW)
        common_app_id = f"CA{rng.randrange(10**7, 10**8)}" if rng.random() < 0.5 else None
        if position < len(known):
            person = known[position]
            basis = weighted_choice(rng, MATCH_BASIS_WEIGHTS)
            prior_student = person.id_number in student_status
            email = person.email
            if basis == "NAME_DOB_POSTAL":
                # A different email, so only name + birth date + postal code can link them.
                local = email_local(person.first_name, person.last_name)
                email = f"{local}.new{position}@{FAKE_EMAIL_DOMAIN}"
            applicant = Applicant(
                person_id=fake_uuid(rng),
                application_id=fake_uuid(rng),
                first_name=person.first_name,
                middle_name=person.middle_name,
                last_name=person.last_name,
                birth_date=person.birth_date,
                email=email,
                phone=person.phone,
                street=person.address_line1,
                city=person.city,
                postal_code=person.postal_code,
                entry_term_code=weighted_choice(rng, ENTRY_TERM_WEIGHTS),
                student_type="READMIT" if prior_student else "FIRST_TIME",
                final_status=status,
                program_codes=_program_choices(rng),
                sis_id=str(person.id_number) if basis == "SIS_ID" else None,
                common_app_id=common_app_id,
                created_at_utc=created,
            )
        else:
            first, last = rng.choice(FIRST_NAMES), rng.choice(LAST_NAMES)
            city, postal = rng.choice(CITIES)
            has_address = rng.random() < 0.96
            as_of = AS_OF.date()
            applicant = Applicant(
                person_id=fake_uuid(rng),
                application_id=fake_uuid(rng),
                first_name=first,
                middle_name=rng.choice(FIRST_NAMES) if rng.random() < 0.25 else None,
                last_name=last,
                # The CRM accepts incomplete applicant data; about 1% omit birth date.
                birth_date=None
                if rng.random() < 0.01
                else random_date(rng, date(as_of.year - 45, 1, 1), date(as_of.year - 17, 1, 1)),
                email=f"{email_local(first, last)}.app{position}@{FAKE_EMAIL_DOMAIN}",
                phone=fake_phone(rng) if rng.random() < 0.8 else None,
                street=fake_street(rng) if has_address else None,
                city=city if has_address else None,
                postal_code=postal if has_address else None,
                entry_term_code=weighted_choice(rng, ENTRY_TERM_WEIGHTS),
                student_type=weighted_choice(
                    rng, (("FIRST_TIME", 70), ("TRANSFER", 22), ("NON_DEGREE", 8))
                ),
                final_status=status,
                program_codes=_program_choices(rng),
                sis_id=None,
                common_app_id=common_app_id,
                created_at_utc=created,
            )
        data.add_applicant(rng, applicant)
    return data
