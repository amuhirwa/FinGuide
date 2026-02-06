/*
 * Investment Bloc
 * ===============
 * BLoC for investment state management
 */

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../data/models/investment_model.dart';
import '../../data/repositories/investment_repository.dart';

// ==================== Events ====================

abstract class InvestmentEvent extends Equatable {
  const InvestmentEvent();

  @override
  List<Object?> get props => [];
}

class LoadInvestments extends InvestmentEvent {}

class LoadInvestmentSummary extends InvestmentEvent {}

class LoadInvestmentAdvice extends InvestmentEvent {}

class CreateInvestment extends InvestmentEvent {
  final Map<String, dynamic> data;
  const CreateInvestment(this.data);

  @override
  List<Object?> get props => [data];
}

class UpdateInvestment extends InvestmentEvent {
  final int id;
  final Map<String, dynamic> data;
  const UpdateInvestment(this.id, this.data);

  @override
  List<Object?> get props => [id, data];
}

class DeleteInvestment extends InvestmentEvent {
  final int id;
  const DeleteInvestment(this.id);

  @override
  List<Object?> get props => [id];
}

class AddContribution extends InvestmentEvent {
  final int investmentId;
  final double amount;
  final bool isWithdrawal;
  final String? note;
  const AddContribution(
      this.investmentId, this.amount, this.isWithdrawal, this.note);

  @override
  List<Object?> get props => [investmentId, amount, isWithdrawal, note];
}

// ==================== States ====================

abstract class InvestmentState extends Equatable {
  const InvestmentState();

  @override
  List<Object?> get props => [];
}

class InvestmentInitial extends InvestmentState {}

class InvestmentLoading extends InvestmentState {}

class InvestmentsLoaded extends InvestmentState {
  final List<InvestmentModel> investments;
  final InvestmentSummary? summary;
  final List<InvestmentAdvice>? advice;

  const InvestmentsLoaded({
    required this.investments,
    this.summary,
    this.advice,
  });

  @override
  List<Object?> get props => [investments, summary, advice];
}

class InvestmentCreated extends InvestmentState {
  final InvestmentModel investment;
  const InvestmentCreated(this.investment);

  @override
  List<Object?> get props => [investment];
}

class InvestmentUpdated extends InvestmentState {
  final InvestmentModel investment;
  const InvestmentUpdated(this.investment);

  @override
  List<Object?> get props => [investment];
}

class InvestmentDeleted extends InvestmentState {}

class ContributionAdded extends InvestmentState {
  final ContributionModel contribution;
  const ContributionAdded(this.contribution);

  @override
  List<Object?> get props => [contribution];
}

class InvestmentError extends InvestmentState {
  final String message;
  const InvestmentError(this.message);

  @override
  List<Object?> get props => [message];
}

// ==================== Bloc ====================

class InvestmentBloc extends Bloc<InvestmentEvent, InvestmentState> {
  final InvestmentRepository _repository;

  InvestmentBloc(this._repository) : super(InvestmentInitial()) {
    on<LoadInvestments>(_onLoadInvestments);
    on<LoadInvestmentSummary>(_onLoadSummary);
    on<LoadInvestmentAdvice>(_onLoadAdvice);
    on<CreateInvestment>(_onCreateInvestment);
    on<UpdateInvestment>(_onUpdateInvestment);
    on<DeleteInvestment>(_onDeleteInvestment);
    on<AddContribution>(_onAddContribution);
  }

  Future<void> _onLoadInvestments(
    LoadInvestments event,
    Emitter<InvestmentState> emit,
  ) async {
    emit(InvestmentLoading());

    final investmentsResult = await _repository.getInvestments();
    final summaryResult = await _repository.getInvestmentSummary();
    final adviceResult = await _repository.getInvestmentAdvice();

    investmentsResult.fold(
      (error) => emit(InvestmentError(error)),
      (investments) {
        InvestmentSummary? summary;
        List<InvestmentAdvice>? advice;

        summaryResult.fold(
          (_) {},
          (s) => summary = s,
        );

        adviceResult.fold(
          (_) {},
          (a) => advice = a,
        );

        emit(InvestmentsLoaded(
          investments: investments,
          summary: summary,
          advice: advice,
        ));
      },
    );
  }

  Future<void> _onLoadSummary(
    LoadInvestmentSummary event,
    Emitter<InvestmentState> emit,
  ) async {
    // Just reload everything
    add(LoadInvestments());
  }

  Future<void> _onLoadAdvice(
    LoadInvestmentAdvice event,
    Emitter<InvestmentState> emit,
  ) async {
    // Just reload everything
    add(LoadInvestments());
  }

  Future<void> _onCreateInvestment(
    CreateInvestment event,
    Emitter<InvestmentState> emit,
  ) async {
    emit(InvestmentLoading());

    final result = await _repository.createInvestment(event.data);

    result.fold(
      (error) => emit(InvestmentError(error)),
      (investment) => emit(InvestmentCreated(investment)),
    );
  }

  Future<void> _onUpdateInvestment(
    UpdateInvestment event,
    Emitter<InvestmentState> emit,
  ) async {
    emit(InvestmentLoading());

    final result = await _repository.updateInvestment(event.id, event.data);

    result.fold(
      (error) => emit(InvestmentError(error)),
      (investment) => emit(InvestmentUpdated(investment)),
    );
  }

  Future<void> _onDeleteInvestment(
    DeleteInvestment event,
    Emitter<InvestmentState> emit,
  ) async {
    emit(InvestmentLoading());

    final result = await _repository.deleteInvestment(event.id);

    result.fold(
      (error) => emit(InvestmentError(error)),
      (_) => emit(InvestmentDeleted()),
    );
  }

  Future<void> _onAddContribution(
    AddContribution event,
    Emitter<InvestmentState> emit,
  ) async {
    emit(InvestmentLoading());

    final result = await _repository.addContribution(
      event.investmentId,
      {
        'amount': event.amount,
        'is_withdrawal': event.isWithdrawal,
        'note': event.note,
        'contribution_date': DateTime.now().toIso8601String(),
      },
    );

    result.fold(
      (error) => emit(InvestmentError(error)),
      (contribution) => emit(ContributionAdded(contribution)),
    );
  }
}
