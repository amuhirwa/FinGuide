/*
 * SMS Service
 * ===========
 * Reads existing MoMo SMS messages and listens for new ones in real-time.
 *
 * All SMS parsing is done on-device via MomoParser. Raw SMS bodies are
 * stored in the local Drift DB and never sent to the backend.
 *
 * Income detection: when new income SMS arrives, the device computes the
 * user's financial context from the local DB and requests AI nudges from
 * the backend (context payload only — no raw transactions).
 */

import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:telephony/telephony.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';

import '../constants/storage_keys.dart';
import '../network/api_client.dart';
import '../database/app_database.dart';
import 'momo_parser.dart';
import 'nudge_notification_service.dart';
import '../../features/transactions/data/datasources/transaction_local_datasource.dart';

/// Known MoMo sender addresses / keywords used to filter SMS.
const List<String> _momoSenders = [
  'M-Money',
  'MoMo',
  'MTN',
  'MobileMoney',
  'momo',
  '8199',
  '162',
  '164',
  '165',
];

/// Keywords that identify a message body as a MoMo transaction.
const List<String> _momoKeywords = [
  'RWF',
  'Balance:',
  'transferred to',
  'received',
  'payment of',
  'transaction of',
  'FT Id',
  'Mokash',
  'from your Mokash account',
  'to your Mokash account',
];

/// Keywords that indicate this SMS is an income (money received) message.
const List<String> _incomeKeywords = [
  'received',
  'You have received',
  'has been deposited',
  'Cash In',
];

/// Extract the first RWF amount from an SMS string.
/// Top-level so it is reachable from the background isolate.
double? _extractAmountBackground(String body) {
  final match =
      RegExp(r'([\d,]+)\s*RWF', caseSensitive: false).firstMatch(body);
  if (match == null) return null;
  return double.tryParse(match.group(1)!.replaceAll(',', ''));
}

/// Top-level background SMS handler required by the `telephony` package.
///
/// The background isolate cannot use Drift (FFI-backed SQLite is not
/// isolate-safe). Instead we queue the SMS body to SharedPreferences and
/// parse it on the main isolate when the app resumes.
@pragma('vm:entry-point')
Future<void> backgroundSmsHandler(SmsMessage message) async {
  final body = message.body ?? '';
  if (body.isEmpty) return;

  WidgetsFlutterBinding.ensureInitialized();

  // 1. Queue for local parsing on next foreground resume.
  final prefs = await SharedPreferences.getInstance();
  final pending = prefs.getStringList(StorageKeys.pendingBackgroundSms) ?? [];
  if (!pending.contains(body)) {
    pending.add(body);
    await prefs.setStringList(StorageKeys.pendingBackgroundSms, pending);
  }

  // 2. Is this a MoMo message worth notifying on immediately?
  final bodyLower = body.toLowerCase();
  final addressLower = (message.address ?? '').toLowerCase();
  final isMomo =
      _momoKeywords.any((k) => bodyLower.contains(k.toLowerCase())) ||
          _momoSenders.any((s) => addressLower.contains(s.toLowerCase()));
  if (!isMomo) return;

  final amount = _extractAmountBackground(body);
  if (amount == null || amount < 40000) return;

  final isIncome = _incomeKeywords.any(
    (k) => bodyLower.contains(k.toLowerCase()),
  );

  // 3. Show an immediate local notification (no backend / DB call).
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

  await plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(
        const AndroidNotificationChannel(
          NudgeNotificationService.channelId,
          NudgeNotificationService.channelName,
          description: NudgeNotificationService.channelDesc,
          importance: Importance.high,
          playSound: true,
        ),
      );

  final fmt = amount >= 1000000
      ? '${(amount / 1000000).toStringAsFixed(1)}M'
      : '${(amount / 1000).toStringAsFixed(0)}k';
  final title = isIncome ? 'RWF $fmt received!' : 'RWF $fmt spent';
  final notifBody = isIncome
      ? 'Remember to save or invest. Open FinGuide to get your personalised savings nudge.'
      : 'Stay aware of your spending. Open FinGuide to check your safe-to-spend balance.';

  await plugin.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title,
    notifBody,
    NotificationDetails(
      android: AndroidNotificationDetails(
        NudgeNotificationService.channelId,
        NudgeNotificationService.channelName,
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(notifBody),
      ),
    ),
  );
}

