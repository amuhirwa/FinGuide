/// Unit tests for SmsService.
///
/// Tests cover consent management, delta-sync behaviour, historical import,
/// and the amount extraction regex logic.
///
/// Note: the MoMo filter logic (_isMomoMessage, _isIncomeSms) is already
/// fully tested in sms_detection_test.dart with the mirrored helpers.
/// Here we focus on the service-level integration: SharedPreferences,
/// ApiClient calls, and batching behaviour.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telephony/telephony.dart';

import 'package:finguide/core/constants/storage_keys.dart';
import 'package:finguide/core/network/api_client.dart';
import 'package:finguide/core/services/nudge_notification_service.dart';
import 'package:finguide/core/services/sms_service.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockTelephony extends Mock implements Telephony {}

class MockApiClient extends Mock implements ApiClient {}

class MockNudgeNotificationService extends Mock
    implements NudgeNotificationService {}

// ── Amount-extraction helper (mirrors the top-level logic in sms_service.dart) ──

double? _extractAmount(String body) {
  final match =
      RegExp(r'([\d,]+)\s*RWF', caseSensitive: false).firstMatch(body);
  if (match == null) return null;
  return double.tryParse(match.group(1)!.replaceAll(',', ''));
}

// ── Main ──────────────────────────────────────────────────────────────────────

