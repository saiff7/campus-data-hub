"""Shared building blocks: the fixed simulation clock, seeded randomness and fake values.

Every domain draws from its own Random seeded with "<seed>:<domain>", so changing one
domain's logic does not reshuffle the others. Nothing here reads the wall clock.
"""

import random
import uuid
from datetime import date, datetime, timedelta
from decimal import ROUND_HALF_UP, Decimal

# The synthetic "today". Data is generated as it would look on this date.
AS_OF = datetime(2026, 9, 1, 12, 0, 0)
FAKE_EMAIL_DOMAIN = "example.com"
# NANP numbers 555-0100 through 555-0199 are reserved for fictional use.
FAKE_PHONE_PREFIXES = ("617", "508", "413", "978", "781")

FIRST_NAMES = (
    "Aaliyah",
    "Adrian",
    "Aisha",
    "Alejandro",
    "Amara",
    "Andre",
    "Anika",
    "Ari",
    "Bianca",
    "Brandon",
    "Camila",
    "Carlos",
    "Chloe",
    "Daniel",
    "Deja",
    "Diego",
    "Elena",
    "Elijah",
    "Emily",
    "Ethan",
    "Fatima",
    "Gabriel",
    "Grace",
    "Hannah",
    "Hector",
    "Imani",
    "Isaac",
    "Isabella",
    "Jada",
    "Jamal",
    "Jasmine",
    "Javier",
    "Jayden",
    "Julia",
    "Kai",
    "Keisha",
    "Kevin",
    "Laila",
    "Liam",
    "Lucia",
    "Malik",
    "Maria",
    "Marcus",
    "Maya",
    "Mei",
    "Miguel",
    "Nadia",
    "Nathan",
    "Nia",
    "Noah",
    "Olivia",
    "Omar",
    "Priya",
    "Rafael",
    "Rosa",
    "Samuel",
    "Sara",
    "Sofia",
    "Tariq",
    "Thanh",
    "Tyler",
    "Valeria",
    "Victor",
    "Wei",
    "Xavier",
    "Yusuf",
    "Zara",
    "Zoe",
)
LAST_NAMES = (
    "Abernathy",
    "Alvarez",
    "Baptiste",
    "Bergstrom",
    "Calloway",
    "Castellano",
    "Chandra",
    "Delacroix",
    "Donnelly",
    "Esposito",
    "Fairbanks",
    "Ferreira",
    "Gallagher",
    "Goldberg",
    "Haddad",
    "Hargrove",
    "Ibarra",
    "Jansen",
    "Kaminski",
    "Kowalczyk",
    "Lachance",
    "Lindgren",
    "Mbeki",
    "McAllister",
    "Montoya",
    "Nakamura",
    "Nwosu",
    "Okonkwo",
    "Oyelaran",
    "Pacheco",
    "Pellegrini",
    "Quintero",
    "Rasmussen",
    "Rosario",
    "Sandoval",
    "Sorensen",
    "Tavares",
    "Thibodeau",
    "Underhill",
    "Valdivia",
    "Vasquez",
    "Whitcombe",
    "Wojcik",
    "Yamamoto",
    "Zielinski",
    "Zuniga",
)
STREET_NAMES = (
    "Maple",
    "Oak",
    "Elm",
    "Cedar",
    "Chestnut",
    "Pleasant",
    "Prospect",
    "Highland",
    "Summer",
    "Winter",
    "Union",
    "Central",
    "Washington",
    "Lincoln",
    "Walnut",
    "Spring",
    "Park",
    "Church",
)
STREET_SUFFIXES = ("St", "Ave", "Rd", "Ln", "Ct", "Way")
# Massachusetts places with a representative ZIP code, used for realistic address shape.
CITIES = (
    ("Worcester", "01608"),
    ("Springfield", "01103"),
    ("Lowell", "01852"),
    ("Cambridge", "02139"),
    ("Brockton", "02301"),
    ("Quincy", "02169"),
    ("Lynn", "01902"),
    ("New Bedford", "02740"),
    ("Fall River", "02720"),
    ("Newton", "02458"),
    ("Somerville", "02143"),
    ("Framingham", "01702"),
    ("Haverhill", "01830"),
    ("Waltham", "02451"),
    ("Malden", "02148"),
    ("Medford", "02155"),
    ("Taunton", "02780"),
    ("Chicopee", "01013"),
    ("Weymouth", "02188"),
    ("Revere", "02151"),
)


def domain_rng(seed: int, domain: str) -> random.Random:
    return random.Random(f"{seed}:{domain}")


def fake_uuid(rng: random.Random) -> str:
    return str(uuid.UUID(int=rng.getrandbits(128), version=4))


def fake_phone(rng: random.Random) -> str:
    return f"{rng.choice(FAKE_PHONE_PREFIXES)}-555-01{rng.randrange(100):02d}"


def fake_street(rng: random.Random) -> str:
    return f"{rng.randint(1, 999)} {rng.choice(STREET_NAMES)} {rng.choice(STREET_SUFFIXES)}"


def email_local(*parts: str) -> str:
    return ".".join("".join(ch for ch in part.lower() if ch.isalnum()) for part in parts if part)


def random_datetime(rng: random.Random, start: datetime, end: datetime) -> datetime:
    """Uniform instant in [start, end], truncated to whole milliseconds (datetime2(3))."""
    span_ms = int((end - start).total_seconds() * 1000)
    moment = start + timedelta(milliseconds=rng.randint(0, max(span_ms, 0)))
    return moment.replace(microsecond=(moment.microsecond // 1000) * 1000)


def random_date(rng: random.Random, start: date, end: date) -> date:
    return start + timedelta(days=rng.randint(0, (end - start).days))


def at_noon(day: date) -> datetime:
    return datetime(day.year, day.month, day.day, 12, 0, 0)


def money(value: float | Decimal) -> Decimal:
    return Decimal(str(value)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


def weighted_choice[T](rng: random.Random, options: tuple[tuple[T, int], ...]) -> T:
    values, weights = zip(*options, strict=True)
    return rng.choices(values, weights=weights, k=1)[0]