/// Service responsible for reading & listening to MoMo SMS messages.
///
/// SMS parsing is fully on-device. Parsed transactions are written to the
/// local Drift DB. The backend is only contacted for AI nudge generation.
class SmsService {
  final Telephony _telephony;
  final ApiClient _apiClient;
  final SharedPreferences _prefs;
  final NudgeNotificationService _nudgeService;
  final TransactionLocalDataSource _localDs;
  final Logger _log = Logger();

  final StreamController<SmsMessage> _incomingController =
      StreamController<SmsMessage>.broadcast();

  Stream<SmsMessage> get onMomoReceived => _incomingController.stream;

  SmsService({
    required Telephony telephony,
    required ApiClient apiClient,
    required SharedPreferences prefs,
    required NudgeNotificationService nudgeService,
    required TransactionLocalDataSource localDataSource,
  })  : _telephony = telephony,
        _apiClient = apiClient,
        _prefs = prefs,
        _nudgeService = nudgeService,
        _localDs = localDataSource;

  // ─── Permission helpers ────────────────────────────────────────────

  Future<bool> requestPermission() async {
    return await _telephony.requestPhoneAndSmsPermissions ?? false;
  }

  Future<bool> get hasPermission async {
    return await _telephony.requestPhoneAndSmsPermissions ?? false;
  }

  // ─── Consent persistence ──────────────────────────────────────────

  bool get hasConsented => _prefs.getBool(StorageKeys.smsConsentGiven) ?? false;

  Future<void> setConsent(bool value) async {
    await _prefs.setBool(StorageKeys.smsConsentGiven, value);
  }

  // ─── Read historical SMS ─────────────────────────────────────────

