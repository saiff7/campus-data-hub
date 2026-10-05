"""J1-Sim person records: the institution's authoritative people."""

import random
from datetime import date, datetime

from campus_ops.generators.common import (
    AS_OF,
    CITIES,
    FAKE_EMAIL_DOMAIN,
    FIRST_NAMES,
    LAST_NAMES,
    email_local,
    fake_phone,
    fake_street,
    random_date,
    random_datetime,
)
from campus_ops.generators.records import J1Person

FIRST_ID_NUMBER = 2400001
PEOPLE_CREATED_FROM = datetime(2023, 6, 1)


def _birth_date(rng: random.Random) -> date:
    # Community-college mix: mostly traditional age, with a substantial adult population.
    if rng.random() < 0.75:
        oldest, youngest = 24, 18
    else:
        oldest, youngest = 55, 25
    as_of = AS_OF.date()
    return random_date(
        rng,
        date(as_of.year - oldest - 1, as_of.month, as_of.day),
        date(as_of.year - youngest, as_of.month, as_of.day),
    )


def build_j1_people(rng: random.Random, count: int) -> list[J1Person]:
    people: list[J1Person] = []
    for offset in range(count):
        id_number = FIRST_ID_NUMBER + offset
        first, last = rng.choice(FIRST_NAMES), rng.choice(LAST_NAMES)
        middle = rng.choice(FIRST_NAMES) if rng.random() < 0.3 else None
        has_address = rng.random() < 0.97
        city, postal = rng.choice(CITIES)
        created = random_datetime(rng, PEOPLE_CREATED_FROM, AS_OF)
        people.append(
            J1Person(
                id_number=id_number,
                first_name=first,
                middle_name=middle,
                last_name=last,
                birth_date=_birth_date(rng),
                # The numeric suffix keeps regular emails unique; shared emails exist only
                # as deliberate edge cases.
                email=f"{email_local(first, last)}{offset + 1}@{FAKE_EMAIL_DOMAIN}",
                phone=fake_phone(rng) if rng.random() < 0.85 else None,
                address_line1=fake_street(rng) if has_address else None,
                city=city if has_address else None,
                state_code="MA" if has_address else None,
                postal_code=postal if has_address else None,
                created_at_utc=created,
                updated_at_utc=random_datetime(rng, created, AS_OF),
            )
        )
    return people
