/*
 * Reports Repository
 * ==================
 * Fetches report data from the API and delegates CSV export to ReportService.
 */

import '../../../../core/network/api_client.dart';
import '../../../../core/services/report_service.dart';

class ReportsRepository {
  final ApiClient _apiClient;
  final ReportService _reportService;

  ReportsRepository(this._apiClient, this._reportService);

  /// Export transactions as CSV and trigger the share sheet.
  Future<Map<String, dynamic>> exportTransactions({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final data = await _apiClient.exportTransactions(
      startDate: startDate,
      endDate: endDate,
    );

    await _reportService.exportAndShare(
      headers: data['headers'] as List,
      rows: data['rows'] as List,
      fileName: 'finguide_transactions_${_dateSuffix()}.csv',
    );

    return data;
  }

  /// Export goals as CSV and trigger the share sheet.
  Future<Map<String, dynamic>> exportGoals() async {
    final data = await _apiClient.exportGoals();

    // Main goals table
    final csv = StringBuffer();
    csv.writeln(_reportService.buildCsv(
      data['headers'] as List,
      data['rows'] as List,
    ));

    // Append contributions sub-table if present
    final contributions = data['contributions'] as Map<String, dynamic>?;
    if (contributions != null && (contributions['rows'] as List).isNotEmpty) {
      csv.writeln(); // blank line separator
      csv.writeln('Contributions');
      csv.write(_reportService.buildCsv(
        contributions['headers'] as List,
        contributions['rows'] as List,
      ));
    }

    await _reportService.shareCsv(
      csvContent: csv.toString(),
      fileName: 'finguide_goals_${_dateSuffix()}.csv',
    );

    return data;
  }

  /// Export investments as CSV and trigger the share sheet.
  Future<Map<String, dynamic>> exportInvestments() async {
    final data = await _apiClient.exportInvestments();

    await _reportService.exportAndShare(
      headers: data['headers'] as List,
      rows: data['rows'] as List,
      fileName: 'finguide_investments_${_dateSuffix()}.csv',
    );

    return data;
  }

  String _dateSuffix() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  }
}
