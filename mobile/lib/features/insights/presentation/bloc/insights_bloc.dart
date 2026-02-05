/*
 * Insights BLoC
 * =============
 * State management for insights feature
 */

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/insights_model.dart';
import '../../data/repositories/insights_repository.dart';

// Events
abstract class InsightsEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadFinancialHealth extends InsightsEvent {}

class LoadPredictions extends InsightsEvent {
  final int? days;

  LoadPredictions({this.days});

  @override
  List<Object?> get props => [days];
}

class LoadSpendingAnalysis extends InsightsEvent {
  final DateTime? startDate;
  final DateTime? endDate;

  LoadSpendingAnalysis({this.startDate, this.endDate});

  @override
  List<Object?> get props => [startDate, endDate];
}

class RunInvestmentSimulation extends InsightsEvent {
  final double initialAmount;
  final double monthlyContribution;
  final int months;
  final double annualReturn;

  RunInvestmentSimulation({
    required this.initialAmount,
    required this.monthlyContribution,
    required this.months,
    required this.annualReturn,
  });

  @override
  List<Object?> get props =>
      [initialAmount, monthlyContribution, months, annualReturn];
}

// States
abstract class InsightsState extends Equatable {
  @override
  List<Object?> get props => [];
}

class InsightsInitial extends InsightsState {}

class InsightsLoading extends InsightsState {}

class FinancialHealthLoaded extends InsightsState {
  final FinancialHealth health;

  FinancialHealthLoaded(this.health);

  @override
  List<Object?> get props => [health];
}

class PredictionsLoaded extends InsightsState {
  final List<PredictionModel> predictions;

  PredictionsLoaded(this.predictions);

  @override
  List<Object?> get props => [predictions];
}

class SpendingAnalysisLoaded extends InsightsState {
  final List<SpendingCategory> categories;

  SpendingAnalysisLoaded(this.categories);

  @override
  List<Object?> get props => [categories];
}

class SimulationComplete extends InsightsState {
  final SimulationResult result;

  SimulationComplete(this.result);

  @override
  List<Object?> get props => [result];
}

class InsightsError extends InsightsState {
  final String message;

  InsightsError(this.message);

  @override
  List<Object?> get props => [message];
}

// BLoC
class InsightsBloc extends Bloc<InsightsEvent, InsightsState> {
  final InsightsRepository _repository;

  InsightsBloc(this._repository) : super(InsightsInitial()) {
    on<LoadFinancialHealth>(_onLoadHealth);
    on<LoadPredictions>(_onLoadPredictions);
    on<LoadSpendingAnalysis>(_onLoadSpending);
    on<RunInvestmentSimulation>(_onRunSimulation);
  }

  Future<void> _onLoadHealth(
    LoadFinancialHealth event,
    Emitter<InsightsState> emit,
  ) async {
    emit(InsightsLoading());

    final result = await _repository.getFinancialHealth();

    result.fold(
      (error) => emit(InsightsError(error)),
      (health) => emit(FinancialHealthLoaded(health)),
    );
  }

  Future<void> _onLoadPredictions(
    LoadPredictions event,
    Emitter<InsightsState> emit,
  ) async {
    emit(InsightsLoading());

    final result = await _repository.getPredictions(days: event.days);

    result.fold(
      (error) => emit(InsightsError(error)),
      (predictions) => emit(PredictionsLoaded(predictions)),
    );
  }

  Future<void> _onLoadSpending(
    LoadSpendingAnalysis event,
    Emitter<InsightsState> emit,
  ) async {
    emit(InsightsLoading());

    final result = await _repository.getSpendingByCategory(
      startDate: event.startDate,
      endDate: event.endDate,
    );

    result.fold(
      (error) => emit(InsightsError(error)),
      (categories) => emit(SpendingAnalysisLoaded(categories)),
    );
  }

  void _onRunSimulation(
    RunInvestmentSimulation event,
    Emitter<InsightsState> emit,
  ) {
    final result = _repository.runSimulation(
      initialAmount: event.initialAmount,
      monthlyContribution: event.monthlyContribution,
      months: event.months,
      annualReturn: event.annualReturn,
    );

    emit(SimulationComplete(result));
  }
}
