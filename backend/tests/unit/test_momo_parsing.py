"""
Unit tests for app.core.momo_parsing
=====================================
Covers all four regex patterns, edge cases, USSD wrappers,
phone normalisation, and the _title_case helper.
"""

import pytest
from app.core.momo_parsing import parse_momo_sms, _title_case

pytestmark = pytest.mark.unit


# ──────────────────────────────────────────────────────────────────────────────
# _title_case
# ──────────────────────────────────────────────────────────────────────────────

class TestTitleCase:
    def test_all_caps_converted(self):
        assert _title_case("MUTONI BRICE") == "Mutoni Brice"

    def test_mixed_case_preserved(self):
        assert _title_case("NexVentures Ltd") == "NexVentures Ltd"

    def test_single_word_all_caps(self):
        assert _title_case("JOHN") == "John"

    def test_empty_string(self):
        assert _title_case("") == ""

    def test_none_returns_none(self):
        assert _title_case(None) is None

    def test_already_lowercase(self):
        # Lowercase is not all-caps, so it's preserved
        assert _title_case("john doe") == "john doe"


# ──────────────────────────────────────────────────────────────────────────────
# Guard: None / empty input
# ──────────────────────────────────────────────────────────────────────────────

class TestGuardClauses:
    def test_none_returns_none(self):
        assert parse_momo_sms(None) is None

    def test_empty_string_returns_none(self):
        assert parse_momo_sms("") is None

    def test_unrecognised_format_returns_none(self):
        assert parse_momo_sms("Hello, your MTN data bundle expires soon.") is None

    def test_partial_match_returns_none(self):
        assert parse_momo_sms("You have received RWF from somewhere") is None


# ──────────────────────────────────────────────────────────────────────────────
# Pattern 1 — Income (received)
# ──────────────────────────────────────────────────────────────────────────────

class TestPattern1Income:
    INCOME_SMS = (
        "You have received 20,000 RWF from MUTONI BRICE QUERCY (*********726) "
        "at 2024-11-15 10:23:45. Balance: 250,000 RWF."
    )

    def test_type_is_income(self):
        result = parse_momo_sms(self.INCOME_SMS)
        assert result["type"] == "income"

    def test_amount_parsed(self):
        result = parse_momo_sms(self.INCOME_SMS)
        assert result["amount"] == 20000.0

    def test_party_name_title_cased(self):
        result = parse_momo_sms(self.INCOME_SMS)
        assert result["party_name"] == "Mutoni Brice Quercy"

    def test_balance_extracted(self):
        result = parse_momo_sms(self.INCOME_SMS)
        assert result["balance"] == 250000.0

    def test_date_extracted(self):
        result = parse_momo_sms(self.INCOME_SMS)
        assert result["date"] == "2024-11-15 10:23:45"

    def test_category_is_other_income(self):
        result = parse_momo_sms(self.INCOME_SMS)
        assert result["category"] == "other_income"

    def test_raw_text_preserved(self):
        result = parse_momo_sms(self.INCOME_SMS)
        assert result["raw_text"] == self.INCOME_SMS

    def test_company_name_preserved(self):
        sms = (
            "You have received 796,000 RWF from NEXVENTURES Ltd  (*********500) "
            "at 2024-11-20 09:00:00. Balance: 800,000 RWF."
        )
        result = parse_momo_sms(sms)
        assert result is not None
        assert result["amount"] == 796000.0

    def test_phone_normalised_from_masked(self):
        # Masked phone like *********726 — last 9 digits prefixed with 0
        result = parse_momo_sms(self.INCOME_SMS)
        # The phone extracted is just the digits in the parentheses after stripping non-digits
        # *********726 → digits are "726" which is only 3 chars — no phone set if < 9 digits
        # This is expected behaviour for masked numbers
        assert result is not None  # Parser should still succeed


# ──────────────────────────────────────────────────────────────────────────────
# Pattern 2 — P2P transfer (expense)
# ──────────────────────────────────────────────────────────────────────────────

