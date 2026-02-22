/*
 * Report Service
 * ==============
 * Converts backend report JSON into CSV strings and triggers
 * the native share sheet so the user can save or send the file.
 */

import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ReportService {
  /// Build a CSV string from [headers] and [rows].
  String buildCsv(List<dynamic> headers, List<dynamic> rows) {
    final buffer = StringBuffer();

    // Header row
    buffer.writeln(headers.map(_escape).join(','));

    // Data rows
    for (final row in rows) {
      if (row is List) {
        buffer.writeln(row.map(_escape).join(','));
      }
    }

    return buffer.toString();
  }

  /// Write [csvContent] to a temporary file and open the OS share sheet.
  Future<void> shareCsv({
    required String csvContent,
    required String fileName,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(csvContent);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      subject: fileName,
    );
  }

  /// Convenience: build + share in one call.
  Future<void> exportAndShare({
    required List<dynamic> headers,
    required List<dynamic> rows,
    required String fileName,
  }) async {
    final csv = buildCsv(headers, rows);
    await shareCsv(csvContent: csv, fileName: fileName);
  }

  /// Escape a cell value for CSV (wrap in quotes if it contains commas/newlines).
  String _escape(dynamic value) {
    final s = value?.toString() ?? '';
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }
}
