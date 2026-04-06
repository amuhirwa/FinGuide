/*
 * Transaction Local Data Source
 * ==============================
 * All transaction reads/writes go through this class via the local Drift DB.
 * Nothing in this file touches the network.
 */

import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../models/transaction_model.dart';
import '../../domain/models/financial_context.dart';

class TransactionLocalDataSource {
  final AppDatabase _db;

  TransactionLocalDataSource(this._db);

  // ─── Insert ───────────────────────────────────────────────────────────────

  /// Insert a parsed transaction, skipping if the reference already exists.
  ///
  /// Returns `true` if the row was inserted, `false` if it was a duplicate.
  Future<bool> insertTransaction(TransactionsCompanion row) async {
    if (row.reference.value != null) {
      // Fast-path: check reference uniqueness
      final existing = await (_db.transactions.select()
            ..where((t) => t.reference.equals(row.reference.value!)))
          .getSingleOrNull();
      if (existing != null) return false;
    }

    // Fallback: same amount + type + date within ±90 seconds (handles rows
    // migrated from the backend which have a different reference format)
    if (row.transactionDate.value != null) {
      final date = row.transactionDate.value!;
      final window = const Duration(seconds: 90);
      final existing = await (_db.transactions.select()
            ..where((t) =>
                t.amount.isBetweenValues(
                    row.amount.value - 0.01, row.amount.value + 0.01) &
                t.transactionType.equals(row.transactionType.value) &
                t.transactionDate.isBiggerOrEqualValue(
                    date.subtract(window)) &
                t.transactionDate.isSmallerOrEqualValue(date.add(window))))
          .getSingleOrNull();
      if (existing != null) return false;
    }

    await _db.transactions.insertOnConflictUpdate(row);
    return true;
  }

  /// Bulk-insert a list of companions.  Returns the count of newly inserted rows.
  Future<int> insertAll(List<TransactionsCompanion> rows) async {
    int inserted = 0;
    for (final row in rows) {
      if (await insertTransaction(row)) inserted++;
    }
    return inserted;
  }

  // ─── Queries ──────────────────────────────────────────────────────────────

