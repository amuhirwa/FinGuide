/*
 * Transaction BLoC
 * ================
 * State management for transactions
 */

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/transaction_model.dart';
import '../../data/repositories/transaction_repository.dart';

// Events
abstract class TransactionEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadTransactions extends TransactionEvent {
  final String? transactionType;
  final String? category;
  final DateTime? startDate;
  final DateTime? endDate;

  LoadTransactions({
    this.transactionType,
    this.category,
    this.startDate,
    this.endDate,
  });

  @override
  List<Object?> get props => [transactionType, category, startDate, endDate];
}

class LoadTransactionSummary extends TransactionEvent {
  final DateTime? startDate;
  final DateTime? endDate;

  LoadTransactionSummary({this.startDate, this.endDate});

  @override
  List<Object?> get props => [startDate, endDate];
}

class CreateTransaction extends TransactionEvent {
  final Map<String, dynamic> data;

  CreateTransaction(this.data);

  @override
  List<Object?> get props => [data];
}

class UpdateTransaction extends TransactionEvent {
  final int id;
  final Map<String, dynamic> data;

  UpdateTransaction(this.id, this.data);

  @override
  List<Object?> get props => [id, data];
}

class ParseSmsMessages extends TransactionEvent {
  final List<String> messages;

  ParseSmsMessages(this.messages);

  @override
  List<Object?> get props => [messages];
}

// States
abstract class TransactionState extends Equatable {
  @override
  List<Object?> get props => [];
}

class TransactionInitial extends TransactionState {}

class TransactionLoading extends TransactionState {}

class TransactionsLoaded extends TransactionState {
  final List<TransactionModel> transactions;
  final TransactionSummary? summary;

  TransactionsLoaded(this.transactions, {this.summary});

  @override
  List<Object?> get props => [transactions, summary];
}

class TransactionCreated extends TransactionState {
  final TransactionModel transaction;

  TransactionCreated(this.transaction);

  @override
  List<Object?> get props => [transaction];
}

class SmsParseSuccess extends TransactionState {
  final List<TransactionModel> transactions;
  final int parsedCount;

  SmsParseSuccess(this.transactions, this.parsedCount);

  @override
  List<Object?> get props => [transactions, parsedCount];
}

class TransactionError extends TransactionState {
  final String message;

  TransactionError(this.message);

  @override
  List<Object?> get props => [message];
}

// BLoC
class TransactionBloc extends Bloc<TransactionEvent, TransactionState> {
  final TransactionRepository _repository;

  TransactionBloc(this._repository) : super(TransactionInitial()) {
    on<LoadTransactions>(_onLoadTransactions);
    on<LoadTransactionSummary>(_onLoadSummary);
    on<CreateTransaction>(_onCreateTransaction);
    on<UpdateTransaction>(_onUpdateTransaction);
    on<ParseSmsMessages>(_onParseSms);
  }

  Future<void> _onLoadTransactions(
    LoadTransactions event,
    Emitter<TransactionState> emit,
  ) async {
    emit(TransactionLoading());

    final result = await _repository.getTransactions(
      transactionType: event.transactionType,
      category: event.category,
      startDate: event.startDate,
      endDate: event.endDate,
      pageSize: 200,
    );

    if (result.isLeft()) {
      result.fold((error) => emit(TransactionError(error)), (_) {});
      return;
    }

    final transactions = result.getOrElse(() => []);

    // Also fetch summary for the same window so card stays in sync
    final summaryResult = await _repository.getTransactionSummary(
      startDate: event.startDate,
      endDate: event.endDate,
    );

    summaryResult.fold(
      (_) => emit(TransactionsLoaded(transactions)),
      (summary) => emit(TransactionsLoaded(transactions, summary: summary)),
    );
  }

  Future<void> _onLoadSummary(
    LoadTransactionSummary event,
    Emitter<TransactionState> emit,
  ) async {
    final currentState = state;
    List<TransactionModel> transactions = [];

    if (currentState is TransactionsLoaded) {
      transactions = currentState.transactions;
    }

    final result = await _repository.getTransactionSummary(
      startDate: event.startDate,
      endDate: event.endDate,
    );

    result.fold(
      (error) => emit(TransactionError(error)),
      (summary) => emit(TransactionsLoaded(transactions, summary: summary)),
    );
  }

  Future<void> _onCreateTransaction(
    CreateTransaction event,
    Emitter<TransactionState> emit,
  ) async {
    emit(TransactionLoading());

    final result = await _repository.createTransaction(event.data);

    result.fold(
      (error) => emit(TransactionError(error)),
      (transaction) => emit(TransactionCreated(transaction)),
    );
  }

  Future<void> _onUpdateTransaction(
    UpdateTransaction event,
    Emitter<TransactionState> emit,
  ) async {
    emit(TransactionLoading());

    final result = await _repository.updateTransaction(event.id, event.data);

    result.fold(
      (error) => emit(TransactionError(error)),
      (transaction) => emit(TransactionCreated(transaction)),
    );
  }

  Future<void> _onParseSms(
    ParseSmsMessages event,
    Emitter<TransactionState> emit,
  ) async {
    emit(TransactionLoading());

    final result = await _repository.parseSmsMessages(event.messages);

    result.fold(
      (error) => emit(TransactionError(error)),
      (transactions) =>
          emit(SmsParseSuccess(transactions, transactions.length)),
    );
  }
}
