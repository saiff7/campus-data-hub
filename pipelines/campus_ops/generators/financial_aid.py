"""J1-Sim financial aid awards for fall and spring terms with billed credits.

Amounts follow the database invariant disbursed <= accepted <= offered. Disbursement
happens a week after census, so terms whose census is after AS_OF have nothing disbursed.
"""

import random
from datetime import timedelta
from decimal import Decimal

from campus_ops.generators.calendar import TERMS_BY_CODE
from campus_ops.generators.common import AS_OF, at_noon, money
from campus_ops.generators.records import J1FinancialAidAward, J1Student

AID_APPLICANT_SHARE = 0.55
DISBURSEMENT_DAYS_AFTER_CENSUS = 7
FULL_TIME_CREDITS = Decimal("12")
# fund code -> (probability for an aid applicant, minimum, maximum) per term
FUND_RULES: tuple[tuple[str, float, int, int], ...] = (
    ("PELL", 0.70, 750, 3700),
    ("SEOG", 0.10, 200, 600),
    ("MASSGRANT", 0.40, 300, 1200),
    ("DIRECT_SUB", 0.30, 1750, 2750),
    ("DIRECT_UNSUB", 0.15, 1000, 3000),
    ("INST_SCHOL", 0.10, 250, 1500),
)
LOAN_FUNDS = frozenset({"DIRECT_SUB", "DIRECT_UNSUB"})


def build_awards(
    rng: random.Random,
    students: list[J1Student],
    billed_credits: dict[tuple[int, str], Decimal],
) -> list[J1FinancialAidAward]:
    awards: list[J1FinancialAidAward] = []
    aid_applicants = {s.id_number for s in students if rng.random() < AID_APPLICANT_SHARE}
    next_award_id = 1
    for (id_number, term_code), credits in sorted(billed_credits.items()):
        term = TERMS_BY_CODE[term_code]
        if id_number not in aid_applicants or term.term_type == "SUMMER" or rng.random() >= 0.9:
            continue
        load_factor = min(credits / FULL_TIME_CREDITS, Decimal("1"))
        disbursed_on = term.census + timedelta(days=DISBURSEMENT_DAYS_AFTER_CENSUS)
        is_disbursable = disbursed_on <= AS_OF.date()
        offered_at = at_noon(term.start - timedelta(days=rng.randint(30, 90)))
        for fund_code, probability, minimum, maximum in FUND_RULES:
            if rng.random() >= probability:
                continue
            offered = money(
                round(rng.randint(minimum, maximum) * float(load_factor) / 50) * 50 or 50
            )
            roll = rng.random()
            if roll < 0.10:
                status, accepted = "OFFERED", Decimal("0.00")
            elif roll < 0.18 or (fund_code in LOAN_FUNDS and roll < 0.35):
                status, accepted = "DECLINED", Decimal("0.00")
            elif 0.36 <= roll < 0.40:
                status, accepted = "CANCELLED", Decimal("0.00")
            else:
                status = "ACCEPTED"
                accepted = offered if rng.random() < 0.9 else money(offered * Decimal("0.5"))
            disbursed = accepted if is_disbursable else Decimal("0.00")
            updated = (
                at_noon(disbursed_on)
                if disbursed
                else offered_at + timedelta(days=rng.randint(1, 20))
            )
            awards.append(
                J1FinancialAidAward(
                    award_id=next_award_id,
                    id_number=id_number,
                    aid_year=term.academic_year,
                    term_code=term_code,
                    fund_code=fund_code,
                    award_status=status,
                    offered_amount=offered,
                    accepted_amount=accepted,
                    disbursed_amount=disbursed,
                    created_at_utc=offered_at,
                    updated_at_utc=min(updated, AS_OF),
                )
            )
            next_award_id += 1
    return awards
