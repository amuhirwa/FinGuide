/*
 * App Database
 * ============
 * Local SQLite database using Drift.
 * Stores transaction data on-device — nothing is persisted on the backend.
 *
 * Run `dart run build_runner build` to regenerate app_database.g.dart
 * whenever this file changes.
 */

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

// ─── Transactions table ───────────────────────────────────────────────────────

class Transactions extends Table {
  // Local surrogate primary key — auto-incremented by SQLite
  IntColumn get id => integer().autoIncrement()();

  // Server-side id from the old backend (set during one-time migration, null
  // for transactions parsed locally after the migration)
  IntColumn get serverId => integer().nullable()();

  // Core fields
  TextColumn get transactionType => text()(); // "income" | "expense" | "transfer"
  TextColumn get category => text().withDefault(const Constant('other'))();
  TextColumn get needWant =>
      text().withDefault(const Constant('uncategorized'))();
  RealColumn get amount => real()();

  // Human-readable description / merchant name
  TextColumn get description => text().nullable()();

  // Counterparty — phone number or name extracted from SMS
  TextColumn get counterparty => text().nullable()();

  // User-assigned friendly name for the counterparty
  TextColumn get counterpartyName => text().nullable()();

  // Deduplication key: SHA-256 hex of raw SMS body (first 32 chars).
  // For migrated server rows: "server:<id>".
  // UNIQUE constraint makes duplicate inserts a no-op via insertOnConflictUpdate.
  TextColumn get reference => text().nullable().unique()();

  // When the transaction actually occurred (parsed from SMS timestamp)
  DateTimeColumn get transactionDate => dateTime()();

  // MoMo wallet balance reported in the SMS after this transaction
  RealColumn get balanceAfter => real().nullable()();

  // Parser confidence score (0.0–1.0); null for manually-created rows
  RealColumn get confidenceScore => real().nullable()();

  // Whether the user has manually verified / corrected this transaction
  BoolColumn get isVerified =>
      boolean().withDefault(const Constant(false))();

  // Backend investment id, set when linked to an RNIT/investment record
  IntColumn get linkedInvestmentId => integer().nullable()();

  // Original SMS body — kept locally only, never sent to the backend
  TextColumn get rawSms => text().nullable()();

  // SMS sender address (e.g. "M-Money", "8199")
  TextColumn get smsSender => text().nullable()();

  // Row creation timestamp
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

// ─── Counterparty mappings table ──────────────────────────────────────────────

/// Stores the user's preferred category for each phone number / merchant name.
/// When a new SMS is parsed, this table is consulted before the parser's
/// auto-detected category is applied.
class CounterpartyMappings extends Table {
  IntColumn get id => integer().autoIncrement()();

  // Phone number or merchant name — the lookup key
  TextColumn get counterparty => text().unique()();

  // Human-readable display name set by the user
  TextColumn get displayName => text().nullable()();

  // User's preferred category for this counterparty
  TextColumn get category => text().withDefault(const Constant('other'))();
  TextColumn get needWant =>
      text().withDefault(const Constant('uncategorized'))();

  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}

// ─── Database class ───────────────────────────────────────────────────────────

@DriftDatabase(tables: [Transactions, CounterpartyMappings])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'finguide_local');
  }
}