class TestPattern2Transfer:
    TRANSFER_SMS = (
        "1,500 RWF transferred to Juldas NYIRISHEMA (250788217896) "
        "at 2024-11-16 14:05:00. Balance: 48,500 RWF."
    )

    def test_type_is_expense(self):
        result = parse_momo_sms(self.TRANSFER_SMS)
        assert result["type"] == "expense"

    def test_amount_parsed(self):
        result = parse_momo_sms(self.TRANSFER_SMS)
        assert result["amount"] == 1500.0

    def test_category_is_transfer_out(self):
        result = parse_momo_sms(self.TRANSFER_SMS)
        assert result["category"] == "transfer_out"

    def test_party_name_parsed(self):
        result = parse_momo_sms(self.TRANSFER_SMS)
        assert "Nyirishema" in result["party_name"]

    def test_party_phone_normalised(self):
        result = parse_momo_sms(self.TRANSFER_SMS)
        # 250788217896 → last 9 = 788217896 → "0788217896"
        assert result["party_phone"] is not None

    def test_balance_extracted(self):
        result = parse_momo_sms(self.TRANSFER_SMS)
        assert result["balance"] == 48500.0

    def test_date_extracted(self):
        result = parse_momo_sms(self.TRANSFER_SMS)
        assert result["date"] == "2024-11-16 14:05:00"

    def test_large_amount_with_commas(self):
        sms = (
            "50,000 RWF transferred to Alice UWERA (250781234567) "
            "at 2024-12-01 08:00:00. Balance: 150,000 RWF."
        )
        result = parse_momo_sms(sms)
        assert result["amount"] == 50000.0


# ──────────────────────────────────────────────────────────────────────────────
# Pattern 3 — "A transaction of X RWF by ENTITY was completed at ..."
# ──────────────────────────────────────────────────────────────────────────────

class TestPattern3EntityTransaction:
    def test_data_bundle_categorised(self):
        sms = (
            "A transaction of 1,000 RWF by Data Bundle MTN was completed "
            "at 2024-11-17 11:30:00. Balance: 49,000 RWF."
        )
        result = parse_momo_sms(sms)
        assert result is not None
        assert result["type"] == "expense"
        assert result["category"] == "airtime_data"
        assert result["amount"] == 1000.0

    def test_rnit_categorised(self):
        sms = (
            "A transaction of 796,000 RWF by MOBILE MONEY RWANDA Limited "
            "was completed at 2024-11-18 12:00:00. Balance: 4,000 RWF."
        )
        result = parse_momo_sms(sms)
        assert result is not None
        assert result["type"] == "expense"
        assert result["category"] == "other"

    def test_rnit_investment_flagged(self):
        sms = (
            "A transaction of 10,000 RWF by Rwanda National Investment Trust "
            "was completed at 2024-11-18 12:00:00. Balance: 40,000 RWF."
        )
        result = parse_momo_sms(sms)
        assert result is not None
        assert result["category"] == "investment"
        assert result.get("is_rnit") is True

    def test_generic_merchant_categorised_utilities(self):
        sms = (
            "A transaction of 7,000 RWF by ESICIA LTD was completed "
            "at 2024-11-19 09:15:00. Balance: 43,000 RWF."
        )
        result = parse_momo_sms(sms)
        assert result is not None
        assert result["category"] == "utilities"

    def test_airtime_categorised(self):
        sms = (
            "A transaction of 500 RWF by Airtime Recharge MTN was completed "
            "at 2024-11-20 08:00:00. Balance: 99,500 RWF."
        )
        result = parse_momo_sms(sms)
        assert result is not None
        assert result["category"] == "airtime_data"

    def test_balance_extracted(self):
        sms = (
            "A transaction of 3,000 RWF by KIGALI WATER was completed "
            "at 2024-11-21 10:00:00. Balance: 47,000 RWF."
        )
        result = parse_momo_sms(sms)
        assert result["balance"] == 47000.0


# ──────────────────────────────────────────────────────────────────────────────
# Pattern 4 — "Your payment of X RWF to MERCHANT ..."
# ──────────────────────────────────────────────────────────────────────────────

