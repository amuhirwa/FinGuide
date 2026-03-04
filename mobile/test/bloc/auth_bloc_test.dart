/// BLoC tests for AuthBloc.
///
/// Uses bloc_test + mocktail to verify state transitions for every
/// event without touching GetIt, platform channels, or the network.
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:finguide/core/error/failures.dart';
import 'package:finguide/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:finguide/features/auth/domain/entities/user.dart';
import 'package:finguide/features/auth/domain/usecases/check_auth_usecase.dart';
import 'package:finguide/features/auth/domain/usecases/login_usecase.dart';
import 'package:finguide/features/auth/domain/usecases/register_usecase.dart';
import 'package:finguide/features/auth/domain/usecases/send_otp_usecase.dart';
import 'package:finguide/features/auth/domain/usecases/verify_otp_usecase.dart';
import 'package:finguide/features/auth/domain/repositories/auth_repository.dart';
import 'package:finguide/features/auth/presentation/bloc/auth_bloc.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockAuthRepository extends Mock implements AuthRepository {}

class MockSendOtpUseCase extends Mock implements SendOtpUseCase {}

class MockVerifyOtpUseCase extends Mock implements VerifyOtpUseCase {}

class MockLoginUseCase extends Mock implements LoginUseCase {}

class MockRegisterUseCase extends Mock implements RegisterUseCase {}

class MockCheckAuthUseCase extends Mock implements CheckAuthUseCase {}

class MockAuthLocalDataSource extends Mock implements AuthLocalDataSource {}

// ── Test Data ─────────────────────────────────────────────────────────────────

const kPhone = '+250781234567';
const kPassword = 'Test@1234';
const kOtpCode = '654321';
const kOtpToken = 'fake.otp.token';

final kTestUser = User(
  id: 1,
  phoneNumber: kPhone,
  fullName: 'Test User',
  ubudeheCategory: 'category_2',
  incomeFrequency: 'monthly',
  isActive: true,
  isVerified: true,
  createdAt: DateTime(2024, 1, 1),
);

const kServerFailure = ServerFailure(message: 'Server error');
const kAuthFailure = AuthFailure(message: 'Invalid credentials');

// ── Helpers ───────────────────────────────────────────────────────────────────

AuthBloc _makeBloc({
  required MockSendOtpUseCase sendOtp,
  required MockVerifyOtpUseCase verifyOtp,
  required MockLoginUseCase login,
  required MockRegisterUseCase register,
  required MockCheckAuthUseCase checkAuth,
  required MockAuthLocalDataSource localDS,
  MockAuthRepository? authRepository,
}) {
  return AuthBloc(
    sendOtpUseCase: sendOtp,
    verifyOtpUseCase: verifyOtp,
    loginUseCase: login,
    registerUseCase: register,
    checkAuthUseCase: checkAuth,
    localDataSource: localDS,
    authRepository: authRepository ?? MockAuthRepository(),
  );
}

