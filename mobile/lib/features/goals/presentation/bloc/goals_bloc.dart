/*
 * Goals BLoC
 * ==========
 * State management for savings goals
 */

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/savings_goal_model.dart';
import '../../data/repositories/goals_repository.dart';

// Events
abstract class GoalsEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadGoals extends GoalsEvent {
  final String? status;

  LoadGoals({this.status});

  @override
  List<Object?> get props => [status];
}

class CreateGoal extends GoalsEvent {
  final Map<String, dynamic> data;

  CreateGoal(this.data);

  @override
  List<Object?> get props => [data];
}

class UpdateGoal extends GoalsEvent {
  final int id;
  final Map<String, dynamic> data;

  UpdateGoal(this.id, this.data);

  @override
  List<Object?> get props => [id, data];
}

class DeleteGoal extends GoalsEvent {
  final int id;

  DeleteGoal(this.id);

  @override
  List<Object?> get props => [id];
}

class ContributeToGoal extends GoalsEvent {
  final int goalId;
  final double amount;
  final String? note;

  ContributeToGoal(this.goalId, this.amount, {this.note});

  @override
  List<Object?> get props => [goalId, amount, note];
}

// States
abstract class GoalsState extends Equatable {
  @override
  List<Object?> get props => [];
}

class GoalsInitial extends GoalsState {}

class GoalsLoading extends GoalsState {}

class GoalsLoaded extends GoalsState {
  final List<SavingsGoalModel> goals;

  GoalsLoaded(this.goals);

  @override
  List<Object?> get props => [goals];
}

class GoalCreated extends GoalsState {
  final SavingsGoalModel goal;

  GoalCreated(this.goal);

  @override
  List<Object?> get props => [goal];
}

class GoalUpdated extends GoalsState {
  final SavingsGoalModel goal;

  GoalUpdated(this.goal);

  @override
  List<Object?> get props => [goal];
}

class GoalDeleted extends GoalsState {}

class ContributionSuccess extends GoalsState {
  final SavingsGoalModel goal;

  ContributionSuccess(this.goal);

  @override
  List<Object?> get props => [goal];
}

class GoalsError extends GoalsState {
  final String message;

  GoalsError(this.message);

  @override
  List<Object?> get props => [message];
}

// BLoC
class GoalsBloc extends Bloc<GoalsEvent, GoalsState> {
  final GoalsRepository _repository;

  GoalsBloc(this._repository) : super(GoalsInitial()) {
    on<LoadGoals>(_onLoadGoals);
    on<CreateGoal>(_onCreateGoal);
    on<UpdateGoal>(_onUpdateGoal);
    on<DeleteGoal>(_onDeleteGoal);
    on<ContributeToGoal>(_onContribute);
  }

  Future<void> _onLoadGoals(LoadGoals event, Emitter<GoalsState> emit) async {
    emit(GoalsLoading());

    final result = await _repository.getGoals(status: event.status);

    result.fold(
      (error) => emit(GoalsError(error)),
      (goals) => emit(GoalsLoaded(goals)),
    );
  }

  Future<void> _onCreateGoal(CreateGoal event, Emitter<GoalsState> emit) async {
    emit(GoalsLoading());

    final result = await _repository.createGoal(event.data);

    result.fold(
      (error) => emit(GoalsError(error)),
      (goal) => emit(GoalCreated(goal)),
    );
  }

  Future<void> _onUpdateGoal(UpdateGoal event, Emitter<GoalsState> emit) async {
    emit(GoalsLoading());

    final result = await _repository.updateGoal(event.id, event.data);

    result.fold(
      (error) => emit(GoalsError(error)),
      (goal) => emit(GoalUpdated(goal)),
    );
  }

  Future<void> _onDeleteGoal(DeleteGoal event, Emitter<GoalsState> emit) async {
    emit(GoalsLoading());

    final result = await _repository.deleteGoal(event.id);

    result.fold(
      (error) => emit(GoalsError(error)),
      (_) => emit(GoalDeleted()),
    );
  }

  Future<void> _onContribute(
    ContributeToGoal event,
    Emitter<GoalsState> emit,
  ) async {
    emit(GoalsLoading());

    final result = await _repository.contributeToGoal(
      event.goalId,
      event.amount,
      note: event.note,
    );

    result.fold(
      (error) => emit(GoalsError(error)),
      (goal) => emit(ContributionSuccess(goal)),
    );
  }
}
