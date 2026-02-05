"""
SMS Parser Service
==================
Parses MoMo SMS messages into structured transaction data.
"""

import re
from datetime import datetime
from typing import Optional, Dict
import hashlib


def parse_momo_sms(sms_text: str) -> Optional[Dict]:
    """
    Parse a MoMo (Mobile Money) SMS message into structured transaction data.
    
    Supports common Rwandan MoMo message formats:
    - MTN Mobile Money
    - Airtel Money
    
    Args:
        sms_text: Raw SMS text
        
    Returns:
        Dict with parsed transaction data or None if parsing fails
    """
    if not sms_text:
        return None
    
    # Normalize text
    text = sms_text.strip().upper()
    
    # Common patterns
    amount_pattern = r'(?:RWF|FRW)\s*([\d,]+(?:\.\d{2})?)'
    phone_pattern = r'(?:07[238]\d{7}|(?:\+?250)?7[238]\d{7})'
    ref_pattern = r'(?:REF|TXN|ID)[:\s]*([A-Z0-9]+)'
    
    result = {
        "transaction_type": None,
        "amount": 0,
        "counterparty": None,
        "description": None,
        "reference": None,
        "transaction_date": datetime.now(),
        "confidence": 0.8
    }
    
    # Try to extract reference
    ref_match = re.search(ref_pattern, text)
    if ref_match:
        result["reference"] = ref_match.group(1)
    else:
        # Generate reference from SMS hash
        result["reference"] = hashlib.md5(sms_text.encode()).hexdigest()[:12].upper()
    
    # Extract amount
    amount_match = re.search(amount_pattern, text)
    if amount_match:
        amount_str = amount_match.group(1).replace(',', '')
        result["amount"] = float(amount_str)
    else:
        return None  # Can't parse without amount
    
    # Extract counterparty phone
    phone_match = re.search(phone_pattern, text)
    if phone_match:
        phone = phone_match.group()
        # Normalize phone
        if phone.startswith('+250'):
            phone = '0' + phone[4:]
        elif phone.startswith('250'):
            phone = '0' + phone[3:]
        result["counterparty"] = phone
    
    # Determine transaction type based on keywords
    income_keywords = [
        'RECEIVED', 'CREDITED', 'DEPOSIT', 'PAYMENT RECEIVED',
        'TRANSFER FROM', 'YOU HAVE RECEIVED', 'INCOMING'
    ]
    expense_keywords = [
        'SENT', 'PAID', 'DEBITED', 'WITHDRAWN', 'TRANSFER TO',
        'PAYMENT TO', 'PURCHASE', 'BILL PAYMENT', 'AIRTIME'
    ]
    
    for keyword in income_keywords:
        if keyword in text:
            result["transaction_type"] = "income"
            result["description"] = f"Mobile Money received"
            break
    
    if not result["transaction_type"]:
        for keyword in expense_keywords:
            if keyword in text:
                result["transaction_type"] = "expense"
                result["description"] = f"Mobile Money payment"
                break
    
    # Default to expense if can't determine
    if not result["transaction_type"]:
        result["transaction_type"] = "expense"
        result["description"] = "Mobile Money transaction"
        result["confidence"] = 0.5
    
    # Try to extract more context
    if 'AIRTIME' in text or 'DATA' in text or 'BUNDLE' in text:
        result["description"] = "Airtime/Data purchase"
    elif 'BILL' in text or 'UTILITY' in text:
        result["description"] = "Bill payment"
    elif 'SALARY' in text or 'WAGE' in text:
        result["description"] = "Salary payment"
        result["transaction_type"] = "income"
    elif 'EJO HEZA' in text:
        result["description"] = "Ejo Heza contribution"
    
    return result


def batch_parse_sms(messages: list) -> list:
    """
    Parse multiple SMS messages.
    
    Args:
        messages: List of SMS text strings
        
    Returns:
        List of successfully parsed transactions
    """
    parsed = []
    for msg in messages:
        result = parse_momo_sms(msg)
        if result:
            parsed.append(result)
    return parsed
