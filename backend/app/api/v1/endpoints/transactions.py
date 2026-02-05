"""
Transaction Endpoints
=====================
CRUD operations and SMS parsing for transactions.
"""

from typing import List, Optional
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from sqlalchemy import func, and_

from app.models.base import get_db
from app.models.transaction import Transaction, CounterpartyMapping, TransactionType as ModelTransactionType
from app.models.transaction import TransactionCategory as ModelCategory, NeedWantCategory as ModelNeedWant
from app.schemas.transaction import (
    TransactionCreate, TransactionUpdate, TransactionResponse,
    TransactionListResponse, TransactionSummary,
    SMSParseRequest, SMSParseResponse,
    CounterpartyMappingCreate, CounterpartyMappingResponse,
    TransactionType, TransactionCategory, NeedWantCategory
)
from app.schemas.user import TokenPayload
from app.core.deps import get_current_active_user
from app.services.sms_parser import parse_momo_sms

router = APIRouter()


@router.get("", response_model=TransactionListResponse)
async def get_transactions(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
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
    
    # Default to current month if no dates provided
    if not start_date:
        today = datetime.now()
        start_date = today.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    if not end_date:
        end_date = datetime.now()
    
    # Query transactions in date range
    transactions = db.query(Transaction).filter(
        and_(
            Transaction.user_id == user_id,
            Transaction.transaction_date >= start_date,
            Transaction.transaction_date <= end_date
        )
    ).all()
    
    # Calculate totals
    total_income = sum(t.amount for t in transactions if t.transaction_type == ModelTransactionType.INCOME)
    total_expenses = sum(t.amount for t in transactions if t.transaction_type == ModelTransactionType.EXPENSE)
    
    # Category breakdown
    category_breakdown = {}
    for t in transactions:
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
    current_user: TokenPayload = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """
    Parse SMS messages and create transactions.
    """
    user_id = int(current_user.sub)
    parsed_transactions = []
    failed_count = 0
    
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
            
            # Check for duplicate
            if parsed.get("reference"):
                existing = db.query(Transaction).filter(
                    Transaction.reference == parsed["reference"]
                ).first()
                if existing:
                    continue
            
            # Auto-categorize based on counterparty
            category = ModelCategory.OTHER
            need_want = ModelNeedWant.UNCATEGORIZED
            counterparty_name = None
            
            if parsed.get("counterparty") and parsed["counterparty"] in mapping_dict:
                mapping = mapping_dict[parsed["counterparty"]]
                category = mapping.category
                need_want = mapping.need_want
                counterparty_name = mapping.display_name
            
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
                is_verified=False
            )
            
            db.add(transaction)
            db.commit()
            db.refresh(transaction)
            parsed_transactions.append(transaction)
            
        except Exception as e:
            failed_count += 1
            continue
    
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
