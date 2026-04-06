/*
 * MoMo Parser
 * ===========
 * Dart port of backend/app/core/momo_parsing.py
 *
 * Parses MTN MoMo and MoKash SMS messages into structured transaction data
 * entirely on-device. Raw SMS bodies never leave the device.
 *
 * Supported patterns (same as the Python backend):
 *   0A — MoKash withdrawal ("You have transferred RWF X from your Mokash account")
 *    1 — P2P income       ("You have received X RWF from NAME (PHONE) at DATE")
 *    2 — P2P expense      ("X RWF transferred to NAME (PHONE) at DATE")
 *    3 — Merchant payment ("A transaction of X RWF by ENTITY was completed at DATE")
 *    4 — Payment/deposit  ("Your payment of X RWF to MERCHANT ...")
 *   0B — MoKash deposit confirmation (silenced — duplicate of pattern 4)
 */

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';

/// The result of parsing a single MoMo SMS body.
class ParsedTransaction {
  final String transactionType; // "income" | "expense" | "transfer"
  final double amount;
  final String category;
  final String needWant;
  final String? partyName;
  final String? partyPhone; // normalized to "07XXXXXXXX" or masked suffix
  final double? balance; // wallet balance after transaction, from SMS
  final DateTime? date;
  final String reference; // SHA-256 hex of raw SMS (first 32 chars)
  final bool isMokashWithdrawal;
  final bool isMokashDeposit;
  final bool isRnit;
  final String rawSms;

  const ParsedTransaction({
    required this.transactionType,
    required this.amount,
    required this.category,
    required this.needWant,
    this.partyName,
    this.partyPhone,
    this.balance,
    this.date,
    required this.reference,
    this.isMokashWithdrawal = false,
    this.isMokashDeposit = false,
    this.isRnit = false,
    required this.rawSms,
  });
}

/// On-device MoMo SMS parser.
class MomoParser {
  // ─── Cleaning patterns ────────────────────────────────────────────────────

  static final _txIdPattern = RegExp(r'\*16\d\*TxId:\d+\*S\*');
  static final _txIdBarePattern = RegExp(r'TxId:\d+\*S\*');
  static final _ussdPattern = RegExp(r'\*16\d\*S\*');
  static final _yelloPattern = RegExp(r"^Y'ello[.,]\s*", caseSensitive: false);
  static final _downloadPattern =
      RegExp(r'Download\s+MoMo.*$', caseSensitive: false, dotAll: true);

  // ─── Transaction patterns ─────────────────────────────────────────────────

  // Pattern 0A: MoKash withdrawal — money moving from MoKash back to MoMo wallet
  static final _pat0A = RegExp(
    r'You have transferred RWF ([\d,]+) from your Mokash account'
    r' on (\d{1,2}/\d{1,2}/\d{4}) at ([\d:]+\s*(?:AM|PM))',
    caseSensitive: false,
  );

  // Pattern 1: P2P received (income)
  static final _pat1 = RegExp(
    r'You have received ([\d,]+) RWF from (.*?)\s*\(([^)]+)\) at ([\d-]+ [\d:]+)',
    caseSensitive: false,
  );

  // Pattern 2: P2P sent (expense)
  static final _pat2 = RegExp(
    r'([\d,]+) RWF transferred to (.*?)\s*\((25\d{10}|25\d{9}|07\d{8})\) at ([\d-]+ [\d:]+)',
    caseSensitive: false,
  );

  // Pattern 3: Merchant / "A transaction of X RWF by ENTITY was completed"
  static final _pat3 = RegExp(
    r'A transaction of ([\d,]+) RWF by (.*?) was completed at ([\d-]+ [\d:]+)',
    caseSensitive: false,
  );

  // Pattern 4: Payment / MoKash deposit
  static final _pat4 = RegExp(
    r'Your payment of ([\d,]+) RWF to (.*?) (?:with token|was completed)',
    caseSensitive: false,
  );

