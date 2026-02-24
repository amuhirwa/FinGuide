/*
 * Reports BLoC Events
 */

import 'package:equatable/equatable.dart';

abstract class ReportEvent extends Equatable {
  const ReportEvent();

  @override
  List<Object?> get props => [];
}

/// Export transactions report (optionally filtered by date range)
class ExportTransactionsRequested extends ReportEvent {
  final DateTime? startDate;
  final DateTime? endDate;

  const ExportTransactionsRequested({this.startDate, this.endDate});

  @override
  List<Object?> get props => [startDate, endDate];
}

/// Export goals report
class ExportGoalsRequested extends ReportEvent {
  const ExportGoalsRequested();
}

/// Export investments report
class ExportInvestmentsRequested extends ReportEvent {
  const ExportInvestmentsRequested();
}
