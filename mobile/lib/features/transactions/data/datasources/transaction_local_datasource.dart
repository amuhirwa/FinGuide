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

/// Canonical descriptions for savings movements.
///
/// The piggybank balance identifies deposits/withdrawals by these exact
/// strings, so the parser and the aggregation must agree on them.
const String kMokashDepositDescription = 'MoKash deposit';
const String kMokashWithdrawalDescription = 'MoKash withdrawal';

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

  // ─── Dashboard aggregates ─────────────────────────────────────────────────
  //
  // Ported from the backend endpoints so the dashboard can be served entirely
  // from the local DB. Both return the same JSON shape their HTTP counterparts
  // did, so callers only swap the call site.

  /// Piggybank balance — mirrors `GET /goals/piggybank`.
  ///
  /// Savings deposits minus withdrawals returned to the main wallet.
  Future<Map<String, dynamic>> computePiggybank() async {
    final rows = await (_db.transactions.select()
          ..where((t) =>
              t.category.equals('savings') &
              t.transactionType.equals('transfer'))
          ..orderBy([(t) => OrderingTerm.desc(t.transactionDate)]))
        .get();

    final contributions =
        rows.where((r) => r.description == kMokashDepositDescription).toList();
    final withdrawals = rows
        .where((r) => r.description == kMokashWithdrawalDescription)
        .toList();

    final totalIn = contributions.fold<double>(0, (s, r) => s + r.amount);
    final totalOut = withdrawals.fold<double>(0, (s, r) => s + r.amount);

    final byParty = <String, Map<String, dynamic>>{};
    void accumulate(Transaction r, String field) {
      final key = r.counterpartyName ?? r.counterparty ?? 'MoKash Savings';
      final entry = byParty.putIfAbsent(
        key,
        () => <String, dynamic>{
          'name': key,
          'total_in': 0.0,
          'total_out': 0.0,
          'tx_count': 0,
        },
      );
      entry[field] = (entry[field] as double) + r.amount;
      if (field == 'total_in') {
        entry['tx_count'] = (entry['tx_count'] as int) + 1;
      }
    }

    for (final r in contributions) {
      accumulate(r, 'total_in');
    }
    for (final r in withdrawals) {
      accumulate(r, 'total_out');
    }

    return {
      'balance': (totalIn - totalOut).clamp(0.0, double.infinity),
      'total_contributed': totalIn,
      'total_withdrawn': totalOut,
      'contribution_count': contributions.length,
      'withdrawal_count': withdrawals.length,
      'by_party': byParty.values.toList(),
      'recent_contributions': contributions
          .take(10)
          .map((r) => {
                'date': r.transactionDate.toIso8601String(),
                'amount': r.amount,
                'party':
                    r.counterpartyName ?? r.counterparty ?? 'Savings',
              })
          .toList(),
    };
  }

  /// Safe-to-spend — mirrors `GET /insights/safe-to-spend`.
  ///
  /// [activeGoals] comes from the backend (goals are still server-side); pass
  /// the raw goal JSON list. Everything else is computed from local rows.
  Future<Map<String, dynamic>> computeSafeToSpend({
    List<Map<String, dynamic>> activeGoals = const [],
  }) async {
    final now = DateTime.now();
    final eightWeeksAgo = now.subtract(const Duration(days: 56));

    final expenses = (await _filteredRows(startDate: eightWeeksAgo, endDate: now))
        .where((r) => r.transactionType == 'expense')
        .toList();

    // Weighting: needs count fully, wants are ~30% trimmable, savings aren't a
    // drain, and uncategorized sits in between with outliers dropped.
    const wantWeight = 0.70;
    const uncatWeight = 0.85;

    final uncategorizedRaw = expenses
        .where((r) => r.needWant != 'need' && r.needWant != 'want' && r.needWant != 'savings')
        .map((r) => r.amount)
        .toList()
      ..sort();
    final outlierThreshold = uncategorizedRaw.isEmpty
        ? double.infinity
        : _median(uncategorizedRaw) * 2.5;

    final weeklyTotals = <int, double>{};
    for (final r in expenses) {
      final weekKey =
          r.transactionDate.difference(eightWeeksAgo).inDays ~/ 7;
      final double weighted;
      if (r.needWant == 'savings') {
        // Savings aren't a drain — they're wealth-building.
        continue;
      } else if (r.needWant == 'need') {
        weighted = r.amount;
      } else if (r.needWant == 'want') {
        weighted = r.amount * wantWeight;
      } else {
        // Uncategorized: drop probable one-offs before weighting.
        if (r.amount > outlierThreshold) continue;
        weighted = r.amount * uncatWeight;
      }
      weeklyTotals[weekKey] = (weeklyTotals[weekKey] ?? 0.0) + weighted;
    }

    final nonZero = weeklyTotals.values.where((v) => v > 0).toList()..sort();
    double avgWeeklyExpense = 0;
    if (nonZero.isNotEmpty) {
      // Trimmed mean once there's enough history to drop the extremes.
      final trimmed =
          nonZero.length >= 4 ? nonZero.sublist(1, nonZero.length - 1) : nonZero;
      avgWeeklyExpense = trimmed.reduce((a, b) => a + b) / trimmed.length;
    }

    // Balance: latest SMS balance, else this month's net flow.
    final monthStart = DateTime(now.year, now.month, 1);
    final latestBalance = await (_db.transactions.select()
          ..where((t) => t.balanceAfter.isNotNull())
          ..orderBy([(t) => OrderingTerm.desc(t.transactionDate)])
          ..limit(1))
        .getSingleOrNull();

    double totalBalance;
    if (latestBalance?.balanceAfter != null) {
      totalBalance = latestBalance!.balanceAfter!;
    } else {
      final monthRows = await _filteredRows(startDate: monthStart);
      final income = monthRows
          .where((r) => r.transactionType == 'income')
          .fold<double>(0, (s, r) => s + r.amount);
      final spent = monthRows
          .where((r) => r.transactionType == 'expense')
          .fold<double>(0, (s, r) => s + r.amount);
      totalBalance = income - spent;
    }

    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysRemaining = (daysInMonth - now.day) < 1 ? 1 : daysInMonth - now.day;
    final weeksRemaining = daysRemaining / 7.0;

    // Reserve each goal's actual shortfall, capped at its weekly pace.
    double reservedForGoals = 0;
    for (final g in activeGoals) {
      final remaining = (g['remaining_amount'] as num?)?.toDouble() ??
          (((g['target_amount'] as num?)?.toDouble() ?? 0) -
              ((g['current_amount'] as num?)?.toDouble() ?? 0));
      final paceCap =
          ((g['weekly_target'] as num?)?.toDouble() ?? 0) * weeksRemaining;
      reservedForGoals += remaining < paceCap ? remaining : paceCap;
    }

    final reservedForExpenses = avgWeeklyExpense * weeksRemaining;
    final emergencyBuffer = avgWeeklyExpense * 2.0;

    // Spent today / this calendar week.
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
    final expensesToday = expenses
        .where((r) => !r.transactionDate.isBefore(todayStart))
        .fold<double>(0, (s, r) => s + r.amount);
    final expensesThisWeek = expenses
        .where((r) => !r.transactionDate.isBefore(weekStart))
        .fold<double>(0, (s, r) => s + r.amount);

    // Expected income still to come: median of the last 3 months' income
    // (median, so one unusual month doesn't skew it), minus what already landed.
    final threeMonthsAgo = DateTime(now.year, now.month - 3, 1);
    final histIncome = (await _filteredRows(
      startDate: threeMonthsAgo,
      endDate: monthStart,
    ))
        .where((r) => r.transactionType == 'income');

    final monthlyBuckets = <String, double>{};
    for (final r in histIncome) {
      final key = '${r.transactionDate.year}-${r.transactionDate.month}';
      monthlyBuckets[key] = (monthlyBuckets[key] ?? 0) + r.amount;
    }
    final monthlyTotals = monthlyBuckets.values.toList()..sort();
    final medianMonthlyIncome =
        monthlyTotals.isEmpty ? 0.0 : _median(monthlyTotals);

    final incomeThisMonth = (await _filteredRows(startDate: monthStart))
        .where((r) => r.transactionType == 'income')
        .fold<double>(0, (s, r) => s + r.amount);

    // 0.85 = conservative discount for income variability.
    final expectedIncomeRemaining =
        ((medianMonthlyIncome - incomeThisMonth) * 0.85)
            .clamp(0.0, double.infinity);

    final safeToSpend = (totalBalance +
            expectedIncomeRemaining -
            reservedForGoals -
            emergencyBuffer)
        .clamp(0.0, double.infinity);

    final incomeNote = expectedIncomeRemaining > 0
        ? ' + RWF ${expectedIncomeRemaining.toStringAsFixed(0)} expected income'
        : '';
    final explanation = avgWeeklyExpense > 0
        ? 'Based on your ${nonZero.length}-week weighted spending average '
            '(needs 100%, wants 70%) of RWF ${avgWeeklyExpense.toStringAsFixed(0)}/week'
            '$incomeNote, with $daysRemaining days remaining this month'
        : 'Not enough expense history yet.${incomeNote.isNotEmpty ? ' ${incomeNote.trim()}' : ''} '
            'Add more transactions to get an accurate safe-to-spend figure.';

    return {
      'safe_to_spend': safeToSpend,
      'total_balance': totalBalance,
      'reserved_for_expenses': reservedForExpenses,
      'reserved_for_goals': reservedForGoals,
      'emergency_buffer': emergencyBuffer,
      'explanation': explanation,
      'safe_per_day': safeToSpend / daysRemaining,
      'safe_per_week': safeToSpend / weeksRemaining,
      'weeks_remaining': weeksRemaining,
      'days_remaining': daysRemaining,
      'avg_weekly_expense': avgWeeklyExpense,
      'expected_income_remaining': expectedIncomeRemaining,
      'expenses_today': expensesToday,
      'expenses_this_week': expensesThisWeek,
    };
  }

  /// Median of an already-sorted list.
  double _median(List<double> sorted) {
    if (sorted.isEmpty) return 0;
    final n = sorted.length;
    if (n.isOdd) return sorted[n ~/ 2];
    return (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2.0;
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
  // Savings deposits/withdrawals carry a canonical description so the
  // piggybank balance can identify them. Everything else falls back to the
  // counterparty name.
  final String? description = (parsed.isMokashDeposit as bool? ?? false)
      ? kMokashDepositDescription
      : (parsed.isMokashWithdrawal as bool? ?? false)
          ? kMokashWithdrawalDescription
          : parsed.partyName as String?;

  return TransactionsCompanion(
    transactionType: Value(parsed.transactionType as String),
    category: Value(parsed.category as String),
    needWant: Value(parsed.needWant as String),
    amount: Value(parsed.amount as double),
    description: Value(description),
    counterparty:
        Value((parsed.partyPhone as String?) ?? parsed.partyName as String?),
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
