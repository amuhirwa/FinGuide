/*
 * RNIT BLoC
 * =========
 * State management for RNIT (Rwanda National Investment Trust) portfolio
 */

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/rnit_model.dart';
import '../../data/repositories/rnit_repository.dart';

// ── Events ────────────────────────────────────────────────────────────────────

abstract class RnitEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadRnitPortfolio extends RnitEvent {}

class RefreshRnitNav extends RnitEvent {}

// ── States ────────────────────────────────────────────────────────────────────

abstract class RnitState extends Equatable {
  @override
  List<Object?> get props => [];
}

class RnitInitial extends RnitState {}

class RnitLoading extends RnitState {}

class RnitLoaded extends RnitState {
  final RnitPortfolio portfolio;
  final List<RnitNavPoint> navHistory;
  final bool refreshing;

  RnitLoaded(this.portfolio, this.navHistory, {this.refreshing = false});

  @override
  List<Object?> get props => [portfolio, navHistory, refreshing];

  RnitLoaded copyWith({
    RnitPortfolio? portfolio,
    List<RnitNavPoint>? navHistory,
    bool? refreshing,
  }) {
    return RnitLoaded(
      portfolio ?? this.portfolio,
      navHistory ?? this.navHistory,
      refreshing: refreshing ?? this.refreshing,
    );
  }
}

class RnitError extends RnitState {
  final String message;

  RnitError(this.message);

  @override
  List<Object?> get props => [message];
}

class RnitEmpty extends RnitState {}

// ── BLoC ──────────────────────────────────────────────────────────────────────

class RnitBloc extends Bloc<RnitEvent, RnitState> {
  final RnitRepository _repository;

  RnitBloc(this._repository) : super(RnitInitial()) {
    on<LoadRnitPortfolio>(_onLoad);
    on<RefreshRnitNav>(_onRefresh);
  }

  Future<void> _onLoad(LoadRnitPortfolio event, Emitter<RnitState> emit) async {
    emit(RnitLoading());

    final portfolioResult = await _repository.getPortfolio();

    await portfolioResult.fold(
      (error) async {
        // 404 means user has no RNIT purchases yet — show empty state
        if (error.contains('404') || error.contains('No RNIT')) {
          emit(RnitEmpty());
        } else {
          emit(RnitError(error));
        }
      },
      (portfolio) async {
        final historyResult = await _repository.getNavHistory(limit: 90);
        final navHistory = historyResult.getOrElse(() => []);
        emit(RnitLoaded(portfolio, navHistory));
      },
    );
  }

  Future<void> _onRefresh(RefreshRnitNav event, Emitter<RnitState> emit) async {
    final current = state;
    if (current is RnitLoaded) {
      emit(current.copyWith(refreshing: true));
    }

    await _repository.refreshNav();

    // Reload after refresh
    final portfolioResult = await _repository.getPortfolio();
    await portfolioResult.fold(
      (error) async => emit(RnitError(error)),
      (portfolio) async {
        final historyResult = await _repository.getNavHistory(limit: 90);
        final navHistory = historyResult.getOrElse(() => []);
        emit(RnitLoaded(portfolio, navHistory));
      },
    );
  }
}
