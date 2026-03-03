"""
Transaction Endpoints
=====================
CRUD operations and SMS parsing for transactions.
"""

from typing import List, Optional
from datetime import datetime, timedelta
from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from sqlalchemy import func, and_

from app.models.base import get_db, SessionLocal
from app.models.transaction import Transaction, CounterpartyMapping, TransactionType as ModelTransactionType
from app.models.transaction import TransactionCategory as ModelCategory, NeedWantCategory as ModelNeedWant
from app.models.prediction import Recommendation
from app.models.user import User as UserModel
from app.schemas.transaction import (
    TransactionCreate, TransactionUpdate, TransactionResponse,
    TransactionListResponse, TransactionSummary,
    SMSParseRequest, SMSParseResponse,
    CounterpartyMappingCreate, CounterpartyMappingResponse,
    TransactionType, TransactionCategory, NeedWantCategory
)
from app.schemas.user import TokenPayload
from app.core.deps import get_current_active_user
from app.core.momo_parsing import parse_momo_sms as _parse_momo_sms
from app.models.rnit import RnitPurchase
from app.services.rnit_nav import get_nav_on_date
from app.core import nudge_service
import hashlib
import re as _re


def _has_recent_mokash_withdrawal(db: Session, user_id: int, amount: float) -> bool:
    """Check if a MoKash withdrawal of ``amount`` was saved in the last 2 hours.

    Used to detect when the corresponding MoMo 'received' SMS is a self-transfer
    (money returning from MoKash savings) rather than genuine income.
    """
    from datetime import timedelta
    cutoff = datetime.now() - timedelta(hours=2)
    return (
        db.query(Transaction)
        .filter(
            Transaction.user_id == user_id,
            Transaction.transaction_type == ModelTransactionType.TRANSFER,
            Transaction.category == ModelCategory.SAVINGS,
            Transaction.amount == amount,
            Transaction.transaction_date >= cutoff,
        )
        .first()
        is not None
    )


def _trigger_income_nudge(user_id: int, income_amount: float, income_source: Optional[str]) -> None:
    """Background task: generate an income nudge via Claude after an income SMS is parsed."""
    db = SessionLocal()
    try:
        nudge_service.generate_nudges(
            user_id=user_id,
            db=db,
            trigger_type="income",
            income_amount=income_amount,
            income_source=income_source,
        )
    except Exception:
        pass
    finally:
        db.close()


_SAVINGS_CATEGORIES = {
    ModelCategory.SAVINGS,
    ModelCategory.EJO_HEZA,
    ModelCategory.INVESTMENT,
}


def _close_income_nudges(user_id: int, db: Session) -> None:
    """Mark recent unacted income nudges as acted upon when a savings transaction arrives."""
    cutoff = datetime.now() - timedelta(hours=48)
    db.query(Recommendation).filter(
        Recommendation.user_id == user_id,
        Recommendation.trigger_type == "income",
        Recommendation.is_acted_upon == False,
        Recommendation.is_dismissed == False,
        Recommendation.created_at >= cutoff,
    ).update({"is_acted_upon": True, "acted_at": datetime.now()}, synchronize_session=False)
    db.commit()


def _adapt_parsed(result: dict, raw_sms: str) -> dict:
    """Map app.core.momo_parsing output to the dict shape expected by the endpoint."""
    transaction_date = datetime.now()
    if result.get("date"):
        try:
            transaction_date = datetime.strptime(result["date"], "%Y-%m-%d %H:%M:%S")
        except ValueError:
            pass

    reference = result.get("mokash_ref") or hashlib.md5(raw_sms.encode()).hexdigest()[:12].upper()

    party_name = result.get("party_name") or result.get("party")
    party_phone = result.get("party_phone")

    need_want_map = {
        "airtime_data": "need",
        "utilities": "need",
        "food_groceries": "need",
        "transport": "need",
        "healthcare": "need",
        "education": "need",
        "savings": "savings",
        "ejo_heza": "savings",
        "investment": "savings",
    }
    category = result.get("category", "other")
    need_want = need_want_map.get(category, "uncategorized")

    raw_balance = result.get("balance") or result.get("balance_after")
    balance_after = float(raw_balance) if raw_balance else None

    return {
        "transaction_type": result.get("type", "expense"),
        "amount": result.get("amount", 0.0),
        "counterparty": party_phone or party_name,
        "counterparty_name": party_name,
        "description": party_name,
        "category": category,
        "need_want": need_want,
        "reference": reference,
        "transaction_date": transaction_date,
        "confidence": 0.9,
        "is_rnit": result.get("is_rnit", False),
        "balance_after": balance_after,
    }


def parse_momo_sms(sms_text: str):
    result = _parse_momo_sms(sms_text)
    if result is None:
        return None
    return _adapt_parsed(result, sms_text)

