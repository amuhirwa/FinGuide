/// BLoC tests for TransactionBloc.
///
/// Covers every event/state transition using bloc_test + mocktail:
///   LoadTransactions, LoadMoreTransactions, LoadTransactionSummary,
///   CreateTransaction, UpdateTransaction, ParseSmsMessages.
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:finguide/features/transactions/data/models/transaction_model.dart';
import 'package:finguide/features/transactions/data/repositories/transaction_repository.dart';
import 'package:finguide/features/transactions/presentation/bloc/transaction_bloc.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockTransactionRepository extends Mock implements TransactionRepository {}

// ── Test Factories ────────────────────────────────────────────────────────────

TransactionModel _makeTx({
  int id = 1,
  double amount = 50000,
  TransactionType type = TransactionType.income,
}) =>
    TransactionModel(
      id: id,
      transactionType: type,
      category: TransactionCategory.other_income,
      needWant: NeedWantCategory.uncategorized,
      amount: amount,
      description: 'Test tx',
      transactionDate: DateTime(2025, 1, 15),
      isVerified: false,
      createdAt: DateTime(2025, 1, 15),
    );

TransactionSummary _makeSummary({
  double income = 200000,
  double expenses = 80000,
}) =>
    TransactionSummary(
      totalIncome: income,
      totalExpenses: expenses,
      netFlow: income - expenses,
      transactionCount: 5,
      categoryBreakdown: {'other_income': income},
      needWantBreakdown: {'uncategorized': income},
    );

TransactionPage _makePage({
  List<TransactionModel>? transactions,
  int currentPage = 1,
  int totalPages = 1,
}) =>
    TransactionPage(
      transactions: transactions ?? [_makeTx()],
      currentPage: currentPage,
      totalPages: totalPages,
    );

// ── Main ──────────────────────────────────────────────────────────────────────

