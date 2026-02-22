import re
from datetime import datetime


def _title_case(name: str) -> str:
    """Title-case ALL-CAPS names from MoMo; leave already-mixed strings alone."""
    if not name:
        return name
    return name.title() if name == name.upper() else name

def parse_momo_sms(sms_text: str):
    """
    Parse an MTN MoMo SMS into structured transaction data.

    Returns a dict with keys:
        date, amount, type (income/expense), category, party_name,
        party_phone, balance, raw_text
    or None if the message could not be parsed.
    """
    if not sms_text:
        return None

    # ── Clean known MTN prefixes / suffixes ───────────────────────────
    clean = sms_text
    # "*162*TxId:12345*S*", "*164*TxId:12345*S*", etc.
    clean = re.sub(r'\*16\d\*TxId:\d+\*S\*', '', clean)
    # Bare "TxId:12345*S*" (no leading *16X*)
    clean = re.sub(r'TxId:\d+\*S\*', '', clean)
    # USSD wrappers "*164*S*", "*165*S*", "*162*S*" …
    clean = re.sub(r'\*16\d\*S\*', '', clean)
    # Closing tags
    clean = clean.replace("*EN##", "").replace("*EN#", "")
    # "Y'ello, " opener
    clean = re.sub(r"^Y'ello,\s*", '', clean.strip(), flags=re.IGNORECASE)
    # Trailing promotional / download links
    clean = re.sub(r'Download\s+MoMo.*$', '', clean, flags=re.IGNORECASE | re.DOTALL)
    clean = clean.strip()

    data = {
        "date": None,
        "amount": 0.0,
        "type": None,
        "category": "other",
        "party_name": None,
        "party_phone": None,
        "balance": 0.0,
        "raw_text": sms_text,
    }

    # ── PATTERN 1: RECEIVED (Income) ─────────────────────────────────
    # "You have received 20000 RWF from MUTONI BRICE QUERCY (*********726) at ..."
    # "You have received 796000 RWF from NEXVENTURES Ltd  (*********500) at ..."
    m = re.search(
        r'You have received ([\d,]+) RWF from (.*?)\s*\(([^)]+)\) at ([\d-]+ [\d:]+)',
        clean, re.IGNORECASE
    )
    if m:
        data["type"] = "income"
        data["category"] = "other_income"
        data["amount"] = float(m.group(1).replace(",", ""))
        data["party_name"] = _title_case(m.group(2).strip())
        phone = re.sub(r'[^\d]', '', m.group(3))
        if len(phone) >= 9:
            data["party_phone"] = "0" + phone[-9:] if not phone.startswith("07") else phone
        data["date"] = m.group(4)
        m_bal = re.search(r'Balance:\s*([\d,]+)', clean)
        if m_bal:
            data["balance"] = float(m_bal.group(1).replace(",", ""))
        return data

    # ── PATTERN 2: SENT P2P (Expense) ────────────────────────────────
    # "1500 RWF transferred to Juldas NYIRISHEMA (250788217896) at ..."
    m = re.search(
        r'([\d,]+) RWF transferred to (.*?)\s*\((25\d{9}|07\d{8})\) at ([\d-]+ [\d:]+)',
        clean, re.IGNORECASE
    )
    if m:
        data["type"] = "expense"
        data["category"] = "transfer_out"
        data["amount"] = float(m.group(1).replace(",", ""))
        data["party_name"] = _title_case(m.group(2).strip())
        phone = m.group(3)
        data["party_phone"] = "0" + phone[-9:] if not phone.startswith("07") else phone
        data["date"] = m.group(4)
        m_bal = re.search(r'Balance:\s*([\d,]+)', clean)
        if m_bal:
            data["balance"] = float(m_bal.group(1).replace(",", ""))
        return data

    # ── PATTERN 3: "A transaction of X RWF by ENTITY was completed at …" ──
    # "A transaction of 100 RWF by Data Bundle MTN was completed at ..."
    # "A transaction of 796000 RWF by MOBILE MONEY RWANDA Limited was completed at ..."
    # "A transaction of 7000 RWF by ESICIA LTD was completed at ..."
    m = re.search(
        r'A transaction of ([\d,]+) RWF by (.*?) was completed at ([\d-]+ [\d:]+)',
        clean, re.IGNORECASE
    )
    if m:
        data["type"] = "expense"
        data["amount"] = float(m.group(1).replace(",", ""))
        party = m.group(2).strip()
        data["party_name"] = _title_case(party)
        data["date"] = m.group(3)
        m_bal = re.search(r'Balance:\s*([\d,]+)', clean)
        if m_bal:
            data["balance"] = float(m_bal.group(1).replace(",", ""))
        pl = party.lower()
        if "data bundle" in pl or "airtime" in pl:
            data["category"] = "airtime_data"
        elif "mobile money rwanda" in pl:
            data["category"] = "other"   # cash-out / agent withdrawal
        else:
            data["category"] = "utilities"   # bill / merchant
        return data

    # ── PATTERN 4: "Your payment of X RWF to MERCHANT …" ─────────────
    # "Your payment of 2,000 RWF to Afri Farmers Market ltd ... was completed at ..."
    # "Your payment of 300000 RWF to Mokash Savings with token ..."
    m = re.search(
        r'Your payment of ([\d,]+) RWF to (.*?) (?:with token|was completed)',
        clean, re.IGNORECASE
    )
    if m:
        data["type"] = "expense"
        data["amount"] = float(m.group(1).replace(",", ""))
        party = m.group(2).strip()
        data["party_name"] = _title_case(party)
        m_date = re.search(r'completed at ([\d-]+ [\d:]+)', clean)
        if m_date:
            data["date"] = m_date.group(1)
        m_bal = re.search(r'Balance:\s*([\d,]+)', clean)
        if m_bal:
            data["balance"] = float(m_bal.group(1).replace(",", ""))
        pl = party.lower()
        if "mokash" in pl:
            data["category"] = "savings"
        elif "ejo heza" in pl:
            data["category"] = "ejo_heza"
        else:
            data["category"] = "other"
        return data

    return None  # unrecognised format

# --- RUN THE PARSER ---
# parsed_records = []
# for sms in raw_messages:
#     result = parse_momo_sms(sms)
#     if result:
#         parsed_records.append(result)

# # Convert to DataFrame for easy viewing/saving
# df = pd.DataFrame(parsed_records)

# # --- SAVE TO CSV ---
# # This CSV is exactly what your BiLSTM model needs to load!
# df.to_csv("my_momo_history.csv", index=False)

# print(df[['date', 'category', 'amount', 'type', 'party']])