router = APIRouter()


@router.get("", response_model=TransactionListResponse)
async def get_transactions(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=500),
    transaction_type: Optional[TransactionType] = None,
    category: Optional[TransactionCategory] = None,
    start_date: Optional[datetime] = None,
    end_date: Optional[datetime] = None,
    current_user: TokenPayload = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """
    Get paginated list of transactions for the current user.
    """
    query = db.query(Transaction).filter(
        Transaction.user_id == int(current_user.sub)
    )
    
    # Apply filters
    if transaction_type:
        query = query.filter(Transaction.transaction_type == ModelTransactionType(transaction_type.value))
    if category:
        query = query.filter(Transaction.category == ModelCategory(category.value))
    if start_date:
        query = query.filter(Transaction.transaction_date >= start_date)
    if end_date:
        query = query.filter(Transaction.transaction_date <= end_date)
    
    # Get total count
    total = query.count()
    
    # Paginate
    transactions = query.order_by(Transaction.transaction_date.desc()) \
        .offset((page - 1) * page_size) \
        .limit(page_size) \
        .all()
    
    total_pages = (total + page_size - 1) // page_size
    
    return TransactionListResponse(
        transactions=[TransactionResponse.model_validate(t) for t in transactions],
        total=total,
        page=page,
        page_size=page_size,
        total_pages=total_pages
    )


