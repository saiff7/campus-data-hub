"""J1-Sim student account ledger.

Sign convention matches the database: charges and refunds are positive, payments and aid
credits are negative. Each term's activity is built so that some students carry balances
into the aging buckets the reporting layer will need.
"""

import random
from collections import defaultdict
from datetime import date, timedelta
from decimal import Decimal

from campus_ops.generators.calendar import TERMS_BY_CODE
from campus_ops.generators.common import AS_OF, at_noon, money, random_date
from campus_ops.generators.financial_aid import DISBURSEMENT_DAYS_AFTER_CENSUS
from campus_ops.generators.records import J1FinancialAidAward, J1StudentAccountTransaction

TUITION_PER_CREDIT = Decimal("240.00")
TERM_FEES = {"FALL": Decimal("425.00"), "SPRING": Decimal("425.00"), "SUMMER": Decimal("150.00")}
LATE_FEE = Decimal("25.00")
BILLING_DAYS_BEFORE_START = 21


def build_transactions(
    rng: random.Random,
    billed_credits: dict[tuple[int, str], Decimal],
    awards: list[J1FinancialAidAward],
) -> list[J1StudentAccountTransaction]:
    disbursed: dict[tuple[int, str], Decimal] = defaultdict(Decimal)
    for award in awards:
        disbursed[(award.id_number, award.term_code)] += award.disbursed_amount

    as_of_date = AS_OF.date()
    rows: list[J1StudentAccountTransaction] = []

    def add(
        id_number: int,
        term_code: str,
        kind: str,
        detail: str,
        amount: Decimal,
        *,
        posted: date,
        due: date | None = None,
    ) -> None:
        rows.append(
            J1StudentAccountTransaction(
                transaction_id=len(rows) + 1,
                id_number=id_number,
                term_code=term_code,
                transaction_type=kind,
                detail_code=detail,
                amount=amount,
                posted_date=posted,
                due_date=due,
                created_at_utc=at_noon(posted),
                updated_at_utc=at_noon(posted),
            )
        )

    for (id_number, term_code), credits in sorted(billed_credits.items()):
        term = TERMS_BY_CODE[term_code]
        billed_on = term.start - timedelta(days=BILLING_DAYS_BEFORE_START)
        tuition = money(credits * TUITION_PER_CREDIT)
        fees = TERM_FEES[term.term_type]
        add(id_number, term_code, "CHARGE", "TUIT", tuition, posted=billed_on, due=term.start)
        add(id_number, term_code, "CHARGE", "FEES", fees, posted=billed_on, due=term.start)
        balance = tuition + fees

        aid = disbursed.get((id_number, term_code), Decimal("0"))
        if aid:
            aid_on = term.census + timedelta(days=DISBURSEMENT_DAYS_AFTER_CENSUS)
            add(id_number, term_code, "AID_CREDIT", "FAID", -aid, posted=aid_on)
            balance -= aid
            if balance < 0:
                refund_on = aid_on + timedelta(days=10)
                add(id_number, term_code, "REFUND", "RFND", -balance, posted=refund_on)
                balance = Decimal("0")

        if balance <= 0:
            continue
        term_has_ended = term.end < as_of_date
        payment = money(balance * _payment_share(rng, term_has_ended=term_has_ended))
        if payment > 0:
            pay_until = term.end if term_has_ended else as_of_date
            paid_on = random_date(rng, billed_on, pay_until)
            add(id_number, term_code, "PAYMENT", "PYMT", -payment, posted=paid_on)
            balance -= payment
        if balance > 0 and term_has_ended:
            late_on = term.start + timedelta(days=45)
            add(id_number, term_code, "ADJUSTMENT", "LATE", LATE_FEE, posted=late_on)
    return rows


def _payment_share(rng: random.Random, *, term_has_ended: bool) -> Decimal:
    """Share of the remaining term balance the student pays. Completed terms are mostly paid
    in full; the in-progress term has more unpaid and partly paid balances."""
    full, none = (0.85, 0.03) if term_has_ended else (0.35, 0.25)
    partial_range = (50, 95) if term_has_ended else (20, 80)
    roll = rng.random()
    if roll < full:
        return Decimal("1")
    if roll < full + none:
        return Decimal("0")
    return Decimal(rng.randint(*partial_range)) / 100
