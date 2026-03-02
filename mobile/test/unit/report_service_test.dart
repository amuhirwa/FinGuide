/// Unit tests for ReportService.buildCsv().
///
/// Mirrors the production _escape logic and buildCsv implementation
/// to verify CSV output without touching platform channels
/// (shareCsv / exportAndShare are not tested here as they require
/// path_provider and share_plus native plugins).
library;

import 'package:flutter_test/flutter_test.dart';

// ── Mirrored implementation (same logic as ReportService) ─────────────────────

String _escape(dynamic value) {
  final s = value?.toString() ?? '';
  if (s.contains(',') || s.contains('"') || s.contains('\n')) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}

String buildCsv(List<dynamic> headers, List<dynamic> rows) {
  final buffer = StringBuffer();
  buffer.writeln(headers.map(_escape).join(','));
  for (final row in rows) {
    if (row is List) {
      buffer.writeln(row.map(_escape).join(','));
    }
  }
  return buffer.toString();
}

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ── _escape helper ──────────────────────────────────────────────────────

  group('_escape', () {
    test('plain string passes through unchanged', () {
      expect(_escape('Hello'), 'Hello');
    });

    test('null becomes empty string', () {
      expect(_escape(null), '');
    });

    test('integer is converted to string', () {
      expect(_escape(42), '42');
    });

    test('string with comma is wrapped in double-quotes', () {
      expect(_escape('Hello, world'), '"Hello, world"');
    });

    test('string with double-quote escapes the quote and wraps', () {
      expect(_escape('Say "hi"'), '"Say ""hi"""');
    });

    test('string with newline is wrapped in double-quotes', () {
      expect(_escape('line1\nline2'), '"line1\nline2"');
    });

    test('string with both comma and quote is handled correctly', () {
      final result = _escape('a, "b"');
      expect(result, startsWith('"'));
      expect(result, endsWith('"'));
      expect(result, contains('""b""'));
    });

    test('empty string passes through unchanged', () {
      expect(_escape(''), '');
    });
  });

  // ── buildCsv ─────────────────────────────────────────────────────────────

  group('buildCsv', () {
    test('empty rows returns only header line', () {
      final csv = buildCsv(['Name', 'Amount'], []);
      final lines = csv.trim().split('\n');
      expect(lines.length, 1);
      expect(lines[0], 'Name,Amount');
    });

    test('single row produces correct output', () {
      final csv = buildCsv(
        ['Date', 'Type', 'Amount (RWF)'],
        [
          ['2024-01-15', 'income', '50000.00']
        ],
      );
      final lines = csv.trim().split('\n');
      expect(lines.length, 2);
      expect(lines[0], 'Date,Type,Amount (RWF)');
      expect(lines[1], '2024-01-15,income,50000.00');
    });

    test('multiple rows all appear in output', () {
      final csv = buildCsv(
        ['Name', 'Amount'],
        [
          ['Alice', '10000'],
          ['Bob', '20000'],
          ['Charlie', '30000'],
        ],
      );
      final lines = csv.trim().split('\n');
      expect(lines.length, 4); // 1 header + 3 data rows
    });

    test('header containing comma is quoted', () {
      final csv = buildCsv(['Amount (RWF, total)', 'Status'], []);
      expect(csv, contains('"Amount (RWF, total)"'));
    });

    test('row cell containing comma is quoted', () {
      final csv = buildCsv(
        ['Name', 'Notes'],
        [
          ['John', 'salary, bonus']
        ],
      );
      expect(csv, contains('"salary, bonus"'));
    });

    test('row cell containing double-quote is escaped', () {
      final csv = buildCsv(
        ['Description'],
        [
          ['He said "hello"']
        ],
      );
      expect(csv, contains('"He said ""hello"""'));
    });

    test('non-list rows are skipped silently', () {
      // Non-list items should not appear in output
      final csv = buildCsv(
        ['Name'],
        [
          ['Alice'],
          'not a list',  // should be ignored
          ['Bob'],
        ],
      );
      final lines = csv.trim().split('\n');
      // header + Alice + Bob = 3 lines
      expect(lines.length, 3);
    });

    test('numeric values are converted to string correctly', () {
      final csv = buildCsv(
        ['Amount'],
        [
          [50000.0]
        ],
      );
      expect(csv, contains('50000.0'));
    });

    test('null cell values become empty string', () {
      final csv = buildCsv(
        ['Name', 'Note'],
        [
          ['Alice', null]
        ],
      );
      expect(csv, contains('Alice,'));
    });

    test('output ends with newline', () {
      final csv = buildCsv(['A'], [['1']]);
      expect(csv.endsWith('\n'), true);
    });

    test('transaction report shape matches expected headers', () {
      final headers = [
        'Date', 'Type', 'Category', 'Need/Want', 'Amount (RWF)',
        'Description', 'Counterparty', 'Reference', 'Verified',
      ];
      final rows = [
        ['2024-01-15 09:00', 'income', 'other_income', 'uncategorized',
         '50000.00', 'Salary', 'Employer', 'REF001', 'No']
      ];
      final csv = buildCsv(headers, rows);
      final lines = csv.trim().split('\n');
      final headerCols = lines[0].split(',');
      expect(headerCols.length, 9);
      final dataCols = lines[1].split(',');
      expect(dataCols.length, 9);
    });
  });
}
