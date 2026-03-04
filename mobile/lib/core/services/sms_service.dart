/*
 * SMS Service
 * ===========
 * Reads existing MoMo SMS messages and listens for new ones in real-time.
 *
 * Uses the `telephony` package for SMS access on Android.
 * Messages are filtered to MoMo-related senders and parsed via the backend.
 *
 * Income detection: when new income SMS arrives, the backend generates an
 * AI nudge (via nudge_service.py). The mobile side then fetches and displays
 * that nudge as a local notification.
 */

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:telephony/telephony.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';

import '../constants/storage_keys.dart';
import '../network/api_client.dart';
import 'nudge_notification_service.dart';

/// Known MoMo sender addresses / keywords used to filter SMS.
/// MTN MoMo Rwanda sends from short-codes or addresses containing these strings.
const List<String> _momoSenders = [
  'M-Money',
  'MoMo',
  'MTN',
  'MobileMoney',
  'momo',
  '8199', // Common MTN MoMo short code in Rwanda
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
  // MoKash (savings account) messages
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
/// Duplicated here at the top level because [SmsService._extractAmount] is an
/// instance method and is not reachable from the background isolate.
double? _extractAmountBackground(String body) {
  final match =
      RegExp(r'([\d,]+)\s*RWF', caseSensitive: false).firstMatch(body);
  if (match == null) return null;
  return double.tryParse(match.group(1)!.replaceAll(',', ''));
}

/// Top-level background SMS handler required by the `telephony` package when
/// [listenInBackground] is `true`.
///
/// Android wakes this isolate (even when the app is killed) for every
/// incoming SMS.  We:
///   1. Initialize Flutter bindings so platform channels work.
///   2. Persist the body to SharedPreferences so the foreground delta-sync
///      can forward it to the backend for AI nudge generation.
///   3. If the message is a significant MoMo transaction (≥ 40 000 RWF),
///      fire an **immediate** local notification without contacting the
///      backend.  The AI-personalised nudge is shown on the next resume.
@pragma('vm:entry-point')
Future<void> backgroundSmsHandler(SmsMessage message) async {
  final body = message.body ?? '';
  if (body.isEmpty) return;

  // Initialize Flutter engine bindings so platform channels are available.
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Persist to queue for backend sync on next foreground.
  final prefs = await SharedPreferences.getInstance();
  final pending = prefs.getStringList(StorageKeys.pendingBackgroundSms) ?? [];
  if (!pending.contains(body)) {
    pending.add(body);
    await prefs.setStringList(StorageKeys.pendingBackgroundSms, pending);
  }

  // 2. Is this a MoMo message worth notifying on?
  final bodyLower = body.toLowerCase();
  final addressLower = (message.address ?? '').toLowerCase();
  final isMomo =
      _momoKeywords.any((k) => bodyLower.contains(k.toLowerCase())) ||
          _momoSenders.any((s) => addressLower.contains(s.toLowerCase()));
  if (!isMomo) return;

  final amount = _extractAmountBackground(body);
  // Only notify immediately for meaningful amounts (40 000 RWF baseline).
  if (amount == null || amount < 40000) return;

  final isIncome = _incomeKeywords.any(
    (k) => bodyLower.contains(k.toLowerCase()),
  );

  // 3. Show immediate local notification (no backend call).
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
class SmsService {
  final Telephony _telephony;
  final ApiClient _apiClient;
  final SharedPreferences _prefs;
  final NudgeNotificationService _nudgeService;
  final Logger _log = Logger();

  /// Stream controller that broadcasts newly received MoMo messages.
  final StreamController<SmsMessage> _incomingController =
      StreamController<SmsMessage>.broadcast();

  /// Public stream of incoming MoMo messages.
  Stream<SmsMessage> get onMomoReceived => _incomingController.stream;

  SmsService({
    required Telephony telephony,
    required ApiClient apiClient,
    required SharedPreferences prefs,
    required NudgeNotificationService nudgeService,
  })  : _telephony = telephony,
        _apiClient = apiClient,
        _prefs = prefs,
        _nudgeService = nudgeService;

  // ─── Permission helpers ────────────────────────────────────────────

  /// Request SMS permissions from the OS.  Returns `true` if granted.
  Future<bool> requestPermission() async {
    final granted = await _telephony.requestPhoneAndSmsPermissions ?? false;
    return granted;
  }

  /// Check whether SMS permissions have already been granted.
  Future<bool> get hasPermission async {
    final granted = await _telephony.requestPhoneAndSmsPermissions ?? false;
    return granted;
  }

  // ─── Consent persistence ──────────────────────────────────────────

  /// Whether the user has already given SMS consent.
  bool get hasConsented => _prefs.getBool(StorageKeys.smsConsentGiven) ?? false;

  /// Persist the user's consent choice.
  Future<void> setConsent(bool value) async {
    await _prefs.setBool(StorageKeys.smsConsentGiven, value);
  }

  // ─── Read historical SMS ─────────────────────────────────────────

  /// Read all existing MoMo SMS from the device inbox.
  ///
  /// Returns a list of raw message bodies that matched MoMo patterns.
  Future<List<String>> readHistoricalMessages() async {
    try {
      final List<SmsMessage> messages = await _telephony.getInboxSms(
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

  /// Read historical MoMo messages and send them to the backend for parsing.
  /// Returns the number of transactions successfully parsed.
  Future<int> importHistoricalMessages() async {
    final bodies = await readHistoricalMessages();
    if (bodies.isEmpty) return 0;

    try {
      int totalParsed = 0;
      bool hasIncome = false;

      // Send in batches of 50 to avoid huge payloads
      for (var i = 0; i < bodies.length; i += 50) {
        final batch = bodies.sublist(
          i,
          i + 50 > bodies.length ? bodies.length : i + 50,
        );
        final result = await _apiClient.parseSmsMessages(batch);
        final parsed = result['parsed_count'] as int? ?? batch.length;
        totalParsed += parsed;

        // Check if any of the batch contained income SMS
        if (!hasIncome) {
          hasIncome = batch.any(_isIncomeSms);
        }
      }

      await _prefs.setBool(StorageKeys.smsInitialImportDone, true);
      _log.i('Imported $totalParsed transactions from ${bodies.length} SMS');

      // Nudges are triggered by the backend background task on income parse.
      // Fetch and display any new income nudge after a short delay.
      if (hasIncome) {
        _showPendingIncomeNudge();
      }

      return totalParsed;
    } catch (e) {
      _log.e('Failed to import SMS to backend', error: e);
      return 0;
    }
  }

  // ─── Delta sync (new since last open) ──────────────────────────

  /// Import only MoMo SMS that arrived after the last successful sync.
  ///
  /// Also drains any messages that were captured by [backgroundSmsHandler]
  /// while the app was not in the foreground.
  ///
  /// Call this every time the app is foregrounded / opened so the user
  /// always sees up-to-date transactions without re-scanning all history.
  Future<int> syncNewMessages() async {
    // Process any SMS queued by the background isolate handler first.
    await _drainBackgroundQueue();

    final lastTimestamp = _prefs.getInt(StorageKeys.lastSmsSyncTimestamp) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      // Fetch only SMS newer than the stored timestamp
      final List<SmsMessage> messages = await _telephony.getInboxSms(
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

      _log.i('Delta sync: found ${newMomo.length} new MoMo SMS since '
          '${DateTime.fromMillisecondsSinceEpoch(lastTimestamp)}');

      bool hasIncome = newMomo.any(_isIncomeSms);
      int totalParsed = 0;

      for (var i = 0; i < newMomo.length; i += 50) {
        final batch = newMomo.sublist(
          i,
          (i + 50) > newMomo.length ? newMomo.length : i + 50,
        );
        final result = await _apiClient.parseSmsMessages(batch);
        totalParsed += result['parsed_count'] as int? ?? batch.length;
      }

      await _prefs.setInt(StorageKeys.lastSmsSyncTimestamp, now);
      _log.i('Delta sync complete: $totalParsed new transactions imported');

      // Show income nudge notification if significant income was detected
      if (hasIncome) {
        final threshold = await _getSignificantThreshold();
        final bigIncome = newMomo.any((sms) {
          final amt = _extractAmount(sms);
          return _isIncomeSms(sms) && amt != null && amt >= threshold;
        });
        if (bigIncome) {
          _showSignificantIncomeNudge(
            newMomo
                .where(_isIncomeSms)
                .map(_extractAmount)
                .whereType<double>()
                .fold(0.0, (a, b) => a + b),
          );
        } else {
          _showPendingIncomeNudge();
        }
      }

      return totalParsed;
    } catch (e) {
      _log.e('Delta SMS sync failed', error: e);
      return 0;
    }
  }

  // ─── Background queue drain ─────────────────────────────────────────

  /// Send any SMS bodies that were queued by [backgroundSmsHandler] to the
  /// backend and clear the queue.
  Future<void> _drainBackgroundQueue() async {
    final pending =
        _prefs.getStringList(StorageKeys.pendingBackgroundSms) ?? [];
    if (pending.isEmpty) return;

    // Clear immediately so a crash doesn't reprocess stale entries.
    await _prefs.remove(StorageKeys.pendingBackgroundSms);
    _log.i('Draining ${pending.length} background-queued SMS');

    try {
      for (var i = 0; i < pending.length; i += 50) {
        final batch = pending.sublist(
          i,
          (i + 50) > pending.length ? pending.length : i + 50,
        );
        await _apiClient.parseSmsMessages(batch);
      }
    } catch (e) {
      _log.e('Failed to drain background SMS queue', error: e);
    }
  }

  // ─── Real-time listener ───────────────────────────────────────────

  /// Start listening for new incoming MoMo SMS in the foreground.
  ///
  /// Note: [listenInBackground] is intentionally `false`.  The `telephony`
  /// package (v0.2.0) does not properly annotate its background channel
  /// entry point for AOT compilation and crashes the engine when enabled.
  /// Missed messages are caught by [syncNewMessages] every time the app is
  /// foregrounded via the [WidgetsBindingObserver] in main.dart.
  void startListening() {
    _telephony.listenIncomingSms(
      onNewMessage: _onNewSms,
      listenInBackground: false,
    );
    _log.i('SMS listener started (foreground only)');
  }

  /// Handle an incoming SMS.
  void _onNewSms(SmsMessage message) {
    if (_isMomoMessage(message)) {
      _log.i('New MoMo SMS detected from ${message.address}');
      _incomingController.add(message);

      final body = message.body;
      if (body != null && body.isNotEmpty) {
        final isIncome = _isIncomeSms(body);
        final amount = _extractAmount(body);
        _apiClient.parseSmsMessages([body]).then((_) async {
          // Check if this is significant enough to trigger a nudge
          final threshold = await _getSignificantThreshold();
          if (amount != null && amount >= threshold) {
            if (isIncome) {
              _showSignificantIncomeNudge(amount);
            } else {
              _showBigExpenseNudge(amount);
            }
          } else if (isIncome) {
            _showPendingIncomeNudge();
          }
        }).catchError((Object e) {
          _log.e('Failed to push live SMS to backend', error: e);
        });
      }
    }
  }

  // ─── Nudge helper ─────────────────────────────────────────────────

  /// After the backend has had a moment to generate an income nudge,
  /// fetch the latest recommendations and display them as local notifications.
  Future<void> _showPendingIncomeNudge() async {
    try {
      // Small delay so the backend background task can complete
      await Future.delayed(const Duration(seconds: 3));
      final nudges = await _apiClient.generateNudges('income');
      for (final nudge in nudges) {
        final id = nudge['id'] as int? ?? nudge.hashCode;
        final title = nudge['title'] as String? ?? 'FinGuide Nudge';
        final message = nudge['message'] as String? ?? '';
        final type = nudge['recommendation_type'] as String? ?? 'savings';
        await _nudgeService.showNudge(
          id: id,
          title: title,
          body: message,
          type: type,
        );
      }
    } catch (e) {
      _log.e('Failed to show income nudge notification', error: e);
    }
  }

  // ─── Significant transaction nudges ──────────────────────────────

  /// Returns the threshold (in RWF) above which a transaction is considered
  /// "significant" and warrants a nudge notification.
  ///
  /// = max(40_000, 5% of average monthly income).
  /// The average is derived from the last summary call; falls back to 40k.
  Future<double> _getSignificantThreshold() async {
    try {
      final summary = await _apiClient.getTransactionSummary();
      final avgIncome =
          (summary['average_monthly_income'] as num?)?.toDouble() ??
              (summary['total_income'] as num?)?.toDouble() ??
              0.0;
      return (avgIncome * 0.05).clamp(40000, double.infinity);
    } catch (_) {
      return 40000;
    }
  }

  /// Extract the first RWF amount from an SMS body (e.g. "20,000 RWF").
  double? _extractAmount(String body) {
    final match =
        RegExp(r'([\d,]+)\s*RWF', caseSensitive: false).firstMatch(body);
    if (match == null) return null;
    return double.tryParse(match.group(1)!.replaceAll(',', ''));
  }

  /// Show a nudge for a significant income event — prompt to save or invest.
  Future<void> _showSignificantIncomeNudge(double amount) async {
    try {
      await Future.delayed(const Duration(seconds: 3));
      final nudges = await _apiClient.generateNudges(
        'income',
        incomeAmount: amount,
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
        // Fallback generic nudge
        final fmt = amount >= 1000000
            ? '${(amount / 1000000).toStringAsFixed(1)}M'
            : amount >= 1000
                ? '${(amount / 1000).toStringAsFixed(0)}k'
                : amount.toStringAsFixed(0);
        await _nudgeService.showNudge(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: '💰 RWF $fmt received!',
          body:
              'Great timing — consider moving 20% into savings or your Ejo Heza goal before spending.',
          type: 'savings',
        );
      }
    } catch (e) {
      _log.e('Failed to show significant income nudge', error: e);
    }
  }

  /// Show a nudge after a big expense — remind the user of their situation.
  Future<void> _showBigExpenseNudge(double amount) async {
    try {
      await Future.delayed(const Duration(seconds: 2));
      final fmt = amount >= 1000000
          ? '${(amount / 1000000).toStringAsFixed(1)}M'
          : amount >= 1000
              ? '${(amount / 1000).toStringAsFixed(0)}k'
              : amount.toStringAsFixed(0);
      final safe = await _apiClient.getSafeToSpend();
      final remaining = (safe['safe_to_spend'] as num?)?.toDouble() ?? 0.0;
      final remainFmt = remaining >= 1000
          ? '${(remaining / 1000).toStringAsFixed(0)}k'
          : remaining.toStringAsFixed(0);
      await _nudgeService.showNudge(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: '📊 RWF $fmt just left your wallet',
        body: remaining > 0
            ? 'You have RWF $remainFmt safe to spend for the rest of the month. Stay on track!'
            : 'This is a big spend for your budget — check your FinGuide safe-to-spend before your next purchase.',
        type: 'spending',
      );
    } catch (e) {
      _log.e('Failed to show big expense nudge', error: e);
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────

  /// Check whether an SMS is a MoMo transaction message.
  bool _isMomoMessage(SmsMessage message) {
    final address = (message.address ?? '').toLowerCase();
    final body = (message.body ?? '').toLowerCase();

    final senderMatch = _momoSenders.any(
      (s) => address.contains(s.toLowerCase()),
    );
    final bodyMatch = _momoKeywords.any(
      (k) => body.contains(k.toLowerCase()),
    );

    return senderMatch || bodyMatch;
  }

  /// Check whether an SMS body indicates incoming money.
  bool _isIncomeSms(String body) {
    final lower = body.toLowerCase();
    return _incomeKeywords.any((k) => lower.contains(k.toLowerCase()));
  }

  /// Clean up resources.
  void dispose() {
    _incomingController.close();
  }
}