@router.post("", response_model=TransactionResponse, status_code=status.HTTP_201_CREATED)
async def create_transaction(
    transaction_data: TransactionCreate,
    current_user: TokenPayload = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """
    Create a new transaction manually.
    """
    transaction = Transaction(
        user_id=int(current_user.sub),
        transaction_type=ModelTransactionType(transaction_data.transaction_type.value),
        category=ModelCategory(transaction_data.category.value),
        need_want=ModelNeedWant(transaction_data.need_want.value),
        amount=transaction_data.amount,
        description=transaction_data.description,
        counterparty=transaction_data.counterparty,
        counterparty_name=transaction_data.counterparty_name,
        reference=transaction_data.reference,
        raw_sms=transaction_data.raw_sms,
        transaction_date=transaction_data.transaction_date,
        is_verified=True  # Manual transactions are verified
    )
    
    db.add(transaction)
    db.commit()
    db.refresh(transaction)
    
    return TransactionResponse.model_validate(transaction)


@router.get("/summary", response_model=TransactionSummary)
async def get_transaction_summary(
    start_date: Optional[datetime] = None,
    end_date: Optional[datetime] = None,
    current_user: TokenPayload = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """
    Get transaction summary for a period.
    """
    user_id = int(current_user.sub)
    
    # Query transactions in date range (all-time if no dates provided)
    query = db.query(Transaction).filter(Transaction.user_id == user_id)
    if start_date:
        query = query.filter(Transaction.transaction_date >= start_date)
    if end_date:
        query = query.filter(Transaction.transaction_date <= end_date)
    transactions = query.all()
    
    # Calculate totals
    total_income = sum(t.amount for t in transactions if t.transaction_type == ModelTransactionType.INCOME)
    total_expenses = sum(t.amount for t in transactions if t.transaction_type == ModelTransactionType.EXPENSE)
    
    # Category breakdown (expenses only — transfers excluded)
    category_breakdown = {}
    for t in transactions:
        if t.transaction_type == ModelTransactionType.EXPENSE:
            cat = t.category.value if t.category else "other"
            if cat not in category_breakdown:
                category_breakdown[cat] = 0
            category_breakdown[cat] += t.amount
    
    # Need/Want breakdown
    need_want_breakdown = {"need": 0, "want": 0, "savings": 0, "uncategorized": 0}
    for t in transactions:
        if t.transaction_type == ModelTransactionType.EXPENSE:
            nw = t.need_want.value if t.need_want else "uncategorized"
            need_want_breakdown[nw] += t.amount
    
    return TransactionSummary(
        total_income=total_income,
        total_expenses=total_expenses,
        net_flow=total_income - total_expenses,
        transaction_count=len(transactions),
        category_breakdown=category_breakdown,
        need_want_breakdown=need_want_breakdown
    )


@router.get("/{transaction_id}", response_model=TransactionResponse)
async def get_transaction(
    transaction_id: int,
    current_user: TokenPayload = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """
    Get a specific transaction.
    """
    transaction = db.query(Transaction).filter(
        and_(
            Transaction.id == transaction_id,
            Transaction.user_id == int(current_user.sub)
        )
    ).first()
    
    if not transaction:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Transaction not found"
        )
    
    return TransactionResponse.model_validate(transaction)


@router.patch("/{transaction_id}", response_model=TransactionResponse)
async def update_transaction(
    transaction_id: int,
    update_data: TransactionUpdate,
    current_user: TokenPayload = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """
    Update a transaction (e.g., correct category, verify).
    """
    transaction = db.query(Transaction).filter(
        and_(
            Transaction.id == transaction_id,
            Transaction.user_id == int(current_user.sub)
        )
    ).first()
    
    if not transaction:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Transaction not found"
        )
    
    # Update fields
    if update_data.category is not None:
        transaction.category = ModelCategory(update_data.category.value)
    if update_data.need_want is not None:
        transaction.need_want = ModelNeedWant(update_data.need_want.value)
    if update_data.description is not None:
        transaction.description = update_data.description
    if update_data.counterparty_name is not None:
        transaction.counterparty_name = update_data.counterparty_name
    if update_data.is_verified is not None:
        transaction.is_verified = update_data.is_verified
    
    db.commit()
    db.refresh(transaction)
    
    # Update counterparty mapping if category changed
    if update_data.category and transaction.counterparty:
        existing_mapping = db.query(CounterpartyMapping).filter(
            and_(
                CounterpartyMapping.user_id == int(current_user.sub),
                CounterpartyMapping.counterparty == transaction.counterparty
            )
        ).first()
        
        if existing_mapping:
            existing_mapping.category = transaction.category
            if update_data.need_want:
                existing_mapping.need_want = transaction.need_want
        else:
            new_mapping = CounterpartyMapping(
                user_id=int(current_user.sub),
                counterparty=transaction.counterparty,
                display_name=transaction.counterparty_name,
                category=transaction.category,
                need_want=transaction.need_want
            )
            db.add(new_mapping)
        
        db.commit()
    
    return TransactionResponse.model_validate(transaction)


@router.delete("/{transaction_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_transaction(
    transaction_id: int,
    current_user: TokenPayload = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """
    Delete a transaction.
    """
    transaction = db.query(Transaction).filter(
        and_(
            Transaction.id == transaction_id,
            Transaction.user_id == int(current_user.sub)
        )
    ).first()
    
    if not transaction:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Transaction not found"
        )
    
    db.delete(transaction)
    db.commit()


@router.post("/parse-sms", response_model=SMSParseResponse)
async def parse_sms_messages(
    request: SMSParseRequest,
    background_tasks: BackgroundTasks,
    current_user: TokenPayload = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """
    Parse SMS messages and create transactions.
    Triggers an AI income nudge in the background when income is detected.
    """
    user_id = int(current_user.sub)
    parsed_transactions = []
    failed_count = 0

    # Get user's phone number suffix (last 3 digits) for self-transfer detection.
    # When money comes back from MoKash, MTN sends a 'received' SMS where the
    # sender phone shows the user's own number (masked). We compare the last 3
    # digits to detect and skip these false-income entries.
    user_obj = db.query(UserModel).filter(UserModel.id == user_id).first()
    user_phone_suffix = ""
    if user_obj and user_obj.phone_number:
        user_phone_digits = _re.sub(r'\D', '', user_obj.phone_number)
        user_phone_suffix = user_phone_digits[-3:] if len(user_phone_digits) >= 3 else ""

    # First pass: collect MoKash withdrawal amounts present in THIS batch so we
    # can skip the corresponding duplicate MoMo 'received' SMS below.
    mokash_withdrawal_amounts: set[float] = set()
    for sms_text in request.messages:
        raw = _parse_momo_sms(sms_text)
        if raw and raw.get("is_mokash_withdrawal"):
            mokash_withdrawal_amounts.add(float(raw["amount"]))
    
    # Get user's counterparty mappings for auto-categorization
    mappings = db.query(CounterpartyMapping).filter(
        CounterpartyMapping.user_id == user_id
    ).all()
    mapping_dict = {m.counterparty: m for m in mappings}
    
    for sms_text in request.messages:
        try:
            parsed = parse_momo_sms(sms_text)
            
            if parsed is None:
                failed_count += 1
                continue

            # ── Self-transfer detection ──────────────────────────────────
            # When the user withdraws money from MoKash, they receive TWO SMS:
            #   1. MoKash SMS → parsed above as type=transfer/category=savings ✓
            #   2. MoMo 'received' SMS from their own number → would be income ✗
            # Skip the second SMS to avoid inflating income.
            if parsed["transaction_type"] == "income" and user_phone_suffix:
                party_phone = parsed.get("counterparty") or ""
                phone_digits = _re.sub(r'\D', '', party_phone)
                if phone_digits.endswith(user_phone_suffix):
                    amount = float(parsed.get("amount", 0))
                    if (amount in mokash_withdrawal_amounts
                            or _has_recent_mokash_withdrawal(db, user_id, amount)):
                        continue  # skip — money returning from own MoKash savings
            
            # Check for duplicate
            if parsed.get("reference"):
                existing = db.query(Transaction).filter(
                    Transaction.reference == parsed["reference"]
                ).first()
                if existing:
                    continue
            
            # Auto-categorize: use existing counterparty mapping, else fall back to parser result
            counterparty_name = parsed.get("counterparty_name")
            if parsed.get("counterparty") and parsed["counterparty"] in mapping_dict:
                mapping = mapping_dict[parsed["counterparty"]]
                category = mapping.category
                need_want = mapping.need_want
                counterparty_name = mapping.display_name or counterparty_name
            else:
                try:
                    category = ModelCategory(parsed.get("category", "other"))
                except ValueError:
                    category = ModelCategory.OTHER
                try:
                    need_want = ModelNeedWant(parsed.get("need_want", "uncategorized"))
                except ValueError:
                    need_want = ModelNeedWant.UNCATEGORIZED

            transaction = Transaction(
                user_id=user_id,
                transaction_type=ModelTransactionType(parsed["transaction_type"]),
                category=category,
                need_want=need_want,
                amount=parsed["amount"],
                description=parsed.get("description"),
                counterparty=parsed.get("counterparty"),
                counterparty_name=counterparty_name,
                reference=parsed.get("reference"),
                raw_sms=sms_text,
                transaction_date=parsed["transaction_date"],
                confidence_score=parsed.get("confidence", 0.8),
                balance_after=parsed.get("balance_after"),
                is_verified=False
            )
            
            db.add(transaction)
            db.commit()
            db.refresh(transaction)

            # Auto-close income nudges if the user just saved / invested
            if transaction.category in _SAVINGS_CATEGORIES:
                try:
                    _close_income_nudges(user_id, db)
                except Exception:
                    pass

            # Auto-create RNIT purchase record
            if parsed.get("is_rnit"):
                purchase_date = parsed["transaction_date"]
                nav = get_nav_on_date(db, purchase_date)
                units = (transaction.amount / nav) if nav else None
                rnit_purchase = RnitPurchase(
                    user_id=user_id,
                    transaction_id=transaction.id,
                    purchase_date=purchase_date,
                    amount_rwf=transaction.amount,
                    nav_at_purchase=nav,
                    units=units,
                    raw_sms=sms_text,
                )
                db.add(rnit_purchase)
                db.commit()

            parsed_transactions.append(transaction)

        except Exception as e:
            failed_count += 1
            continue

    # Fire income nudge in background for any income transactions parsed
    income_transactions = [
        t for t in parsed_transactions if t.transaction_type == ModelTransactionType.INCOME
    ]
    if income_transactions:
        total_income = sum(t.amount for t in income_transactions)
        latest_income = max(income_transactions, key=lambda t: t.amount)
        background_tasks.add_task(
            _trigger_income_nudge,
            user_id,
            total_income,
            latest_income.counterparty_name or latest_income.counterparty,
        )

    return SMSParseResponse(
        parsed_count=len(parsed_transactions),
        failed_count=failed_count,
        transactions=[TransactionResponse.model_validate(t) for t in parsed_transactions]
    )


# Counterparty Mappings
@router.get("/mappings/", response_model=List[CounterpartyMappingResponse])
async def get_counterparty_mappings(
    current_user: TokenPayload = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Get all counterparty mappings for the user."""
    mappings = db.query(CounterpartyMapping).filter(
        CounterpartyMapping.user_id == int(current_user.sub)
    ).all()
    return [CounterpartyMappingResponse.model_validate(m) for m in mappings]


@router.post("/mappings/", response_model=CounterpartyMappingResponse, status_code=status.HTTP_201_CREATED)
async def create_counterparty_mapping(
    mapping_data: CounterpartyMappingCreate,
    current_user: TokenPayload = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Create or update a counterparty mapping."""
    user_id = int(current_user.sub)
    
    existing = db.query(CounterpartyMapping).filter(
        and_(
            CounterpartyMapping.user_id == user_id,
            CounterpartyMapping.counterparty == mapping_data.counterparty
        )
    ).first()
    
    if existing:
        existing.category = ModelCategory(mapping_data.category.value)
        existing.need_want = ModelNeedWant(mapping_data.need_want.value)
        existing.display_name = mapping_data.display_name
        db.commit()
        db.refresh(existing)
        return CounterpartyMappingResponse.model_validate(existing)
    
    mapping = CounterpartyMapping(
        user_id=user_id,
        counterparty=mapping_data.counterparty,
        display_name=mapping_data.display_name,
        category=ModelCategory(mapping_data.category.value),
        need_want=ModelNeedWant(mapping_data.need_want.value)
    )
    
    db.add(mapping)
    db.commit()
    db.refresh(mapping)
    
    return CounterpartyMappingResponse.model_validate(mapping)
