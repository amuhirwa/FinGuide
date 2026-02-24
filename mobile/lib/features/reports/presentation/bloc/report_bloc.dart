/*
 * Reports BLoC
 * ============
 * State management for report export operations.
 */

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/reports_repository.dart';
import 'report_event.dart';
import 'report_state.dart';

class ReportBloc extends Bloc<ReportEvent, ReportState> {
  final ReportsRepository _repository;

  ReportBloc(this._repository) : super(const ReportInitial()) {
    on<ExportTransactionsRequested>(_onExportTransactionsRequested);
    on<ExportGoalsRequested>(_onExportGoalsRequested);
    on<ExportInvestmentsRequested>(_onExportInvestmentsRequested);
  }

  Future<void> _onExportTransactionsRequested(
    ExportTransactionsRequested event,
    Emitter<ReportState> emit,
  ) async {
    emit(const ReportExporting('transactions'));
    try {
      final result = await _repository.exportTransactions(
        startDate: event.startDate,
        endDate: event.endDate,
      );
      final recordCount = result['record_count'] as int? ?? 0;
      emit(ReportExported(
        reportType: 'transactions',
        recordCount: recordCount,
      ));
    } catch (e) {
      emit(ReportExportError('Failed to export transactions: $e'));
    }
  }

  Future<void> _onExportGoalsRequested(
    ExportGoalsRequested event,
    Emitter<ReportState> emit,
  ) async {
    emit(const ReportExporting('goals'));
    try {
      final result = await _repository.exportGoals();
      final recordCount = result['record_count'] as int? ?? 0;
      emit(ReportExported(
        reportType: 'goals',
        recordCount: recordCount,
      ));
    } catch (e) {
      emit(ReportExportError('Failed to export goals: $e'));
    }
  }

  Future<void> _onExportInvestmentsRequested(
    ExportInvestmentsRequested event,
    Emitter<ReportState> emit,
  ) async {
    emit(const ReportExporting('investments'));
    try {
      final result = await _repository.exportInvestments();
      final recordCount = result['record_count'] as int? ?? 0;
      emit(ReportExported(
        reportType: 'investments',
        recordCount: recordCount,
      ));
    } catch (e) {
      emit(ReportExportError('Failed to export investments: $e'));
    }
  }
}
