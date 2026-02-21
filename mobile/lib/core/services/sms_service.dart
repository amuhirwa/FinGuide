/*
 * SMS Service
 * ===========
 * Reads existing MoMo SMS messages and listens for new ones in real-time.
 *
 * Uses the `telephony` package for SMS access on Android.
 * Messages are filtered to MoMo-related senders and parsed via the backend.
 */

import 'dart:async';

import 'package:telephony/telephony.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';

import '../constants/storage_keys.dart';
import '../network/api_client.dart';

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
];

/// Service responsible for reading & listening to MoMo SMS messages.
class SmsService {
  final Telephony _telephony;
  final ApiClient _apiClient;
  final SharedPreferences _prefs;
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
  })  : _telephony = telephony,
        _apiClient = apiClient,
        _prefs = prefs;

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
      // Send in batches of 50 to avoid huge payloads
      int totalParsed = 0;
      for (var i = 0; i < bodies.length; i += 50) {
        final batch = bodies.sublist(
          i,
          i + 50 > bodies.length ? bodies.length : i + 50,
        );
        final result = await _apiClient.parseSmsMessages(batch);
        final parsed = result['parsed_count'] as int? ?? batch.length;
        totalParsed += parsed;
      }

      await _prefs.setBool(StorageKeys.smsInitialImportDone, true);
      _log.i('Imported $totalParsed transactions from ${bodies.length} SMS');
      return totalParsed;
    } catch (e) {
      _log.e('Failed to import SMS to backend', error: e);
      return 0;
    }
  }

  // ─── Real-time listener ───────────────────────────────────────────

  /// Start listening for new incoming MoMo SMS in the foreground.
  void startListening() {
    _telephony.listenIncomingSms(
      onNewMessage: _onNewSms,
      listenInBackground: false,
    );
    _log.i('SMS listener started');
  }

  /// Handle an incoming SMS.
  void _onNewSms(SmsMessage message) {
    if (_isMomoMessage(message)) {
      _log.i('New MoMo SMS detected from ${message.address}');
      _incomingController.add(message);

      // Also push to backend immediately
      final body = message.body;
      if (body != null && body.isNotEmpty) {
        _apiClient.parseSmsMessages([body]).catchError((e) {
          _log.e('Failed to push live SMS to backend', error: e);
        });
      }
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────

  /// Check whether an SMS is a MoMo transaction message.
  bool _isMomoMessage(SmsMessage message) {
    final address = (message.address ?? '').toLowerCase();
    final body = (message.body ?? '').toLowerCase();

    // Check sender
    final senderMatch = _momoSenders.any(
      (s) => address.contains(s.toLowerCase()),
    );

    // Check body keywords (fallback – some phones strip the sender)
    final bodyMatch = _momoKeywords.any(
      (k) => body.contains(k.toLowerCase()),
    );

    return senderMatch || bodyMatch;
  }

  /// Clean up resources.
  void dispose() {
    _incomingController.close();
  }
}