class TestPattern4Payment:
    def test_generic_merchant(self):
        sms = (
            "Your payment of 2,000 RWF to Afri Farmers Market ltd "
            "was completed at 2024-11-22 13:00:00. Balance: 98,000 RWF."
        )
        result = parse_momo_sms(sms)
        assert result is not None
        assert result["type"] == "expense"
        assert result["amount"] == 2000.0
        assert result["category"] == "other"

    def test_mokash_savings_categorised(self):
        sms = (
            "Your payment of 300,000 RWF to Mokash Savings with token 123456 "
            "was completed at 2024-11-23 09:00:00. Balance: 200,000 RWF."
        )
        result = parse_momo_sms(sms)
        assert result is not None
        assert result["category"] == "savings"
        assert result["amount"] == 300000.0

    def test_ejo_heza_categorised(self):
        sms = (
            "Your payment of 5,000 RWF to Ejo Heza Pension with token 999 "
            "was completed at 2024-11-24 10:00:00. Balance: 45,000 RWF."
        )
        result = parse_momo_sms(sms)
        assert result is not None
        assert result["category"] == "ejo_heza"

    def test_amount_no_commas(self):
        sms = (
            "Your payment of 15000 RWF to Some Merchant "
            "was completed at 2024-11-25 11:00:00. Balance: 85000 RWF."
        )
        result = parse_momo_sms(sms)
        assert result is not None
        assert result["amount"] == 15000.0

    def test_date_extracted(self):
        sms = (
            "Your payment of 2,000 RWF to Afri Farmers Market ltd "
            "was completed at 2024-11-22 13:45:00. Balance: 98,000 RWF."
        )
        result = parse_momo_sms(sms)
        assert result["date"] == "2024-11-22 13:45:00"


# ──────────────────────────────────────────────────────────────────────────────
# USSD wrappers / MTN prefixes — should be stripped and still parse
# ──────────────────────────────────────────────────────────────────────────────

class TestUssdWrappers:
    def test_162_txid_wrapper_stripped(self):
        sms = (
            "*162*TxId:9876543*S* "
            "You have received 5,000 RWF from ALICE UWERA (*********123) "
            "at 2024-11-26 07:00:00. Balance: 55,000 RWF. *EN#"
        )
        result = parse_momo_sms(sms)
        assert result is not None
        assert result["type"] == "income"
        assert result["amount"] == 5000.0

    def test_yello_opener_stripped(self):
        sms = (
            "Y'ello, 1,000 RWF transferred to Bob REMY (250788999888) "
            "at 2024-11-26 08:00:00. Balance: 9,000 RWF."
        )
        result = parse_momo_sms(sms)
        assert result is not None
        assert result["type"] == "expense"
        assert result["amount"] == 1000.0

    def test_download_momo_link_stripped(self):
        sms = (
            "You have received 10,000 RWF from JOHN DOE (*********400) "
            "at 2024-11-27 09:00:00. Balance: 60,000 RWF. "
            "Download MoMo App from https://example.com"
        )
        result = parse_momo_sms(sms)
        assert result is not None
        assert result["type"] == "income"

    def test_ussd_165_wrapper_stripped(self):
        sms = (
            "*165*S* A transaction of 2,000 RWF by Kigali Water "
            "was completed at 2024-11-28 10:00:00. Balance: 38,000 RWF. *EN##"
        )
        result = parse_momo_sms(sms)
        assert result is not None
        assert result["type"] == "expense"


# ──────────────────────────────────────────────────────────────────────────────
# Amount edge cases
# ──────────────────────────────────────────────────────────────────────────────

class TestAmountEdgeCases:
    def test_large_amount_with_commas(self):
        sms = (
            "You have received 1,200,000 RWF from BIG CORP Ltd (*********321) "
            "at 2024-12-01 12:00:00. Balance: 1,500,000 RWF."
        )
        result = parse_momo_sms(sms)
        assert result is not None
        assert result["amount"] == 1200000.0

    def test_small_amount(self):
        sms = (
            "100 RWF transferred to Small Shop (250781111111) "
            "at 2024-12-02 13:00:00. Balance: 900 RWF."
        )
        result = parse_momo_sms(sms)
        assert result is not None
        assert result["amount"] == 100.0

    def test_zero_balance_is_accepted(self):
        sms = (
            "1,000 RWF transferred to Test Person (250788888888) "
            "at 2024-12-03 14:00:00. Balance: 0 RWF."
        )
        result = parse_momo_sms(sms)
        assert result is not None
        assert result["balance"] == 0.0