  // Pattern 0B: MoKash deposit confirmation — silence this (duplicate of pat4)
  static final _pat0B = RegExp(
    r'RWF [\d,]+ transferred to your Mokash account',
    caseSensitive: false,
  );

  // ─── Extraction helpers ───────────────────────────────────────────────────

  static final _balancePattern = RegExp(r'Balance:\s*([\d,]+)');
  static final _mokashBalPattern =
      RegExp(r'Mokash balance is RWF ([\d,]+)', caseSensitive: false);
  static final _completedAtPattern =
      RegExp(r'completed at ([\d-]+ [\d:]+)');
  static final _mokashRefPattern =
      RegExp(r'Ref\s+(\d+)', caseSensitive: false);
  static final _rwfAmountPattern =
      RegExp(r'([\d,]+)\s*RWF', caseSensitive: false);

  // ─── need/want mapping (mirrors Python _adapt_parsed) ────────────────────

  static const _needWantMap = <String, String>{
    'airtime_data': 'need',
    'utilities': 'need',
    'food_groceries': 'need',
    'transport': 'need',
    'healthcare': 'need',
    'education': 'need',
    'rent': 'need',
    'salary': 'need',
    'savings': 'savings',
    'ejo_heza': 'savings',
    'investment': 'savings',
  };

  // ─── Public API ───────────────────────────────────────────────────────────