  Future<List<String>> readHistoricalMessages() async {
    try {
      final messages = await _telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );

      final momoMessages = messages.where(_isMomoMessage).toList();
      _log.i('Found ${momoMessages.length} MoMo messages out of '
          '${messages.length} total SMS');

      return momoMessages
          .map((m) => m.body ?? '')
          .where((b) => b.isNotEmpty)
          .toList();
    } catch (e) {
      _log.e('Failed to read SMS inbox', error: e);
      return [];
    }
  }

  /// Parse all historical MoMo SMS and store them locally.
  /// Returns the number of new transactions saved to the local DB.
  Future<int> importHistoricalMessages() async {
    final bodies = await readHistoricalMessages();
    if (bodies.isEmpty) return 0;

    try {
      final userPhoneSuffix = _userPhoneSuffix;
      final recentWithdrawals = await _localDs.getRecentMokashWithdrawals();
      int totalInserted = 0;
      bool hasIncome = false;

      for (var i = 0; i < bodies.length; i += 50) {
        final batch = bodies.sublist(
          i,
          (i + 50) > bodies.length ? bodies.length : i + 50,
        );

        final parsed = MomoParser.parseBatch(
          batch,
          userPhoneSuffix: userPhoneSuffix,
          recentWithdrawals: recentWithdrawals,
        );

        for (final tx in parsed) {
          // Apply saved counterparty mapping (user-defined category override)
          final companion = await _applyCounterpartyMapping(
            _parsedToCompanion(tx),
            tx.partyPhone ?? tx.partyName,
          );
          if (await _localDs.insertTransaction(companion)) {
            totalInserted++;
            if (tx.transactionType == 'income') hasIncome = true;
          }
        }
      }

      await _prefs.setBool(StorageKeys.smsInitialImportDone, true);
      _log.i(
          'Imported $totalInserted new transactions from ${bodies.length} SMS');

      if (hasIncome) {
        _showPendingIncomeNudge();
      }

      return totalInserted;
    } catch (e) {
      _log.e('Failed to import SMS', error: e);
      return 0;
    }
  }

  // ─── Delta sync ───────────────────────────────────────────────────

  /// Parse and store any MoMo SMS that arrived since the last sync.
  Future<int> syncNewMessages() async {
    await _drainBackgroundQueue();

    final lastTimestamp =
        _prefs.getInt(StorageKeys.lastSmsSyncTimestamp) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      final messages = await _telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        filter: SmsFilter.where(SmsColumn.DATE)
            .greaterThan(lastTimestamp.toString()),
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.ASC)],
      );

      final newMomo = messages
          .where(_isMomoMessage)
          .map((m) => m.body ?? '')
          .where((b) => b.isNotEmpty)
          .toList();

      if (newMomo.isEmpty) {
        await _prefs.setInt(StorageKeys.lastSmsSyncTimestamp, now);
        return 0;
      }

      _log.i('Delta sync: ${newMomo.length} new MoMo SMS');

      final userPhoneSuffix = _userPhoneSuffix;
      final recentWithdrawals = await _localDs.getRecentMokashWithdrawals();
      final parsed = MomoParser.parseBatch(
        newMomo,
        userPhoneSuffix: userPhoneSuffix,
        recentWithdrawals: recentWithdrawals,
      );

      int totalInserted = 0;
      double incomeTotal = 0;
      ParsedTransaction? latestIncome;

      for (final tx in parsed) {
        final companion = await _applyCounterpartyMapping(
          _parsedToCompanion(tx),
          tx.partyPhone ?? tx.partyName,
        );
        if (await _localDs.insertTransaction(companion)) {
          totalInserted++;
          if (tx.transactionType == 'income') {
            incomeTotal += tx.amount;
            latestIncome = tx;
          }
        }
      }

      await _prefs.setInt(StorageKeys.lastSmsSyncTimestamp, now);
      _log.i('Delta sync complete: $totalInserted new transactions');

      if (latestIncome != null) {
        final threshold = 40000.0;
        if (incomeTotal >= threshold) {
          _showSignificantIncomeNudge(incomeTotal,
              source: latestIncome.partyName);
        } else {
          _showPendingIncomeNudge();
        }
      }

      return totalInserted;
    } catch (e) {
      _log.e('Delta SMS sync failed', error: e);
      return 0;
    }
  }

  // ─── Background queue drain ──────────────────────────────────────

  Future<void> _drainBackgroundQueue() async {
    final pending =
        _prefs.getStringList(StorageKeys.pendingBackgroundSms) ?? [];
    if (pending.isEmpty) return;

    await _prefs.remove(StorageKeys.pendingBackgroundSms);
    _log.i('Draining ${pending.length} background-queued SMS');

    try {
      final userPhoneSuffix = _userPhoneSuffix;
      final recentWithdrawals = await _localDs.getRecentMokashWithdrawals();
      final parsed = MomoParser.parseBatch(
        pending,
        userPhoneSuffix: userPhoneSuffix,
        recentWithdrawals: recentWithdrawals,
      );
      for (final tx in parsed) {
        final companion = await _applyCounterpartyMapping(
          _parsedToCompanion(tx),
          tx.partyPhone ?? tx.partyName,
        );
        await _localDs.insertTransaction(companion);
      }
    } catch (e) {
      _log.e('Failed to drain background SMS queue', error: e);
    }
  }

  // ─── Real-time listener ──────────────────────────────────────────

  void startListening() {
    _telephony.listenIncomingSms(
      onNewMessage: _onNewSms,
      listenInBackground: false,
    );
    _log.i('SMS listener started (foreground only)');
  }

  void _onNewSms(SmsMessage message) {
    if (!_isMomoMessage(message)) return;

    _log.i('New MoMo SMS from ${message.address}');
    _incomingController.add(message);

    final body = message.body;
    if (body == null || body.isEmpty) return;

    final tx = MomoParser.parse(body);
    if (tx == null) return;

    () async {
      final companion = await _applyCounterpartyMapping(
        _parsedToCompanion(tx, smsSender: message.address),
        tx.partyPhone ?? tx.partyName,
      );
      await _localDs.insertTransaction(companion);

      if (tx.transactionType == 'income' && tx.amount >= 40000) {
        _showSignificantIncomeNudge(tx.amount, source: tx.partyName);
      } else if (tx.transactionType == 'income') {
        _showPendingIncomeNudge();
      } else if (tx.transactionType == 'expense' && tx.amount >= 40000) {
        _showBigExpenseNudge(tx.amount);
      }
    }();
  }

  // ─── Nudge helpers ────────────────────────────────────────────────

  /// Compute local context and request an AI nudge for income events.
  Future<void> _showPendingIncomeNudge() async {
    try {
      await Future.delayed(const Duration(seconds: 2));
      final nudges = await _apiClient.generateNudgesWithContext(
        triggerType: 'income',
        context: await _buildContextJson(),
      );
      for (final nudge in nudges) {
        await _nudgeService.showNudge(
          id: nudge['id'] as int? ?? nudge.hashCode,
          title: nudge['title'] as String? ?? 'FinGuide Nudge',
          body: nudge['message'] as String? ?? '',
          type: nudge['recommendation_type'] as String? ?? 'savings',
        );
      }
    } catch (e) {
      _log.e('Failed to show income nudge', error: e);
    }
  }

  Future<void> _showSignificantIncomeNudge(double amount,
      {String? source}) async {
    try {
      await Future.delayed(const Duration(seconds: 2));
      final nudges = await _apiClient.generateNudgesWithContext(
        triggerType: 'income',
        incomeAmount: amount,
        incomeSource: source,
        context: await _buildContextJson(),
      );
      if (nudges.isNotEmpty) {
        final nudge = nudges.first;
        await _nudgeService.showNudge(
          id: nudge['id'] as int? ?? nudge.hashCode,
          title: nudge['title'] as String? ?? '💰 Money received!',
          body: nudge['message'] as String? ?? '',
          type: nudge['recommendation_type'] as String? ?? 'savings',
        );
      } else {
        final fmt = amount >= 1000000
            ? '${(amount / 1000000).toStringAsFixed(1)}M'
            : '${(amount / 1000).toStringAsFixed(0)}k';
        await _nudgeService.showNudge(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: '💰 RWF $fmt received!',
          body:
              'Great timing — consider moving 20% into savings or your Ejo Heza goal.',
          type: 'savings',
        );
      }
    } catch (e) {
      _log.e('Failed to show significant income nudge', error: e);
    }
  }

  Future<void> _showBigExpenseNudge(double amount) async {
    try {
      await Future.delayed(const Duration(seconds: 2));
      final fmt = amount >= 1000000
          ? '${(amount / 1000000).toStringAsFixed(1)}M'
          : '${(amount / 1000).toStringAsFixed(0)}k';
      final context = await _localDs.computeFinancialContext();
      final remaining = context.estimatedBalance;
      final remainFmt = remaining >= 1000
          ? '${(remaining / 1000).toStringAsFixed(0)}k'
          : remaining.toStringAsFixed(0);
      await _nudgeService.showNudge(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: '📊 RWF $fmt just left your wallet',
        body: remaining > 0
            ? 'You have RWF $remainFmt estimated balance. Stay on track!'
            : 'Big spend alert — check your FinGuide safe-to-spend.',
        type: 'spending',
      );
    } catch (e) {
      _log.e('Failed to show big expense nudge', error: e);
    }
  }

  // ─── Context building ─────────────────────────────────────────────

  Future<Map<String, dynamic>> _buildContextJson() async {
    final ctx = await _localDs.computeFinancialContext();
    return ctx.toJson();
  }

  // ─── Helpers ──────────────────────────────────────────────────────

  /// Last 3 digits of the authenticated user's phone (for self-transfer detect)
  String get _userPhoneSuffix {
    final phone = _prefs.getString(StorageKeys.userPhone) ?? '';
    return phone.length >= 3 ? phone.substring(phone.length - 3) : '';
  }

  bool _isMomoMessage(SmsMessage message) {
    final address = (message.address ?? '').toLowerCase();
    final body = (message.body ?? '').toLowerCase();
    return _momoSenders.any((s) => address.contains(s.toLowerCase())) ||
        _momoKeywords.any((k) => body.contains(k.toLowerCase()));
  }

  bool _isIncomeSms(String body) {
    final lower = body.toLowerCase();
    return _incomeKeywords.any((k) => lower.contains(k.toLowerCase()));
  }

  /// Convert a [ParsedTransaction] to a Drift companion for DB insertion.
  TransactionsCompanion _parsedToCompanion(
    ParsedTransaction tx, {
    String? smsSender,
  }) {
    return TransactionsCompanion(
      transactionType: Value(tx.transactionType),
      category: Value(tx.category),
      needWant: Value(tx.needWant),
      amount: Value(tx.amount),
      description: Value(tx.partyName),
      counterparty: Value(tx.partyPhone ?? tx.partyName),
      counterpartyName: Value(tx.partyName),
      reference: Value(tx.reference),
      transactionDate: Value(tx.date ?? DateTime.now()),
      balanceAfter: Value(tx.balance),
      confidenceScore: const Value(0.85),
      rawSms: Value(tx.rawSms),
      smsSender: Value(smsSender),
    );
  }

  /// Apply a saved counterparty mapping to override the parser's category.
  Future<TransactionsCompanion> _applyCounterpartyMapping(
    TransactionsCompanion companion,
    String? counterpartyKey,
  ) async {
    if (counterpartyKey == null) return companion;
    final mapping =
        await _localDs.getCounterpartyMapping(counterpartyKey);
    if (mapping == null) return companion;
    return companion.copyWith(
      category: Value(mapping.category),
      needWant: Value(mapping.needWant),
    );
  }

  void dispose() {
    _incomingController.close();
  }
}
