/*
 * Transaction Migration Data Source
 * ==================================
 * One-time migration: fetches historical transactions from the backend API
 * and stores them in the local Drift DB.
 *
 * Run once on first app open after the local-first upgrade. Controlled by the
 * StorageKeys.dataMigrationDone flag in SharedPreferences. Safe to re-run:
 * duplicate rows are silently skipped by the UNIQUE reference constraint.
 */

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/database/app_database.dart';
import 'transaction_local_datasource.dart';

class TransactionMigrationDataSource {
  final ApiClient _apiClient;
  final TransactionLocalDataSource _localDs;
  final SharedPreferences _prefs;
  final Logger _log = Logger();

  TransactionMigrationDataSource({
    required ApiClient apiClient,
    required TransactionLocalDataSource localDs,
    required SharedPreferences prefs,
  })  : _apiClient = apiClient,
        _localDs = localDs,
        _prefs = prefs;

  bool get isMigrationDone =>
      _prefs.getBool(StorageKeys.dataMigrationDone) ?? false;

  /// Fetch all transactions from the backend and store them locally.
  ///
  /// Should be called once after login, in a background Future so it
  /// doesn't block the UI. Idempotent — safe to call multiple times.
  Future<void> migrateFromBackend() async {
    if (isMigrationDone) return;

    _log.i('Starting one-time transaction migration from backend...');
    int totalMigrated = 0;
    int page = 1;
    const pageSize = 200;

    try {
      while (true) {
        final response = await _apiClient.getTransactions(
          page: page,
          pageSize: pageSize,
        );

        final list = response['transactions'] as List? ?? [];
        if (list.isEmpty) break;

        final companions = list
            .map((json) => _serverRowToCompanion(json as Map<String, dynamic>))
            .toList();

        final inserted = await _localDs.insertAll(companions);
        totalMigrated += inserted;

        _log.i('Migration page $page: ${list.length} fetched, $inserted new');

        final totalPages = (response['total_pages'] as num?)?.toInt() ?? 1;
        if (page >= totalPages || list.length < pageSize) break;
        page++;
      }

      await _prefs.setBool(StorageKeys.dataMigrationDone, true);
      _log.i('Migration complete: $totalMigrated transactions saved locally');
    } catch (e) {
      // Do NOT set the flag on failure — will retry on next app open.
      _log.e('Migration failed (will retry on next open)', error: e);
    }
  }

  /// Convert a backend JSON transaction row to a Drift companion.
  TransactionsCompanion _serverRowToCompanion(Map<String, dynamic> json) {
    // Use "server:<id>" as the reference so it doesn't collide with
    // SMS-derived SHA-256 references, but is still unique per row.
    final serverId = json['id'] as int?;
    final reference = serverId != null ? 'server:$serverId' : null;

    DateTime? date;
    final dateStr = json['transaction_date'] as String?;
    if (dateStr != null) {
      date = DateTime.tryParse(dateStr);
    }

    return TransactionsCompanion(
      serverId: Value(serverId),
      transactionType: Value(json['transaction_type'] as String? ?? 'expense'),
      category: Value(json['category'] as String? ?? 'other'),
      needWant: Value(json['need_want'] as String? ?? 'uncategorized'),
      amount: Value((json['amount'] as num?)?.toDouble() ?? 0.0),
      description: Value(json['description'] as String?),
      counterparty: Value(json['counterparty'] as String?),
      counterpartyName: Value(json['counterparty_name'] as String?),
      reference: Value(reference),
      transactionDate: Value(date ?? DateTime.now()),
      balanceAfter: Value((json['balance_after'] as num?)?.toDouble()),
      confidenceScore:
          Value((json['confidence_score'] as num?)?.toDouble()),
      isVerified: Value(json['is_verified'] as bool? ?? false),
      linkedInvestmentId: Value(json['linked_investment_id'] as int?),
      // rawSms not available from backend — leave null
    );
  }
}