  /// Parse a single MoMo SMS body.
  /// Returns `null` if the message is not a recognised MoMo transaction.
  static ParsedTransaction? parse(String smsText) {
    if (smsText.trim().isEmpty) return null;

    final clean = _clean(smsText);
    final ref = _computeReference(smsText);

    // ── Pattern 0A: MoKash withdrawal ──────────────────────────────────────
    final m0A = _pat0A.firstMatch(clean);
    if (m0A != null) {
      final amount = _parseAmount(m0A.group(1)!);
      final date = _parseMokashDateTime(m0A.group(2)!, m0A.group(3)!);
      final balMatch = _mokashBalPattern.firstMatch(clean);
      final balance =
          balMatch != null ? _parseAmount(balMatch.group(1)!) : null;
      return ParsedTransaction(
        transactionType: 'transfer',
        amount: amount,
        category: 'savings',
        needWant: 'savings',
        partyName: 'MoKash Savings',
        balance: balance,
        date: date,
        reference: ref,
        isMokashWithdrawal: true,
        rawSms: smsText,
      );
    }

    // ── Pattern 1: P2P received (income) ───────────────────────────────────
    final m1 = _pat1.firstMatch(clean);
    if (m1 != null) {
      final amount = _parseAmount(m1.group(1)!);
      final date = _parseStandardDateTime(m1.group(4)!);
      final balMatch = _balancePattern.firstMatch(clean);
      final balance =
          balMatch != null ? _parseAmount(balMatch.group(1)!) : null;
      final phone = _normalizePhone(m1.group(3)!);
      return ParsedTransaction(
        transactionType: 'income',
        amount: amount,
        category: 'other_income',
        needWant: 'uncategorized',
        partyName: _titleCase(m1.group(2)!.trim()),
        partyPhone: phone,
        balance: balance,
        date: date,
        reference: ref,
        rawSms: smsText,
      );
    }

    // ── Pattern 2: P2P sent (expense) ──────────────────────────────────────
    final m2 = _pat2.firstMatch(clean);
    if (m2 != null) {
      final amount = _parseAmount(m2.group(1)!);
      final date = _parseStandardDateTime(m2.group(4)!);
      final balMatch = _balancePattern.firstMatch(clean);
      final balance =
          balMatch != null ? _parseAmount(balMatch.group(1)!) : null;
      final rawPhone = m2.group(3)!;
      final phone = rawPhone.startsWith('07')
          ? rawPhone
          : '0${rawPhone.substring(rawPhone.length - 9)}';
      return ParsedTransaction(
        transactionType: 'expense',
        amount: amount,
        category: 'transfer_out',
        needWant: 'uncategorized',
        partyName: _titleCase(m2.group(2)!.trim()),
        partyPhone: phone,
        balance: balance,
        date: date,
        reference: ref,
        rawSms: smsText,
      );
    }

    // ── Pattern 3: Merchant transaction ────────────────────────────────────
    final m3 = _pat3.firstMatch(clean);
    if (m3 != null) {
      final amount = _parseAmount(m3.group(1)!);
      final date = _parseStandardDateTime(m3.group(3)!);
      final balMatch = _balancePattern.firstMatch(clean);
      final balance =
          balMatch != null ? _parseAmount(balMatch.group(1)!) : null;
      final party = m3.group(2)!.trim();
      final pl = party.toLowerCase();

      String category;
      bool isRnit = false;
      if (pl.contains('data bundle') || pl.contains('airtime')) {
        category = 'airtime_data';
      } else if (pl.contains('rwanda national investment trust') ||
          pl.contains('rnit')) {
        category = 'investment';
        isRnit = true;
      } else if (pl.contains('mobile money rwanda')) {
        category = 'other';
      } else {
        category = 'utilities';
      }

      return ParsedTransaction(
        transactionType: 'expense',
        amount: amount,
        category: category,
        needWant: _needWantMap[category] ?? 'uncategorized',
        partyName: _titleCase(party),
        balance: balance,
        date: date,
        reference: ref,
        isRnit: isRnit,
        rawSms: smsText,
      );
    }

    // ── Pattern 4: Payment / MoKash deposit ────────────────────────────────
    final m4 = _pat4.firstMatch(clean);
    if (m4 != null) {
      final amount = _parseAmount(m4.group(1)!);
      final dateMatch = _completedAtPattern.firstMatch(clean);
      final date = dateMatch != null
          ? _parseStandardDateTime(dateMatch.group(1)!)
          : null;
      final balMatch = _balancePattern.firstMatch(clean);
      final balance =
          balMatch != null ? _parseAmount(balMatch.group(1)!) : null;
      final party = m4.group(2)!.trim();
      final pl = party.toLowerCase();

      String txType;
      String category;
      bool isMokashDeposit = false;

      if (pl.contains('mokash')) {
        txType = 'transfer';
        category = 'savings';
        isMokashDeposit = true;
      } else if (pl.contains('ejo heza')) {
        txType = 'expense';
        category = 'ejo_heza';
      } else {
        txType = 'expense';
        category = 'other';
      }

      return ParsedTransaction(
        transactionType: txType,
        amount: amount,
        category: category,
        needWant: _needWantMap[category] ?? 'uncategorized',
        partyName: _titleCase(party),
        balance: balance,
        date: date,
        reference: ref,
        isMokashDeposit: isMokashDeposit,
        rawSms: smsText,
      );
    }

    // ── Pattern 0B: MoKash deposit confirmation — silence ──────────────────
    if (_pat0B.hasMatch(clean)) return null;

    return null; // unrecognised format
  }