void main() {
  late MockSendOtpUseCase mockSendOtp;
  late MockVerifyOtpUseCase mockVerifyOtp;
  late MockLoginUseCase mockLogin;
  late MockRegisterUseCase mockRegister;
  late MockCheckAuthUseCase mockCheckAuth;
  late MockAuthLocalDataSource mockLocalDS;

  setUp(() {
    mockSendOtp = MockSendOtpUseCase();
    mockVerifyOtp = MockVerifyOtpUseCase();
    mockLogin = MockLoginUseCase();
    mockRegister = MockRegisterUseCase();
    mockCheckAuth = MockCheckAuthUseCase();
    mockLocalDS = MockAuthLocalDataSource();

    // Fallback registrations required by mocktail
    registerFallbackValue(const SendOtpParams(phoneNumber: kPhone));
    registerFallbackValue(
        const VerifyOtpParams(phoneNumber: kPhone, otpCode: kOtpCode));
    registerFallbackValue(LoginParams(
      phoneNumber: kPhone,
      password: kPassword,
      otpToken: kOtpToken,
    ));
    registerFallbackValue(RegisterParams(
      phoneNumber: kPhone,
      fullName: 'Test User',
      password: kPassword,
      ubudeheCategory: 'category_2',
      incomeFrequency: 'monthly',
      otpToken: kOtpToken,
    ));
  });

  // ── AuthCheckRequested ───────────────────────────────────────────────────

  group('AuthCheckRequested', () {
    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthShowOnboarding] when onboarding not seen',
      build: () {
        when(() => mockLocalDS.hasSeenOnboarding())
            .thenAnswer((_) async => false);
        return _makeBloc(
          sendOtp: mockSendOtp,
          verifyOtp: mockVerifyOtp,
          login: mockLogin,
          register: mockRegister,
          checkAuth: mockCheckAuth,
          localDS: mockLocalDS,
        );
      },
      act: (bloc) => bloc.add(AuthCheckRequested()),
      expect: () => [isA<AuthLoading>(), isA<AuthShowOnboarding>()],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthUnauthenticated] when onboarding seen but no token',
      build: () {
        when(() => mockLocalDS.hasSeenOnboarding())
            .thenAnswer((_) async => true);
        when(() => mockCheckAuth()).thenAnswer(
          (_) async => const Left(AuthFailure(message: 'No token found')),
        );
        return _makeBloc(
          sendOtp: mockSendOtp,
          verifyOtp: mockVerifyOtp,
          login: mockLogin,
          register: mockRegister,
          checkAuth: mockCheckAuth,
          localDS: mockLocalDS,
        );
      },
      act: (bloc) => bloc.add(AuthCheckRequested()),
      expect: () => [isA<AuthLoading>(), isA<AuthUnauthenticated>()],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthAuthenticated] when token valid and SMS consent done',
      build: () {
        when(() => mockLocalDS.hasSeenOnboarding())
            .thenAnswer((_) async => true);
        when(() => mockCheckAuth()).thenAnswer((_) async => Right(kTestUser));
        when(() => mockLocalDS.hasSmsConsentCompleted())
            .thenAnswer((_) async => true);
        return _makeBloc(
          sendOtp: mockSendOtp,
          verifyOtp: mockVerifyOtp,
          login: mockLogin,
          register: mockRegister,
          checkAuth: mockCheckAuth,
          localDS: mockLocalDS,
        );
      },
      act: (bloc) => bloc.add(AuthCheckRequested()),
      expect: () => [isA<AuthLoading>(), isA<AuthAuthenticated>()],
      verify: (bloc) {
        final state = bloc.state as AuthAuthenticated;
        expect(state.user.phoneNumber, kPhone);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthShowSmsConsent] when token valid but no SMS consent',
      build: () {
        when(() => mockLocalDS.hasSeenOnboarding())
            .thenAnswer((_) async => true);
        when(() => mockCheckAuth()).thenAnswer((_) async => Right(kTestUser));
        when(() => mockLocalDS.hasSmsConsentCompleted())
            .thenAnswer((_) async => false);
        return _makeBloc(
          sendOtp: mockSendOtp,
          verifyOtp: mockVerifyOtp,
          login: mockLogin,
          register: mockRegister,
          checkAuth: mockCheckAuth,
          localDS: mockLocalDS,
        );
      },
      act: (bloc) => bloc.add(AuthCheckRequested()),
      expect: () => [isA<AuthLoading>(), isA<AuthShowSmsConsent>()],
    );
  });

  // ── AuthLoginRequested ───────────────────────────────────────────────────

  group('AuthLoginRequested', () {
    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthOtpPending] on successful OTP send',
      build: () {
        when(() => mockSendOtp(any()))
            .thenAnswer((_) async => const Right(null));
        return _makeBloc(
          sendOtp: mockSendOtp,
          verifyOtp: mockVerifyOtp,
          login: mockLogin,
          register: mockRegister,
          checkAuth: mockCheckAuth,
          localDS: mockLocalDS,
        );
      },
      act: (bloc) => bloc.add(const AuthLoginRequested(
        phoneNumber: kPhone,
        password: kPassword,
      )),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthOtpPending>(),
      ],
      verify: (bloc) {
        final state = bloc.state as AuthOtpPending;
        expect(state.phoneNumber, kPhone);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthError] when OTP send fails',
      build: () {
        when(() => mockSendOtp(any())).thenAnswer(
          (_) async => const Left(kServerFailure),
        );
        return _makeBloc(
          sendOtp: mockSendOtp,
          verifyOtp: mockVerifyOtp,
          login: mockLogin,
          register: mockRegister,
          checkAuth: mockCheckAuth,
          localDS: mockLocalDS,
        );
      },
      act: (bloc) => bloc.add(const AuthLoginRequested(
        phoneNumber: kPhone,
        password: kPassword,
      )),
      expect: () => [isA<AuthLoading>(), isA<AuthError>()],
    );
  });

  // ── AuthRegisterRequested ────────────────────────────────────────────────

  group('AuthRegisterRequested', () {
    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthOtpPending] on successful OTP send',
      build: () {
        when(() => mockSendOtp(any()))
            .thenAnswer((_) async => const Right(null));
        return _makeBloc(
          sendOtp: mockSendOtp,
          verifyOtp: mockVerifyOtp,
          login: mockLogin,
          register: mockRegister,
          checkAuth: mockCheckAuth,
          localDS: mockLocalDS,
        );
      },
      act: (bloc) => bloc.add(const AuthRegisterRequested(
        phoneNumber: kPhone,
        fullName: 'Test User',
        password: kPassword,
        ubudeheCategory: 'category_2',
        incomeFrequency: 'monthly',
      )),
      expect: () => [isA<AuthLoading>(), isA<AuthOtpPending>()],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthError] when OTP send fails',
      build: () {
        when(() => mockSendOtp(any())).thenAnswer(
          (_) async => const Left(kServerFailure),
        );
        return _makeBloc(
          sendOtp: mockSendOtp,
          verifyOtp: mockVerifyOtp,
          login: mockLogin,
          register: mockRegister,
          checkAuth: mockCheckAuth,
          localDS: mockLocalDS,
        );
      },
      act: (bloc) => bloc.add(const AuthRegisterRequested(
        phoneNumber: kPhone,
        fullName: 'Test User',
        password: kPassword,
        ubudeheCategory: 'category_2',
        incomeFrequency: 'monthly',
      )),
      expect: () => [isA<AuthLoading>(), isA<AuthError>()],
    );
  });

  // ── AuthOtpAutoDetected ──────────────────────────────────────────────────

  group('AuthOtpAutoDetected — no pending phone', () {
    blocTest<AuthBloc, AuthState>(
      'emits [AuthOtpError] when no pending phone',
      build: () => _makeBloc(
        sendOtp: mockSendOtp,
        verifyOtp: mockVerifyOtp,
        login: mockLogin,
        register: mockRegister,
        checkAuth: mockCheckAuth,
        localDS: mockLocalDS,
      ),
      act: (bloc) => bloc.add(const AuthOtpAutoDetected(otpCode: kOtpCode)),
      expect: () => [isA<AuthOtpError>()],
      verify: (bloc) {
        final err = bloc.state as AuthOtpError;
        expect(err.message.toLowerCase(), contains('session expired'));
      },
    );
  });

  group('AuthOtpAutoDetected — login path', () {
    AuthBloc buildBlocWithPendingLogin(
        MockVerifyOtpUseCase vOtp, MockLoginUseCase login) {
      when(() => mockSendOtp(any())).thenAnswer((_) async => const Right(null));
      return _makeBloc(
        sendOtp: mockSendOtp,
        verifyOtp: vOtp,
        login: login,
        register: mockRegister,
        checkAuth: mockCheckAuth,
        localDS: mockLocalDS,
      );
    }

    blocTest<AuthBloc, AuthState>(
      'emits [AuthOtpVerifying, AuthOtpError] when verify-OTP fails',
      build: () {
        when(() => mockVerifyOtp(any())).thenAnswer(
          (_) async => const Left(kServerFailure),
        );
        return buildBlocWithPendingLogin(mockVerifyOtp, mockLogin);
      },
      act: (bloc) async {
        // Prime the pending state via a login request
        bloc.add(
            const AuthLoginRequested(phoneNumber: kPhone, password: kPassword));
        await Future.delayed(Duration.zero);
        bloc.add(const AuthOtpAutoDetected(otpCode: kOtpCode));
      },
      skip: 2, // skip [Loading, OtpPending] from login request
      expect: () => [isA<AuthOtpVerifying>(), isA<AuthOtpError>()],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthOtpVerifying, AuthAuthenticated] on full success with consent',
      build: () {
        when(() => mockVerifyOtp(any())).thenAnswer(
          (_) async => const Right(kOtpToken),
        );
        when(() => mockLogin(any())).thenAnswer((_) async => Right(kTestUser));
        when(() => mockLocalDS.hasSmsConsentCompleted())
            .thenAnswer((_) async => true);
        return buildBlocWithPendingLogin(mockVerifyOtp, mockLogin);
      },
      act: (bloc) async {
        bloc.add(
            const AuthLoginRequested(phoneNumber: kPhone, password: kPassword));
        await Future.delayed(Duration.zero);
        bloc.add(const AuthOtpAutoDetected(otpCode: kOtpCode));
      },
      skip: 2,
      expect: () => [isA<AuthOtpVerifying>(), isA<AuthAuthenticated>()],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthOtpVerifying, AuthShowSmsConsent] when consent not yet given',
      build: () {
        when(() => mockVerifyOtp(any())).thenAnswer(
          (_) async => const Right(kOtpToken),
        );
        when(() => mockLogin(any())).thenAnswer((_) async => Right(kTestUser));
        when(() => mockLocalDS.hasSmsConsentCompleted())
            .thenAnswer((_) async => false);
        return buildBlocWithPendingLogin(mockVerifyOtp, mockLogin);
      },
      act: (bloc) async {
        bloc.add(
            const AuthLoginRequested(phoneNumber: kPhone, password: kPassword));
        await Future.delayed(Duration.zero);
        bloc.add(const AuthOtpAutoDetected(otpCode: kOtpCode));
      },
      skip: 2,
      expect: () => [isA<AuthOtpVerifying>(), isA<AuthShowSmsConsent>()],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthOtpVerifying, AuthOtpError] when login fails after OTP verified',
      build: () {
        when(() => mockVerifyOtp(any())).thenAnswer(
          (_) async => const Right(kOtpToken),
        );
        when(() => mockLogin(any())).thenAnswer(
          (_) async => const Left(kAuthFailure),
        );
        return buildBlocWithPendingLogin(mockVerifyOtp, mockLogin);
      },
      act: (bloc) async {
        bloc.add(
            const AuthLoginRequested(phoneNumber: kPhone, password: kPassword));
        await Future.delayed(Duration.zero);
        bloc.add(const AuthOtpAutoDetected(otpCode: kOtpCode));
      },
      skip: 2,
      expect: () => [isA<AuthOtpVerifying>(), isA<AuthOtpError>()],
    );
  });

  group('AuthOtpAutoDetected — register path', () {
    AuthBloc buildBlocWithPendingRegister() {
      when(() => mockSendOtp(any())).thenAnswer((_) async => const Right(null));
      return _makeBloc(
        sendOtp: mockSendOtp,
        verifyOtp: mockVerifyOtp,
        login: mockLogin,
        register: mockRegister,
        checkAuth: mockCheckAuth,
        localDS: mockLocalDS,
      );
    }

    blocTest<AuthBloc, AuthState>(
      'emits [AuthOtpVerifying, AuthAuthenticated] on successful register + consent',
      build: () {
        when(() => mockVerifyOtp(any())).thenAnswer(
          (_) async => const Right(kOtpToken),
        );
        when(() => mockRegister(any()))
            .thenAnswer((_) async => Right(kTestUser));
        when(() => mockLocalDS.hasSmsConsentCompleted())
            .thenAnswer((_) async => true);
        return buildBlocWithPendingRegister();
      },
      act: (bloc) async {
        bloc.add(const AuthRegisterRequested(
          phoneNumber: kPhone,
          fullName: 'Test User',
          password: kPassword,
          ubudeheCategory: 'category_2',
          incomeFrequency: 'monthly',
        ));
        await Future.delayed(Duration.zero);
        bloc.add(const AuthOtpAutoDetected(otpCode: kOtpCode));
      },
      skip: 2,
      expect: () => [isA<AuthOtpVerifying>(), isA<AuthAuthenticated>()],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthOtpVerifying, AuthOtpError] when register fails',
      build: () {
        when(() => mockVerifyOtp(any())).thenAnswer(
          (_) async => const Right(kOtpToken),
        );
        when(() => mockRegister(any())).thenAnswer(
          (_) async => const Left(kServerFailure),
        );
        return buildBlocWithPendingRegister();
      },
      act: (bloc) async {
        bloc.add(const AuthRegisterRequested(
          phoneNumber: kPhone,
          fullName: 'Test User',
          password: kPassword,
          ubudeheCategory: 'category_2',
          incomeFrequency: 'monthly',
        ));
        await Future.delayed(Duration.zero);
        bloc.add(const AuthOtpAutoDetected(otpCode: kOtpCode));
      },
      skip: 2,
      expect: () => [isA<AuthOtpVerifying>(), isA<AuthOtpError>()],
    );
  });

  // ── AuthOtpResendRequested ───────────────────────────────────────────────

  group('AuthOtpResendRequested', () {
    blocTest<AuthBloc, AuthState>(
      'emits [AuthOtpError] when no pending phone (no prior login/register)',
      build: () => _makeBloc(
        sendOtp: mockSendOtp,
        verifyOtp: mockVerifyOtp,
        login: mockLogin,
        register: mockRegister,
        checkAuth: mockCheckAuth,
        localDS: mockLocalDS,
      ),
      act: (bloc) => bloc.add(AuthOtpResendRequested()),
      expect: () => [isA<AuthOtpError>()],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthOtpPending] when resend succeeds',
      build: () {
        when(() => mockSendOtp(any()))
            .thenAnswer((_) async => const Right(null));
        return _makeBloc(
          sendOtp: mockSendOtp,
          verifyOtp: mockVerifyOtp,
          login: mockLogin,
          register: mockRegister,
          checkAuth: mockCheckAuth,
          localDS: mockLocalDS,
        );
      },
      act: (bloc) async {
        // Set pending state via login
        bloc.add(
            const AuthLoginRequested(phoneNumber: kPhone, password: kPassword));
        await Future.delayed(Duration.zero);
        bloc.add(AuthOtpResendRequested());
      },
      skip: 2, // skip [Loading, OtpPending] from login
      expect: () => [isA<AuthLoading>(), isA<AuthOtpPending>()],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthOtpError] when resend fails',
      build: () {
        var callCount = 0;
        when(() => mockSendOtp(any())).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) return const Right(null); // login succeeds
          return const Left(kServerFailure); // resend fails
        });
        return _makeBloc(
          sendOtp: mockSendOtp,
          verifyOtp: mockVerifyOtp,
          login: mockLogin,
          register: mockRegister,
          checkAuth: mockCheckAuth,
          localDS: mockLocalDS,
        );
      },
      act: (bloc) async {
        bloc.add(
            const AuthLoginRequested(phoneNumber: kPhone, password: kPassword));
        await Future.delayed(Duration.zero);
        bloc.add(AuthOtpResendRequested());
      },
      skip: 2,
      expect: () => [isA<AuthLoading>(), isA<AuthOtpError>()],
    );
  });

  // ── AuthLogoutRequested ──────────────────────────────────────────────────

  group('AuthLogoutRequested', () {
    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthUnauthenticated] and clears local data',
      build: () {
        when(() => mockLocalDS.clearAll()).thenAnswer((_) async {});
        return _makeBloc(
          sendOtp: mockSendOtp,
          verifyOtp: mockVerifyOtp,
          login: mockLogin,
          register: mockRegister,
          checkAuth: mockCheckAuth,
          localDS: mockLocalDS,
        );
      },
      act: (bloc) => bloc.add(AuthLogoutRequested()),
      expect: () => [isA<AuthLoading>(), isA<AuthUnauthenticated>()],
      verify: (_) {
        verify(() => mockLocalDS.clearAll()).called(1);
      },
    );
  });
}