void main() {
  late MockTransactionRepository mockRepo;

  setUp(() {
    mockRepo = MockTransactionRepository();
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(<String>[]);
  });

  TransactionBloc makeBloc() => TransactionBloc(mockRepo);

  // ── LoadTransactions ──────────────────────────────────────────────────────

  group('LoadTransactions', () {
    blocTest<TransactionBloc, TransactionState>(
      'emits [TransactionLoading, TransactionsLoaded] with summary on success',
      build: () {
        when(() => mockRepo.getTransactionPage(
              transactionType: any(named: 'transactionType'),
              category: any(named: 'category'),
              startDate: any(named: 'startDate'),
              endDate: any(named: 'endDate'),
              page: any(named: 'page'),
              pageSize: any(named: 'pageSize'),
            )).thenAnswer((_) async => Right(_makePage()));
        when(() => mockRepo.getTransactionSummary(
              startDate: any(named: 'startDate'),
              endDate: any(named: 'endDate'),
            )).thenAnswer((_) async => Right(_makeSummary()));
        return makeBloc();
      },
      act: (bloc) => bloc.add(LoadTransactions()),
      expect: () => [isA<TransactionLoading>(), isA<TransactionsLoaded>()],
      verify: (bloc) {
        final s = bloc.state as TransactionsLoaded;
        expect(s.transactions.length, 1);
        expect(s.summary?.totalIncome, 200000);
        expect(s.hasMore, false);
        expect(s.currentPage, 1);
      },
    );

    blocTest<TransactionBloc, TransactionState>(
      'TransactionsLoaded still emits when summary call fails',
      build: () {
        when(() => mockRepo.getTransactionPage(
              transactionType: any(named: 'transactionType'),
              category: any(named: 'category'),
              startDate: any(named: 'startDate'),
              endDate: any(named: 'endDate'),
              page: any(named: 'page'),
              pageSize: any(named: 'pageSize'),
            )).thenAnswer((_) async => Right(_makePage()));
        when(() => mockRepo.getTransactionSummary(
              startDate: any(named: 'startDate'),
              endDate: any(named: 'endDate'),
            )).thenAnswer((_) async => const Left('Summary unavailable'));
        return makeBloc();
      },
      act: (bloc) => bloc.add(LoadTransactions()),
      expect: () => [isA<TransactionLoading>(), isA<TransactionsLoaded>()],
      verify: (bloc) {
        // summary is null but transactions are present
        expect((bloc.state as TransactionsLoaded).summary, isNull);
        expect((bloc.state as TransactionsLoaded).transactions, isNotEmpty);
      },
    );

    blocTest<TransactionBloc, TransactionState>(
      'emits [TransactionLoading, TransactionError] when page load fails',
      build: () {
        when(() => mockRepo.getTransactionPage(
              transactionType: any(named: 'transactionType'),
              category: any(named: 'category'),
              startDate: any(named: 'startDate'),
              endDate: any(named: 'endDate'),
              page: any(named: 'page'),
              pageSize: any(named: 'pageSize'),
            )).thenAnswer((_) async => const Left('Network error'));
        return makeBloc();
      },
      act: (bloc) => bloc.add(LoadTransactions()),
      expect: () => [isA<TransactionLoading>(), isA<TransactionError>()],
      verify: (bloc) {
        expect((bloc.state as TransactionError).message, 'Network error');
      },
    );

    blocTest<TransactionBloc, TransactionState>(
      'hasMore is true when more pages exist',
      build: () {
        when(() => mockRepo.getTransactionPage(
                  transactionType: any(named: 'transactionType'),
                  category: any(named: 'category'),
                  startDate: any(named: 'startDate'),
                  endDate: any(named: 'endDate'),
                  page: any(named: 'page'),
                  pageSize: any(named: 'pageSize'),
                ))
            .thenAnswer(
                (_) async => Right(_makePage(currentPage: 1, totalPages: 3)));
        when(() => mockRepo.getTransactionSummary(
              startDate: any(named: 'startDate'),
              endDate: any(named: 'endDate'),
            )).thenAnswer((_) async => Right(_makeSummary()));
        return makeBloc();
      },
      act: (bloc) => bloc.add(LoadTransactions()),
      verify: (bloc) {
        expect((bloc.state as TransactionsLoaded).hasMore, true);
      },
    );
  });

  // ── LoadMoreTransactions ─────────────────────────────────────────────────

  group('LoadMoreTransactions', () {
    final page1Tx = _makeTx(id: 1);
    final page2Tx = _makeTx(id: 2);

    blocTest<TransactionBloc, TransactionState>(
      'appends next page to existing transactions',
      build: () {
        when(() => mockRepo.getTransactionPage(
              transactionType: any(named: 'transactionType'),
              category: any(named: 'category'),
              startDate: any(named: 'startDate'),
              endDate: any(named: 'endDate'),
              page: 2,
              pageSize: any(named: 'pageSize'),
            )).thenAnswer((_) async => Right(
              _makePage(transactions: [page2Tx], currentPage: 2, totalPages: 2),
            ));
        return makeBloc();
      },
      seed: () => TransactionsLoaded(
        [page1Tx],
        hasMore: true,
        currentPage: 1,
      ),
      act: (bloc) => bloc.add(LoadMoreTransactions()),
      expect: () => [isA<TransactionsLoaded>()],
      verify: (bloc) {
        final s = bloc.state as TransactionsLoaded;
        expect(s.transactions.length, 2);
        expect(s.transactions.first.id, 1);
        expect(s.transactions.last.id, 2);
        expect(s.currentPage, 2);
        expect(s.hasMore, false);
      },
    );

    blocTest<TransactionBloc, TransactionState>(
      'does nothing when hasMore is false',
      build: () => makeBloc(),
      seed: () => TransactionsLoaded([page1Tx], hasMore: false, currentPage: 1),
      act: (bloc) => bloc.add(LoadMoreTransactions()),
      expect: () => <TransactionState>[],
    );

    blocTest<TransactionBloc, TransactionState>(
      'does nothing when state is not TransactionsLoaded',
      build: () => makeBloc(),
      act: (bloc) => bloc.add(LoadMoreTransactions()),
      expect: () => <TransactionState>[],
    );

    blocTest<TransactionBloc, TransactionState>(
      'silently keeps existing list when next page errors',
      build: () {
        when(() => mockRepo.getTransactionPage(
              transactionType: any(named: 'transactionType'),
              category: any(named: 'category'),
              startDate: any(named: 'startDate'),
              endDate: any(named: 'endDate'),
              page: 2,
              pageSize: any(named: 'pageSize'),
            )).thenAnswer((_) async => const Left('Server error'));
        return makeBloc();
      },
      seed: () => TransactionsLoaded([page1Tx], hasMore: true, currentPage: 1),
      act: (bloc) => bloc.add(LoadMoreTransactions()),
      // Should emit nothing — current list is preserved
      expect: () => <TransactionState>[],
    );
  });

  // ── LoadTransactionSummary ────────────────────────────────────────────────

  group('LoadTransactionSummary', () {
    blocTest<TransactionBloc, TransactionState>(
      'updates summary on currently loaded transactions',
      build: () {
        when(() => mockRepo.getTransactionSummary(
              startDate: any(named: 'startDate'),
              endDate: any(named: 'endDate'),
            )).thenAnswer((_) async => Right(_makeSummary(income: 300000)));
        return makeBloc();
      },
      seed: () => TransactionsLoaded([_makeTx()]),
      act: (bloc) => bloc.add(LoadTransactionSummary()),
      expect: () => [isA<TransactionsLoaded>()],
      verify: (bloc) {
        expect((bloc.state as TransactionsLoaded).summary?.totalIncome, 300000);
      },
    );

    blocTest<TransactionBloc, TransactionState>(
      'emits TransactionError when summary fails',
      build: () {
        when(() => mockRepo.getTransactionSummary(
              startDate: any(named: 'startDate'),
              endDate: any(named: 'endDate'),
            )).thenAnswer((_) async => const Left('Unavailable'));
        return makeBloc();
      },
      act: (bloc) => bloc.add(LoadTransactionSummary()),
      expect: () => [isA<TransactionError>()],
    );
  });

  // ── CreateTransaction ─────────────────────────────────────────────────────

  group('CreateTransaction', () {
    final payload = {
      'amount': 50000.0,
      'transaction_type': 'income',
      'category': 'other_income',
    };

    blocTest<TransactionBloc, TransactionState>(
      'emits [TransactionLoading, TransactionCreated] on success',
      build: () {
        when(() => mockRepo.createTransaction(any()))
            .thenAnswer((_) async => Right(_makeTx()));
        return makeBloc();
      },
      act: (bloc) => bloc.add(CreateTransaction(payload)),
      expect: () => [isA<TransactionLoading>(), isA<TransactionCreated>()],
      verify: (bloc) {
        expect((bloc.state as TransactionCreated).transaction.amount, 50000);
      },
    );

    blocTest<TransactionBloc, TransactionState>(
      'emits [TransactionLoading, TransactionError] on failure',
      build: () {
        when(() => mockRepo.createTransaction(any()))
            .thenAnswer((_) async => const Left('Validation error'));
        return makeBloc();
      },
      act: (bloc) => bloc.add(CreateTransaction(payload)),
      expect: () => [isA<TransactionLoading>(), isA<TransactionError>()],
    );
  });

  // ── UpdateTransaction ─────────────────────────────────────────────────────

  group('UpdateTransaction', () {
    blocTest<TransactionBloc, TransactionState>(
      'emits [TransactionLoading, TransactionCreated] on success',
      build: () {
        when(() => mockRepo.updateTransaction(1, any()))
            .thenAnswer((_) async => Right(_makeTx(amount: 60000)));
        return makeBloc();
      },
      act: (bloc) => bloc.add(UpdateTransaction(1, {'amount': 60000})),
      expect: () => [isA<TransactionLoading>(), isA<TransactionCreated>()],
      verify: (bloc) {
        expect((bloc.state as TransactionCreated).transaction.amount, 60000);
      },
    );

    blocTest<TransactionBloc, TransactionState>(
      'emits [TransactionLoading, TransactionError] on failure',
      build: () {
        when(() => mockRepo.updateTransaction(any(), any()))
            .thenAnswer((_) async => const Left('Not found'));
        return makeBloc();
      },
      act: (bloc) => bloc.add(UpdateTransaction(99, {})),
      expect: () => [isA<TransactionLoading>(), isA<TransactionError>()],
    );
  });

  // ── ParseSmsMessages ──────────────────────────────────────────────────────

  group('ParseSmsMessages', () {
    final rawMessages = [
      'You have received 50,000 RWF from Alice at 2025-01-01. Balance: 250,000 RWF.',
      '5,000 RWF transferred to Bob (250788000000) at 2025-01-02. Balance: 245,000 RWF.',
    ];

    blocTest<TransactionBloc, TransactionState>(
      'emits [TransactionLoading, SmsParseSuccess] on success',
      build: () {
        when(() => mockRepo.parseSmsMessages(any()))
            .thenAnswer((_) async => Right(
                  [_makeTx(id: 1), _makeTx(id: 2)],
                ));
        return makeBloc();
      },
      act: (bloc) => bloc.add(ParseSmsMessages(rawMessages)),
      expect: () => [isA<TransactionLoading>(), isA<SmsParseSuccess>()],
      verify: (bloc) {
        final s = bloc.state as SmsParseSuccess;
        expect(s.transactions.length, 2);
        expect(s.parsedCount, 2);
      },
    );

    blocTest<TransactionBloc, TransactionState>(
      'emits [TransactionLoading, TransactionError] on failure',
      build: () {
        when(() => mockRepo.parseSmsMessages(any()))
            .thenAnswer((_) async => const Left('Parse failed'));
        return makeBloc();
      },
      act: (bloc) => bloc.add(ParseSmsMessages(rawMessages)),
      expect: () => [isA<TransactionLoading>(), isA<TransactionError>()],
    );

    blocTest<TransactionBloc, TransactionState>(
      'passes messages list verbatim to repository',
      build: () {
        when(() => mockRepo.parseSmsMessages(rawMessages))
            .thenAnswer((_) async => const Right([]));
        return makeBloc();
      },
      act: (bloc) => bloc.add(ParseSmsMessages(rawMessages)),
      verify: (_) =>
          verify(() => mockRepo.parseSmsMessages(rawMessages)).called(1),
    );

    blocTest<TransactionBloc, TransactionState>(
      'parsedCount equals number of returned transactions',
      build: () {
        final three = [_makeTx(id: 1), _makeTx(id: 2), _makeTx(id: 3)];
        when(() => mockRepo.parseSmsMessages(any()))
            .thenAnswer((_) async => Right(three));
        return makeBloc();
      },
      act: (bloc) => bloc.add(ParseSmsMessages(['a', 'b', 'c'])),
      verify: (bloc) {
        expect((bloc.state as SmsParseSuccess).parsedCount, 3);
      },
    );
  });

  // ── Initial state ─────────────────────────────────────────────────────────

  test('initial state is TransactionInitial', () {
    expect(makeBloc().state, isA<TransactionInitial>());
  });
}