  /// Parse a batch of SMS bodies with cross-batch self-transfer suppression.
  ///
  /// [userPhoneSuffix] — last 3 digits of the user's own phone number, used
  /// to suppress a "received" SMS when the money came from the user's own
  /// MoKash account (i.e. a MoKash withdrawal).
  ///
  /// [recentWithdrawals] — set of MoKash withdrawal amounts from the local DB
  /// in the last 2 hours, for cross-batch self-transfer detection.
  static List<ParsedTransaction> parseBatch(
    List<String> smsBodies, {
    String userPhoneSuffix = '',
    Set<double> recentWithdrawals = const {},
  }) {
    // First pass: collect all MoKash withdrawal amounts within this batch
    final batchWithdrawals = <double>{};
    final parsed = <ParsedTransaction?>[];

    for (final body in smsBodies) {
      final tx = parse(body);
      parsed.add(tx);
      if (tx != null && tx.isMokashWithdrawal) {
        batchWithdrawals.add(tx.amount);
      }
    }

    final allWithdrawals = {...batchWithdrawals, ...recentWithdrawals};

    // Second pass: suppress income SMS that are self-transfers from MoKash
    final results = <ParsedTransaction>[];
    for (final tx in parsed) {
      if (tx == null) continue;

      if (tx.transactionType == 'income' && tx.partyPhone != null) {
        // If the sender's phone suffix matches the user's own number AND the
        // amount matches a known MoKash withdrawal, it's a self-transfer
        final phoneSuffix = tx.partyPhone!.length >= 3
            ? tx.partyPhone!.substring(tx.partyPhone!.length - 3)
            : tx.partyPhone!;
        if (userPhoneSuffix.isNotEmpty &&
            phoneSuffix == userPhoneSuffix &&
            allWithdrawals.contains(tx.amount)) {
          continue; // suppress self-transfer
        }
      }

      results.add(tx);
    }

    return results;
  }

  // ─── Private helpers ──────────────────────────────────────────────────────

  static String _clean(String raw) {
    var s = raw;
    s = s.replaceAll(_txIdPattern, '');
    s = s.replaceAll(_txIdBarePattern, '');
    s = s.replaceAll(_ussdPattern, '');
    s = s.replaceAll('*EN##', '').replaceAll('*EN#', '');
    s = s.trim();
    s = s.replaceFirst(_yelloPattern, '');
    s = s.replaceAll(_downloadPattern, '');
    return s.trim();
  }

  static double _parseAmount(String s) {
    return double.tryParse(s.replaceAll(',', '')) ?? 0.0;
  }

  /// Parse MoKash date/time format: "28/02/2026" + "11:29 AM"
  static DateTime? _parseMokashDateTime(String dateStr, String timeStr) {
    final combined = '${dateStr.trim()} ${timeStr.trim().toUpperCase()}';
    try {
      return DateFormat('dd/MM/yyyy hh:mm a').parse(combined);
    } catch (_) {}
    try {
      return DateFormat('dd/MM/yyyy HH:mm').parse(
        '${dateStr.trim()} ${timeStr.trim()}',
      );
    } catch (_) {}
    return null;
  }

  /// Parse standard MoMo datetime: "2026-02-28 11:29:00"
  static DateTime? _parseStandardDateTime(String s) {
    try {
      return DateTime.parse(s.trim());
    } catch (_) {}
    try {
      return DateFormat('yyyy-MM-dd HH:mm:ss').parse(s.trim());
    } catch (_) {}
    return null;
  }

  /// Normalize a phone number extracted from an SMS to "07XXXXXXXX".
  /// For masked numbers (e.g. "*****726"), stores the suffix only.
  static String? _normalizePhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return null;
    if (digits.length >= 9) {
      return digits.startsWith('07') ? digits : '0${digits.substring(digits.length - 9)}';
    }
    // Masked partial number — keep the suffix digits for self-transfer detection
    return digits;
  }

  /// Title-case all-caps names from MoMo; leave already-mixed strings alone.
  static String _titleCase(String name) {
    if (name.isEmpty) return name;
    if (name == name.toUpperCase()) {
      return name.split(' ').map((w) {
        if (w.isEmpty) return w;
        return w[0].toUpperCase() + w.substring(1).toLowerCase();
      }).join(' ');
    }
    return name;
  }

  /// Compute a SHA-256-based deduplication reference for an SMS body.
  /// Returns the first 32 hex characters of the SHA-256 digest.
  static String _computeReference(String smsText) {
    final bytes = utf8.encode(smsText);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 32);
  }

  /// Extract the first RWF amount from an SMS body.
  /// Used externally for quick checks (e.g. threshold comparisons).
  static double? extractAmount(String body) {
    final match = _rwfAmountPattern.firstMatch(body);
    if (match == null) return null;
    return double.tryParse(match.group(1)!.replaceAll(',', ''));
  }
}
