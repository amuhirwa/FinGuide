/*
 * Reports BLoC State
 */

import 'package:equatable/equatable.dart';

abstract class ReportState extends Equatable {
  const ReportState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class ReportInitial extends ReportState {
  const ReportInitial();
}

/// Report export in progress
class ReportExporting extends ReportState {
  final String reportType; // 'transactions', 'goals', or 'investments'

  const ReportExporting(this.reportType);

  @override
  List<Object?> get props => [reportType];
}

/// Report export succeeded (CSV shared)
class ReportExported extends ReportState {
  final String reportType;
  final int recordCount;

  const ReportExported({
    required this.reportType,
    required this.recordCount,
  });

  @override
  List<Object?> get props => [reportType, recordCount];
}

/// Report export failed
class ReportExportError extends ReportState {
  final String message;

  const ReportExportError(this.message);

  @override
  List<Object?> get props => [message];
}
