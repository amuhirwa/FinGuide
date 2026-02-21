/*
 * Auth BLoC
 * =========
 * State management for authentication
 */

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../data/datasources/auth_local_datasource.dart';
import '../../domain/entities/user.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/register_usecase.dart';
import '../../domain/usecases/check_auth_usecase.dart';

part 'auth_event.dart';
part 'auth_state.dart';

/// Authentication BLoC
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final LoginUseCase _loginUseCase;
  final RegisterUseCase _registerUseCase;
  final CheckAuthUseCase _checkAuthUseCase;
  final AuthLocalDataSource _localDataSource;

  AuthBloc({
    required LoginUseCase loginUseCase,
    required RegisterUseCase registerUseCase,
    required CheckAuthUseCase checkAuthUseCase,
    required AuthLocalDataSource localDataSource,
  })  : _loginUseCase = loginUseCase,
        _registerUseCase = registerUseCase,
        _checkAuthUseCase = checkAuthUseCase,
        _localDataSource = localDataSource,
        super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
  }

  /// Check authentication status on app start
  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    // Check if onboarding has been seen
    final hasSeenOnboarding = await _localDataSource.hasSeenOnboarding();

    if (!hasSeenOnboarding) {
      emit(AuthShowOnboarding());
      return;
    }

    // Check authentication status
    final result = await _checkAuthUseCase();

    result.fold(
      (failure) => emit(AuthUnauthenticated()),
      (user) async {
        // Check if SMS consent flow has been completed
        final hasSmsConsent = await _localDataSource.hasSmsConsentCompleted();
        if (!hasSmsConsent) {
          emit(AuthShowSmsConsent());
        } else {
          emit(AuthAuthenticated(user));
        }
      },
    );
  }

  /// Handle login request
  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    final result = await _loginUseCase(
      LoginParams(phoneNumber: event.phoneNumber, password: event.password),
    );

    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (user) async {
        final hasSmsConsent = await _localDataSource.hasSmsConsentCompleted();
        if (!hasSmsConsent) {
          emit(AuthShowSmsConsent());
        } else {
          emit(AuthAuthenticated(user));
        }
      },
    );
  }

  /// Handle registration request
  Future<void> _onRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    final result = await _registerUseCase(
      RegisterParams(
        phoneNumber: event.phoneNumber,
        fullName: event.fullName,
        password: event.password,
        ubudeheCategory: event.ubudeheCategory,
        incomeFrequency: event.incomeFrequency,
      ),
    );

    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (user) async {
        final hasSmsConsent = await _localDataSource.hasSmsConsentCompleted();
        if (!hasSmsConsent) {
          emit(AuthShowSmsConsent());
        } else {
          emit(AuthAuthenticated(user));
        }
      },
    );
  }

  /// Handle logout request
  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    await _localDataSource.clearAll();
    emit(AuthUnauthenticated());
  }
}
