/*
 * Auth BLoC
 * =========
 * State management for authentication with Twilio SMS-OTP verification.
 *
 * Flow for login / register:
 *   1. LoginRequested / RegisterRequested
 *       → send-otp API  → emit AuthOtpPending
 *   2. OTP page listens for SMS via telephony, dispatches AuthOtpAutoDetected
 *       → verify-otp API → get otp_token
 *       → call login / register with otp_token
 *       → emit AuthAuthenticated (or AuthShowSmsConsent)
 *   3. If OTP send or verify fails → emit AuthOtpError
 */

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../data/datasources/auth_local_datasource.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/register_usecase.dart';
import '../../domain/usecases/check_auth_usecase.dart';
import '../../domain/usecases/send_otp_usecase.dart';
import '../../domain/usecases/verify_otp_usecase.dart';

part 'auth_event.dart';
part 'auth_state.dart';

/// Authentication BLoC
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final LoginUseCase _loginUseCase;
  final RegisterUseCase _registerUseCase;
  final CheckAuthUseCase _checkAuthUseCase;
  final SendOtpUseCase _sendOtpUseCase;
  final VerifyOtpUseCase _verifyOtpUseCase;
  final AuthLocalDataSource _localDataSource;
  final AuthRepository _authRepository;

  // ── Pending action storage ──────────────────────────────────────────────
  // Stored while waiting for OTP auto-detection on the OTP page.
  // Passwords and sensitive fields are kept here (not in state) to avoid
  // broadcasting them through the state stream.
  String? _pendingPhone;
  bool _pendingIsLogin = false;

  // Login fields
  String? _pendingPassword;

  // Register fields
  String? _pendingFullName;
  String? _pendingUbudehe;
  String? _pendingIncomeFreq;
  String? _pendingRegPassword;

  AuthBloc({
    required LoginUseCase loginUseCase,
    required RegisterUseCase registerUseCase,
    required CheckAuthUseCase checkAuthUseCase,
    required SendOtpUseCase sendOtpUseCase,
    required VerifyOtpUseCase verifyOtpUseCase,
    required AuthLocalDataSource localDataSource,
    required AuthRepository authRepository,
  })  : _loginUseCase = loginUseCase,
        _registerUseCase = registerUseCase,
        _checkAuthUseCase = checkAuthUseCase,
        _sendOtpUseCase = sendOtpUseCase,
        _verifyOtpUseCase = verifyOtpUseCase,
        _localDataSource = localDataSource,
        _authRepository = authRepository,
        super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthOtpAutoDetected>(_onOtpAutoDetected);
    on<AuthOtpResendRequested>(_onOtpResendRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthProfileUpdateRequested>(_onProfileUpdateRequested);
  }

  // ── Handlers ─────────────────────────────────────────────────────────────

  /// Check authentication status on app start
  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    final hasSeenOnboarding = await _localDataSource.hasSeenOnboarding();
    if (!hasSeenOnboarding) {
      emit(AuthShowOnboarding());
      return;
    }

    final result = await _checkAuthUseCase();
    await result.fold(
      (failure) async => emit(AuthUnauthenticated()),
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

  /// Login request – sends OTP first, then waits for device SMS auto-read
  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    final result = await _sendOtpUseCase(
      SendOtpParams(phoneNumber: event.phoneNumber),
    );

    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (_) {
        // Store credentials for use after OTP is verified
        _pendingPhone = event.phoneNumber;
        _pendingIsLogin = true;
        _pendingPassword = event.password;
        emit(AuthOtpPending(phoneNumber: event.phoneNumber));
      },
    );
  }

  /// Register request – sends OTP first, then waits for device SMS auto-read
  Future<void> _onRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    final result = await _sendOtpUseCase(
      SendOtpParams(phoneNumber: event.phoneNumber),
    );

    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (_) {
        _pendingPhone = event.phoneNumber;
        _pendingIsLogin = false;
        _pendingRegPassword = event.password;
        _pendingFullName = event.fullName;
        _pendingUbudehe = event.ubudeheCategory;
        _pendingIncomeFreq = event.incomeFrequency;
        emit(AuthOtpPending(phoneNumber: event.phoneNumber));
      },
    );
  }

  /// OTP auto-detected via SMS – verify it and complete the pending auth action
  Future<void> _onOtpAutoDetected(
    AuthOtpAutoDetected event,
    Emitter<AuthState> emit,
  ) async {
    final phone = _pendingPhone;
    if (phone == null) {
      emit(const AuthOtpError('Session expired. Please start again.'));
      return;
    }

    emit(AuthOtpVerifying());

    // Step 1: Verify OTP → get otp_token
    final verifyResult = await _verifyOtpUseCase(
      VerifyOtpParams(phoneNumber: phone, otpCode: event.otpCode),
    );

    await verifyResult.fold(
      (failure) async => emit(AuthOtpError(failure.message)),
      (otpToken) async {
        // Step 2: Complete login or register with the otp_token
        if (_pendingIsLogin) {
          await _completePendingLogin(otpToken, emit);
        } else {
          await _completePendingRegister(otpToken, emit);
        }
      },
    );
  }

  /// Resend OTP to the same phone (e.g. user tapped 'Resend')
  Future<void> _onOtpResendRequested(
    AuthOtpResendRequested event,
    Emitter<AuthState> emit,
  ) async {
    final phone = _pendingPhone;
    if (phone == null) {
      emit(const AuthOtpError('Session expired. Please start again.'));
      return;
    }

    emit(AuthLoading());

    final result = await _sendOtpUseCase(SendOtpParams(phoneNumber: phone));
    result.fold(
      (failure) => emit(AuthOtpError(failure.message)),
      (_) => emit(AuthOtpPending(phoneNumber: phone)),
    );
  }

  /// Handle logout
  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    _clearPending();
    emit(AuthLoading());
    await _localDataSource.clearAll();
    emit(AuthUnauthenticated());
  }

  /// Handle profile update
  Future<void> _onProfileUpdateRequested(
    AuthProfileUpdateRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthProfileUpdating());
    final result = await _authRepository.updateProfile(event.data);
    result.fold(
      (failure) => emit(AuthProfileUpdateError(failure.message)),
      (user) {
        // Emit AuthProfileUpdated first so EditProfilePage listener can react
        // (show toast / pop), then immediately restore AuthAuthenticated so every
        // other page that depends on the auth state (e.g. ProfilePage) keeps
        // rendering without an infinite spinner.
        emit(AuthProfileUpdated(user));
        emit(AuthAuthenticated(user));
      },
    );
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<void> _completePendingLogin(
    String otpToken,
    Emitter<AuthState> emit,
  ) async {
    final result = await _loginUseCase(
      LoginParams(
        phoneNumber: _pendingPhone!,
        password: _pendingPassword!,
        otpToken: otpToken,
      ),
    );

    await result.fold(
      (failure) async => emit(AuthOtpError(failure.message)),
      (user) async {
        _clearPending();
        final hasSmsConsent = await _localDataSource.hasSmsConsentCompleted();
        if (!hasSmsConsent) {
          emit(AuthShowSmsConsent());
        } else {
          emit(AuthAuthenticated(user));
        }
      },
    );
  }

  Future<void> _completePendingRegister(
    String otpToken,
    Emitter<AuthState> emit,
  ) async {
    final result = await _registerUseCase(
      RegisterParams(
        phoneNumber: _pendingPhone!,
        fullName: _pendingFullName!,
        password: _pendingRegPassword!,
        ubudeheCategory: _pendingUbudehe!,
        incomeFrequency: _pendingIncomeFreq!,
        otpToken: otpToken,
      ),
    );

    await result.fold(
      (failure) async => emit(AuthOtpError(failure.message)),
      (user) async {
        _clearPending();
        final hasSmsConsent = await _localDataSource.hasSmsConsentCompleted();
        if (!hasSmsConsent) {
          emit(AuthShowSmsConsent());
        } else {
          emit(AuthAuthenticated(user));
        }
      },
    );
  }

  void _clearPending() {
    _pendingPhone = null;
    _pendingPassword = null;
    _pendingRegPassword = null;
    _pendingFullName = null;
    _pendingUbudehe = null;
    _pendingIncomeFreq = null;
    _pendingIsLogin = false;
  }
}
