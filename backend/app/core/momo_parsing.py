import re
import pandas as pd
from datetime import datetime

# The raw messages you provided (plus a few for testing)
raw_messages = [
    "You have received 20000 RWF from MUTONI BRICE QUERCY (*********726) at 2026-02-04 22:21:22. Balance:31135 RWF. FT Id: 25882888464.",
    "*164*S*Y'ello, A transaction of 200 RWF by Data Bundle MTN was completed at 2026-02-05 09:14:49. Balance:15335 RWF. Fee  0 RWF. FT Id: 25886838746. ET  Id: 17702756692420243.*EN#",
    "*165*S*1500 RWF transferred to JeanClaude GAKWAYA (250784801000) at 2026-02-05 01:30:22 .Fee : 100 RWF. Balance: 15535 RWF. *EN##",
    "*164*S*Y'ello, A transaction of 180000 RWF by MOBILE MONEY RWANDA Limited was completed at 2026-02-02 15:59:51. Balance:2285 RWF. Fee  0 RWF. FT Id: 25830067687. ET  Id: 36212f1f-b897-40af-b42f-7614315f712c.*EN#",
    "*162*TxId:25828436828*S*Your payment of 300000 RWF to Mokash Savings with token  and ET Id: 20260202000000007375816905 was completed at 2026-02-02 14:38:20. Fee 0 RWF. Balance: 32285 RWF . Message: - Y'ello. RWF 300000 transferred to your Mokash account on 2:38 PM at 02/02/2026. Your new Mokash account balance is RWF 300000.Ref 25828436828. *EN#",
    "TxId:25814160288*S*Your payment of 1,500 RWF to Charlotte 1676815 was completed at 2026-02-01 19:25:05.  Balance: 367,835 RWF. Fee 0 RWF.*EN# Download MoMoApp https://tinyurl.com/yc8peh4d and get 5% CASHBACK when you pay merchants using the App"
]

def parse_momo_sms(sms_text):
    # 1. Clean the messy prefixes/suffixes common in MTN SMS
    clean_text = sms_text.replace("*164*S*", "").replace("*165*S*", "").replace("*EN#", "").replace("*EN##", "")
    
    # Initialize default values
    data = {
        "date": None,
        "amount": 0.0,
        "type": "Unknown", # Credit or Debit
        "category": "Uncategorized",
        "party": "Unknown", # Who sent/received
        "balance": 0.0,
        "raw_text": sms_text
    }

    # --- PATTERN 1: RECEIVED MONEY (P2P Income) ---
    # "You have received 20000 RWF from MUTONI..."
    match_recv = re.search(r"You have received ([\d,]+) RWF from (.*?) \(.*?\) at ([\d-]+\s[\d:]+)\.\s*Balance:([\d,]+)", clean_text)
    if match_recv:
        data["type"] = "Income"
        data["category"] = "Transfer_In"
        data["amount"] = float(match_recv.group(1).replace(",", ""))
        data["party"] = match_recv.group(2).strip()
        data["date"] = match_recv.group(3)
        data["balance"] = float(match_recv.group(4).replace(",", ""))
        return data

    # --- PATTERN 2: SENT MONEY (P2P Expense) ---
    # "1500 RWF transferred to JeanClaude..."
    match_sent = re.search(r"([\d,]+) RWF transferred to (.*?) \(.*?\) at ([\d-]+\s[\d:]+)", clean_text)
    if match_sent:
        data["type"] = "Expense"
        data["category"] = "Transfer_Out"
        data["amount"] = float(match_sent.group(1).replace(",", ""))
        data["party"] = match_sent.group(2).strip()
        data["date"] = match_sent.group(3)
        # Extract balance separately because it's further down in the string
        match_bal = re.search(r"Balance:\s*([\d,]+)", clean_text)
        if match_bal: data["balance"] = float(match_bal.group(1).replace(",", ""))
        return data

    # --- PATTERN 3: PAYMENT / BILLS / BUNDLES ---
    # "A transaction of 200 RWF by Data Bundle MTN..." OR "by MOBILE MONEY RWANDA..."
    match_trans = re.search(r"A transaction of ([\d,]+) RWF by (.*?) was completed at ([\d-]+\s[\d:]+)\.\s*Balance:([\d,]+)", clean_text)
    if match_trans:
        data["type"] = "Expense"
        data["amount"] = float(match_trans.group(1).replace(",", ""))
        data["party"] = match_trans.group(2).strip()
        data["date"] = match_trans.group(3)
        data["balance"] = float(match_trans.group(4).replace(",", ""))
        
        # Auto-Categorization Logic
        if "Data Bundle" in data["party"] or "Airtime" in data["party"]:
            data["category"] = "Data & Airtime"
        elif "MOBILE MONEY RWANDA" in data["party"]: 
            # Often cash-outs or bank pulls, but treated as 'Financial' or 'General'
            data["category"] = "Financial" 
        else:
            data["category"] = "Bill Payment"
        return data

    # --- PATTERN 4: MERCHANT PAYMENTS / MOKASH ---
    # "Your payment of 300000 RWF to Mokash Savings..."
    match_pay = re.search(r"Your payment of ([\d,]+) RWF to (.*?) (?:with|was completed at) ([\d-]+\s[\d:]+)?", clean_text)
    if match_pay:
        data["type"] = "Expense" # Technically money leaving main wallet
        data["amount"] = float(match_pay.group(1).replace(",", ""))
        party_raw = match_pay.group(2).strip()
        
        # Extract Date (It might be later in the string for MoKash)
        match_date = re.search(r"completed at ([\d-]+\s[\d:]+)", clean_text)
        if match_date: data["date"] = match_date.group(1)

        match_bal = re.search(r"Balance:\s*([\d,]+)", clean_text)
        if match_bal: data["balance"] = float(match_bal.group(1).replace(",", ""))

        # Categorization
        if "Mokash Savings" in party_raw:
            data["category"] = "Savings" # CRITICAL: This is 'Good' spending
            data["party"] = "MoKash"
        else:
            data["category"] = "Merchant Pay"
            data["party"] = party_raw
        return data

    return None # Message didn't match known patterns

# --- RUN THE PARSER ---
parsed_records = []
for sms in raw_messages:
    result = parse_momo_sms(sms)
    if result:
        parsed_records.append(result)

# Convert to DataFrame for easy viewing/saving
df = pd.DataFrame(parsed_records)

# --- SAVE TO CSV ---
# This CSV is exactly what your BiLSTM model needs to load!
df.to_csv("my_momo_history.csv", index=False)

print(df[['date', 'category', 'amount', 'type', 'party']])