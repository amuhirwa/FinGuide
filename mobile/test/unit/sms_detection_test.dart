/// Unit tests for MoMo SMS detection and income classification.
///
/// These tests mirror the filtering logic in
/// lib/core/services/sms_service.dart and serve as a living specification
/// for which SMS patterns are recognised as MoMo transactions and which are
/// identified as income-credit events.
library;

import 'package:flutter_test/flutter_test.dart';

// ─── Mirrored constants from sms_service.dart ────────────────────────────────

const _momoSenders = [
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

const _momoKeywords = [
  'RWF',
  'Balance:',
  'transferred to',
  'received',
  'payment of',
  'transaction of',
  'FT Id',
];

const _incomeKeywords = [
  'received',
  'You have received',
  'has been deposited',
  'Cash In',
];

// ─── Mirrored helpers ─────────────────────────────────────────────────────────

bool _isMomoMessage({required String address, required String body}) {
  final lowerAddr = address.toLowerCase();
  final lowerBody = body.toLowerCase();
  return _momoSenders.any((s) => lowerAddr.contains(s.toLowerCase())) ||
      _momoKeywords.any((k) => lowerBody.contains(k.toLowerCase()));
}

bool _isIncomeSms(String body) {
  final lower = body.toLowerCase();
  return _incomeKeywords.any((k) => lower.contains(k.toLowerCase()));
}

// ─── Real SMS samples ─────────────────────────────────────────────────────────

const _receivedSms =
    'You have received 20,000 RWF from MUTONI BRICE (*********726) '
    'at 2024-11-15 10:23:45. Balance: 250,000 RWF.';

const _transferSms =
    '1,500 RWF transferred to Juldas NYIRISHEMA (250788217896) '
    'at 2024-11-16 14:05:00. Balance: 48,500 RWF.';

const _paymentSms =
    'Payment of 3,000 RWF to Java House at 10:00. Balance: 47,000 RWF.';

const _bundleSms = 'Your MTN bundle expires in 2 days.';

const _cashInSms = 'Cash In of 50,000 RWF successful. Balance: 300,000 RWF.';

const _depositSms =
    '50,000 RWF has been deposited to your account. Balance: 300,000 RWF.';

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('_isMomoMessage — sender address matching', () {
    test('MTN short sender is MoMo', () {
      expect(_isMomoMessage(address: 'MTN', body: ''), isTrue);
    });

    test('MoMo sender is MoMo', () {
      expect(_isMomoMessage(address: 'MoMo', body: ''), isTrue);
    });

    test('8199 short-code is MoMo', () {
      expect(_isMomoMessage(address: '8199', body: ''), isTrue);
    });

    test('sender matching is case-insensitive', () {
      expect(_isMomoMessage(address: 'mtn', body: ''), isTrue);
      expect(_isMomoMessage(address: 'MOBILEMONEY', body: ''), isTrue);
    });

    test('unknown sender without MoMo body keywords is NOT MoMo', () {
      expect(_isMomoMessage(address: 'PROMO', body: 'Win a prize!'), isFalse);
    });
  });

  group('_isMomoMessage — body keyword matching', () {
    test('RWF in body marks as MoMo', () {
      expect(
          _isMomoMessage(address: 'UNKNOWN', body: '5,000 RWF sent'), isTrue);
    });

    test('"Balance:" in body marks as MoMo', () {
      expect(
        _isMomoMessage(address: '9999', body: 'Balance: 100,000 RWF'),
        isTrue,
      );
    });

    test('"transferred to" in body marks as MoMo', () {
      expect(
        _isMomoMessage(address: 'BANK', body: '2,000 RWF transferred to Alice'),
        isTrue,
      );
    });

    test('full received SMS recognised as MoMo', () {
      expect(
        _isMomoMessage(address: 'MTN', body: _receivedSms),
        isTrue,
      );
    });

    test('full transfer SMS recognised as MoMo', () {
      expect(
        _isMomoMessage(address: 'MTN', body: _transferSms),
        isTrue,
      );
    });

    test('bundle expiry SMS from unknown sender is NOT MoMo', () {
      // Uses a non-MoMo sender so only body keywords are tested.
      // 'MTN Promo' would match because 'MTN' is in sender list.
      expect(
        _isMomoMessage(address: 'PROMO', body: _bundleSms),
        isFalse,
      );
    });

    test('random greeting SMS is NOT MoMo', () {
      expect(
        _isMomoMessage(address: 'FRIEND', body: 'Hello, how are you?'),
        isFalse,
      );
    });

    test('empty address and body is NOT MoMo', () {
      expect(_isMomoMessage(address: '', body: ''), isFalse);
    });
  });

  group('_isIncomeSms — income credit detection', () {
    test('MoMo received SMS is income', () {
      expect(_isIncomeSms(_receivedSms), isTrue);
    });

    test('transfer-out SMS is NOT income', () {
      expect(_isIncomeSms(_transferSms), isFalse);
    });

    test('merchant payment SMS is NOT income', () {
      expect(_isIncomeSms(_paymentSms), isFalse);
    });

    test('bundle expiry SMS is NOT income', () {
      expect(_isIncomeSms(_bundleSms), isFalse);
    });

    test('Cash In SMS is income', () {
      expect(_isIncomeSms(_cashInSms), isTrue);
    });

    test('deposit SMS is income', () {
      expect(_isIncomeSms(_depositSms), isTrue);
    });

    test('detection is case-insensitive', () {
      expect(_isIncomeSms('YOU HAVE RECEIVED 20,000 RWF'), isTrue);
    });

    test('empty string is NOT income', () {
      expect(_isIncomeSms(''), isFalse);
    });

    test('"has been deposited" phrase is income', () {
      expect(
        _isIncomeSms('20,000 RWF has been deposited to your account'),
        isTrue,
      );
    });
  });
}