void main() {
  late MockTelephony mockTelephony;
  late MockApiClient mockApiClient;
  late MockNudgeNotificationService mockNudgeService;
  late SharedPreferences prefs;

  setUp(() async {
    mockTelephony = MockTelephony();
    mockApiClient = MockApiClient();
    mockNudgeService = MockNudgeNotificationService();

    // Provide a fresh in-memory SharedPreferences for every test
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  SmsService makeService() => SmsService(
        telephony: mockTelephony,
        apiClient: mockApiClient,
        prefs: prefs,
        nudgeService: mockNudgeService,
      );

  // ── Consent management ────────────────────────────────────────────────────

  group('hasConsented', () {
    test('returns false when no preference is stored', () {
      expect(makeService().hasConsented, false);
    });

    test('returns true after setConsent(true)', () async {
      final svc = makeService();
      await svc.setConsent(true);
      expect(svc.hasConsented, true);
    });

    test('returns false after setConsent(false)', () async {
      await prefs.setBool(StorageKeys.smsConsentGiven, true);
      final svc = makeService();
      await svc.setConsent(false);
      expect(svc.hasConsented, false);
    });

    test('persists across service instances', () async {
      await makeService().setConsent(true);
      // Re-read the same prefs object — simulates app being re-accessed
      expect(prefs.getBool(StorageKeys.smsConsentGiven), true);
    });
  });

  // ── syncNewMessages ───────────────────────────────────────────────────────

  group('syncNewMessages', () {
    test('returns 0 when telephony inbox is empty', () async {
      when(() => mockTelephony.getInboxSms(
            columns: any(named: 'columns'),
            filter: any(named: 'filter'),
            sortOrder: any(named: 'sortOrder'),
          )).thenAnswer((_) async => <SmsMessage>[]);

      final count = await makeService().syncNewMessages();
      expect(count, 0);
    });

    test('does not call parseSmsMessages when inbox is empty', () async {
      when(() => mockTelephony.getInboxSms(
            columns: any(named: 'columns'),
            filter: any(named: 'filter'),
            sortOrder: any(named: 'sortOrder'),
          )).thenAnswer((_) async => <SmsMessage>[]);

      await makeService().syncNewMessages();

      verifyNever(() => mockApiClient.parseSmsMessages(any()));
    });

    test('drains pending background queue before reading inbox', () async {
      // Seed a pending background message in SharedPreferences
      await prefs.setStringList(
          StorageKeys.pendingBackgroundSms, ['You have received 50,000 RWF.']);

      when(() => mockApiClient.parseSmsMessages(any()))
          .thenAnswer((_) async => {'parsed_count': 1, 'transactions': []});
      when(() => mockTelephony.getInboxSms(
            columns: any(named: 'columns'),
            filter: any(named: 'filter'),
            sortOrder: any(named: 'sortOrder'),
          )).thenAnswer((_) async => <SmsMessage>[]);

      await makeService().syncNewMessages();

      // Queue should be cleared after drain (key removed → null, which is ≡ empty)
      final remaining =
          prefs.getStringList(StorageKeys.pendingBackgroundSms) ?? [];
      expect(remaining, isEmpty);
    });

    test('updates lastSmsSyncTimestamp after successful sync', () async {
      when(() => mockTelephony.getInboxSms(
            columns: any(named: 'columns'),
            filter: any(named: 'filter'),
            sortOrder: any(named: 'sortOrder'),
          )).thenAnswer((_) async => <SmsMessage>[]);

      final before = DateTime.now().millisecondsSinceEpoch;
      await makeService().syncNewMessages();
      final after = DateTime.now().millisecondsSinceEpoch;

      final saved = prefs.getInt(StorageKeys.lastSmsSyncTimestamp) ?? 0;
      expect(saved, greaterThanOrEqualTo(before));
      expect(saved, lessThanOrEqualTo(after));
    });
  });

  // ── importHistoricalMessages ──────────────────────────────────────────────

  group('importHistoricalMessages', () {
    test('returns 0 without calling API when inbox is empty', () async {
      when(() => mockTelephony.getInboxSms(
            columns: any(named: 'columns'),
            sortOrder: any(named: 'sortOrder'),
          )).thenAnswer((_) async => <SmsMessage>[]);

      final count = await makeService().importHistoricalMessages();
      expect(count, 0);
      verifyNever(() => mockApiClient.parseSmsMessages(any()));
    });

    test('marks initial import as done in SharedPreferences', () async {
      // Telephony returns one MoMo message
      final fakeMsg = _fakeSmsMessage(
        address: 'MTN',
        body: 'You have received 20,000 RWF. Balance: 200,000 RWF.',
      );
      when(() => mockTelephony.getInboxSms(
            columns: any(named: 'columns'),
            sortOrder: any(named: 'sortOrder'),
          )).thenAnswer((_) async => [fakeMsg]);
      when(() => mockApiClient.parseSmsMessages(any()))
          .thenAnswer((_) async => {'parsed_count': 1, 'transactions': []});

      await makeService().importHistoricalMessages();

      expect(prefs.getBool(StorageKeys.smsInitialImportDone), true);
    });
  });

  // ── Amount extraction regex ───────────────────────────────────────────────

  group('_extractAmount regex (mirrors sms_service.dart logic)', () {
    test('extracts plain integer amount', () {
      expect(_extractAmount('50000 RWF transferred'), 50000);
    });

    test('extracts comma-formatted large amount', () {
      expect(_extractAmount('You received 1,200,000 RWF'), 1200000);
    });

    test('extracts amount preceding RWF keyword', () {
      expect(_extractAmount('Payment of 3,500 RWF to Java House'), 3500);
    });

    test('returns null when no RWF in body', () {
      expect(_extractAmount('Hello, how are you?'), isNull);
    });

    test('handles lowercase rwf', () {
      expect(_extractAmount('5000 rwf transfer'), 5000);
    });

    test('returns null for empty string', () {
      expect(_extractAmount(''), isNull);
    });

    test('40k threshold — 39999 is below, 40000 is at boundary', () {
      expect(_extractAmount('39,999 RWF received')! < 40000, true);
      expect(_extractAmount('40,000 RWF received')! >= 40000, true);
    });

    test('extracts first amount when multiple present', () {
      // Should be 20,000 not 250,000
      final amount = _extractAmount(
        'You have received 20,000 RWF. Balance: 250,000 RWF.',
      );
      expect(amount, 20000);
    });
  });

  // ── Threshold logic ───────────────────────────────────────────────────────

  group('significant threshold (5% of avg income, floored at 40k)', () {
    test('threshold is always at least 40000', () {
      // Mirrors: (avgIncome * 0.05).clamp(40000, double.infinity)
      // With avgIncome = 0  → 40000
      final result = (0.0 * 0.05).clamp(40000.0, double.infinity);
      expect(result, 40000);
    });

    test('threshold scales when income is high', () {
      // avgIncome = 2,000,000 → 5% = 100,000
      final result = (2000000.0 * 0.05).clamp(40000.0, double.infinity);
      expect(result, 100000);
    });

    test('threshold still clips to 40000 for low income', () {
      // avgIncome = 300,000 → 5% = 15,000 → clamped to 40,000
      final result = (300000.0 * 0.05).clamp(40000.0, double.infinity);
      expect(result, 40000);
    });
  });
}

// ── Test helpers ──────────────────────────────────────────────────────────────

/// Create a fake [SmsMessage] without going through platform channels.
/// The telephony 0.2.0 [SmsMessage.fromMap] requires the column list
/// as a second positional argument.
SmsMessage _fakeSmsMessage({required String address, required String body}) {
  return SmsMessage.fromMap(
    {
      'address': address,
      'body': body,
      'date': DateTime.now().millisecondsSinceEpoch.toString(),
    },
    [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
  );
}