  /// Fetch a page of transactions, newest first.
  Future<List<TransactionModel>> getTransactions({
    int page = 1,
    int pageSize = 50,
    String? transactionType,
    String? category,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final query = _db.transactions.select()
      ..orderBy([(t) => OrderingTerm.desc(t.transactionDate)]);

    if (transactionType != null) {
      query.where((t) => t.transactionType.equals(transactionType));
    }
    if (category != null) {
      query.where((t) => t.category.equals(category));
    }
    if (startDate != null) {
      query.where((t) => t.transactionDate.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      query.where((t) => t.transactionDate.isSmallerOrEqualValue(endDate));
    }

    query
      ..limit(pageSize, offset: (page - 1) * pageSize);

    final rows = await query.get();
    return rows.map(_rowToModel).toList();
  }

  /// Count total transactions matching the given filters.
  Future<int> countTransactions({
    String? transactionType,
    String? category,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final query = _db.transactions.selectOnly()
      ..addColumns([_db.transactions.id.count()]);

    if (transactionType != null) {
      query.where(_db.transactions.transactionType.equals(transactionType));
    }
    if (startDate != null) {
      query.where(
          _db.transactions.transactionDate.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      query.where(
          _db.transactions.transactionDate.isSmallerOrEqualValue(endDate));
    }

    final row = await query.getSingle();
    return row.read(_db.transactions.id.count()) ?? 0;
  }

  /// Fetch transactions for ML / AI context — only the fields the model needs.
  Future<List<Map<String, dynamic>>> getTransactionsForAI({
    int days = 30,
  }) async {
    final since = DateTime.now().subtract(Duration(days: days));
    final rows = await (_db.transactions.select()
          ..where((t) =>
              t.transactionDate.isBiggerOrEqualValue(since) &
              t.transactionType.isNotValue('transfer'))
          ..orderBy([(t) => OrderingTerm.asc(t.transactionDate)]))
        .get();

    return rows
        .map((r) => {
              'date': r.transactionDate.toIso8601String().substring(0, 10),
              'amount': r.amount,
              'category': r.category,
              'type': r.transactionType,
            })
        .toList();
  }

  /// Fetch recent MoKash withdrawal amounts for self-transfer detection.
  Future<Set<double>> getRecentMokashWithdrawals() async {
    final cutoff = DateTime.now().subtract(const Duration(hours: 2));
    final rows = await (_db.transactions.select()
          ..where((t) =>
              t.transactionType.equals('transfer') &
              t.category.equals('savings') &
              t.transactionDate.isBiggerOrEqualValue(cutoff)))
        .get();
    return rows.map((r) => r.amount).toSet();
  }

  // ─── Summary / aggregates ─────────────────────────────────────────────────

  /// Compute totals and breakdowns for the given date range.
  Future<TransactionSummary> getTransactionSummary({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final rows = await _filteredRows(startDate: startDate, endDate: endDate);

    double totalIncome = 0;
    double totalExpenses = 0;
    final categoryBreakdown = <String, double>{};
    final needWantBreakdown = <String, double>{};

    for (final r in rows) {
      if (r.transactionType == 'income') {
        totalIncome += r.amount;
      } else if (r.transactionType == 'expense') {
        totalExpenses += r.amount;
        categoryBreakdown[r.category] =
            (categoryBreakdown[r.category] ?? 0) + r.amount;
        needWantBreakdown[r.needWant] =
            (needWantBreakdown[r.needWant] ?? 0) + r.amount;
      }
    }

    return TransactionSummary(
      totalIncome: totalIncome,
      totalExpenses: totalExpenses,
      netFlow: totalIncome - totalExpenses,
      transactionCount: rows.length,
      categoryBreakdown: categoryBreakdown,
      needWantBreakdown: needWantBreakdown,
    );
  }

  /// Build the financial context payload that is sent to the backend for
  /// AI nudge generation and 7-day forecasting.
  ///
  /// Note: active_goals and investments are fetched from the backend API
  /// by the caller (InsightsRepository) and folded in afterwards.
  Future<FinancialContext> computeFinancialContext() async {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final monthStart = DateTime(now.year, now.month, 1);

    final rows30d = await _filteredRows(startDate: thirtyDaysAgo);

    double income30d = 0;
    double expenses30d = 0;
    double savingsThisMonth = 0;
    final categoryTotals = <String, double>{};

    const savingsCategories = {'savings', 'ejo_heza', 'investment'};

    for (final r in rows30d) {
      if (r.transactionType == 'income') {
        income30d += r.amount;
      } else if (r.transactionType == 'expense') {
        expenses30d += r.amount;
        categoryTotals[r.category] =
            (categoryTotals[r.category] ?? 0) + r.amount;
      } else if (r.transactionType == 'transfer' &&
          savingsCategories.contains(r.category)) {
        if (r.transactionDate.isAfter(monthStart)) {
          savingsThisMonth += r.amount;
        }
      }
    }

    // Top 5 expense categories by amount
    final topCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top5 = topCategories.take(5).map((e) {
      return {'category': e.key, 'amount': e.value};
    }).toList();

    // Estimated balance: latest balance_after from SMS, or net 30-day flow
    final latestBalance = await (_db.transactions.select()
          ..where((t) => t.balanceAfter.isNotNull())
          ..orderBy([(t) => OrderingTerm.desc(t.transactionDate)])
          ..limit(1))
        .getSingleOrNull();

    final estimatedBalance = latestBalance?.balanceAfter ??
        (income30d - expenses30d).clamp(0, double.infinity);

    return FinancialContext(
      contextWindowDays: 30,
      income30d: income30d,
      expenses30d: expenses30d,
      estimatedBalance: estimatedBalance,
      savingsThisMonth: savingsThisMonth,
      topExpenseCategories: top5,
      activeGoals: const [], // filled in by InsightsRepository
      investments: const [], // filled in by InsightsRepository
    );
  }

  // ─── Counterparty mappings ────────────────────────────────────────────────

  /// Look up the user's preferred category for a counterparty phone/name.
  Future<CounterpartyMapping?> getCounterpartyMapping(
      String counterparty) async {
    return (_db.counterpartyMappings.select()
          ..where((m) => m.counterparty.equals(counterparty)))
        .getSingleOrNull();
  }

  /// Save or update a counterparty→category mapping.
  Future<void> upsertCounterpartyMapping({
    required String counterparty,
    String? displayName,
    required String category,
    required String needWant,
  }) async {
    await _db.counterpartyMappings.insertOnConflictUpdate(
      CounterpartyMappingsCompanion(
        counterparty: Value(counterparty),
        displayName: Value(displayName),
        category: Value(category),
        needWant: Value(needWant),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // ─── Update ───────────────────────────────────────────────────────────────

  /// Update an existing transaction (e.g. after user manually corrects category).
  Future<void> updateTransaction(int id, TransactionsCompanion data) async {
    await (_db.transactions.update()..where((t) => t.id.equals(id)))
        .write(data);
  }

  /// Delete a transaction by local id.
  Future<void> deleteTransaction(int id) async {
    await (_db.transactions.delete()..where((t) => t.id.equals(id))).go();
  }

  // ─── Private helpers ──────────────────────────────────────────────────────

  Future<List<Transaction>> _filteredRows({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final query = _db.transactions.select();
    if (startDate != null) {
      query.where((t) => t.transactionDate.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      query.where((t) => t.transactionDate.isSmallerOrEqualValue(endDate));
    }
    return query.get();
  }

  TransactionModel _rowToModel(Transaction r) {
    return TransactionModel(
      id: r.id,
      transactionType: TransactionType.values.firstWhere(
        (e) => e.name == r.transactionType,
        orElse: () => TransactionType.expense,
      ),
      category: TransactionCategory.values.firstWhere(
        (e) => e.name == r.category,
        orElse: () => TransactionCategory.other,
      ),
      needWant: NeedWantCategory.values.firstWhere(
        (e) => e.name == r.needWant,
        orElse: () => NeedWantCategory.uncategorized,
      ),
      amount: r.amount,
      description: r.description,
      counterparty: r.counterparty,
      counterpartyName: r.counterpartyName,
      reference: r.reference,
      transactionDate: r.transactionDate,
      confidenceScore: r.confidenceScore,
      isVerified: r.isVerified,
      linkedInvestmentId: r.linkedInvestmentId,
      createdAt: r.createdAt,
    );
  }
}

/// Helpers to convert a [ParsedTransaction] + raw SMS details into a
/// [TransactionsCompanion] ready to be inserted into the Drift DB.
TransactionsCompanion parsedToCompanion(
  dynamic parsed, {
  String? smsSender,
}) {
  // Import is done via the caller; this is a standalone function so it can
  // be used from sms_service.dart without a circular import.
  return TransactionsCompanion(
    transactionType: Value(parsed.transactionType as String),
    category: Value(parsed.category as String),
    needWant: Value(parsed.needWant as String),
    amount: Value(parsed.amount as double),
    description: Value(parsed.partyName as String?),
    counterparty: Value(parsed.partyPhone as String?),
    counterpartyName: Value(parsed.partyName as String?),
    reference: Value(parsed.reference as String?),
    transactionDate: Value(
      (parsed.date as DateTime?) ?? DateTime.now(),
    ),
    balanceAfter: Value(parsed.balance as double?),
    confidenceScore: const Value(0.85),
    rawSms: Value(parsed.rawSms as String),
    smsSender: Value(smsSender),
  );
}
