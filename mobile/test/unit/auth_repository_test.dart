/// Unit tests for AuthRepositoryImpl.
///
/// Verifies every method's success path, failure paths (ServerException,
/// CacheException, AuthFailure), and side-effects (saveToken, saveUser).
library;

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:finguide/core/error/exceptions.dart';
import 'package:finguide/core/error/failures.dart';
import 'package:finguide/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:finguide/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:finguide/features/auth/data/models/auth_response_model.dart';
import 'package:finguide/features/auth/data/models/user_model.dart';
import 'package:finguide/features/auth/data/repositories/auth_repository_impl.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockAuthRemoteDataSource extends Mock implements AuthRemoteDataSource {}
class MockAuthLocalDataSource extends Mock implements AuthLocalDataSource {}

// ── Fixtures ─────────────────────────────────────────────────────────────────

const kPhone = '+250781234567';
const kPassword = 'Test@1234';
const kOtpCode = '654321';
const kOtpToken = 'fake.otp.token';
const kAccessToken = 'fake.jwt.access.token';

final kUserModel = UserModel(
  id: 1,
  phoneNumber: kPhone,
  fullName: 'Test User',
  ubudeheCategory: 'category_2',
  incomeFrequency: 'monthly',
  isActive: true,
  isVerified: true,
  createdAt: DateTime(2024, 1, 1),
);

final kAuthResponse = AuthResponseModel(
  accessToken: kAccessToken,
  tokenType: 'bearer',
  user: kUserModel,
);

void main() {
  late MockAuthRemoteDataSource mockRemote;
  late MockAuthLocalDataSource mockLocal;
  late AuthRepositoryImpl repo;

  setUp(() {
    mockRemote = MockAuthRemoteDataSource();
    mockLocal = MockAuthLocalDataSource();
    repo = AuthRepositoryImpl(
      remoteDataSource: mockRemote,
      localDataSource: mockLocal,
    );

    // Default stubs so we don't get null pointer errors in test setup
    when(() => mockLocal.saveToken(any())).thenAnswer((_) async {});
    when(() => mockLocal.saveUser(any())).thenAnswer((_) async {});
    when(() => mockLocal.clearAll()).thenAnswer((_) async {});
  });

  // ── sendOtp ──────────────────────────────────────────────────────────────

  group('sendOtp', () {
    test('returns Right(null) on success', () async {
      when(() => mockRemote.sendOtp(phoneNumber: any(named: 'phoneNumber')))
          .thenAnswer((_) async {});

      final result = await repo.sendOtp(phoneNumber: kPhone);

      expect(result, const Right(null));
    });

    test('returns Left(ServerFailure) on ServerException', () async {
      when(() => mockRemote.sendOtp(phoneNumber: any(named: 'phoneNumber')))
          .thenThrow(const ServerException(message: 'SMS failed'));

      final result = await repo.sendOtp(phoneNumber: kPhone);

      expect(result.isLeft(), true);
      final failure = result.fold((l) => l, (r) => null);
      expect(failure, isA<ServerFailure>());
      expect((failure as ServerFailure).message, 'SMS failed');
    });

    test('returns Left(UnknownFailure) on unexpected error', () async {
      when(() => mockRemote.sendOtp(phoneNumber: any(named: 'phoneNumber')))
          .thenThrow(Exception('Network error'));

      final result = await repo.sendOtp(phoneNumber: kPhone);

      expect(result.isLeft(), true);
      expect(result.fold((l) => l, (r) => null), isA<UnknownFailure>());
    });
  });

  // ── verifyOtp ────────────────────────────────────────────────────────────

  group('verifyOtp', () {
    test('returns Right(token) on success', () async {
      when(() => mockRemote.verifyOtp(
            phoneNumber: any(named: 'phoneNumber'),
            otpCode: any(named: 'otpCode'),
          )).thenAnswer((_) async => kOtpToken);

      final result = await repo.verifyOtp(phoneNumber: kPhone, otpCode: kOtpCode);

      expect(result, const Right(kOtpToken));
    });

    test('returns Left(ServerFailure) on ServerException', () async {
      when(() => mockRemote.verifyOtp(
            phoneNumber: any(named: 'phoneNumber'),
            otpCode: any(named: 'otpCode'),
          )).thenThrow(const ServerException(message: 'Invalid code'));

      final result = await repo.verifyOtp(phoneNumber: kPhone, otpCode: '000000');

      expect(result.isLeft(), true);
      expect(result.fold((l) => l, (r) => null), isA<ServerFailure>());
    });

    test('returns Left(UnknownFailure) on unexpected error', () async {
      when(() => mockRemote.verifyOtp(
            phoneNumber: any(named: 'phoneNumber'),
            otpCode: any(named: 'otpCode'),
          )).thenThrow(Exception('Timeout'));

      final result = await repo.verifyOtp(phoneNumber: kPhone, otpCode: kOtpCode);

      expect(result.isLeft(), true);
      expect(result.fold((l) => l, (r) => null), isA<UnknownFailure>());
    });
  });

  // ── register ─────────────────────────────────────────────────────────────

  group('register', () {
    void stubRemoteRegister() {
      when(() => mockRemote.register(
            phoneNumber: any(named: 'phoneNumber'),
            fullName: any(named: 'fullName'),
            password: any(named: 'password'),
            ubudeheCategory: any(named: 'ubudeheCategory'),
            incomeFrequency: any(named: 'incomeFrequency'),
            otpToken: any(named: 'otpToken'),
          )).thenAnswer((_) async => kAuthResponse);
    }

    Future<Either<Failure, dynamic>> callRegister() => repo.register(
          phoneNumber: kPhone,
          fullName: 'Test User',
          password: kPassword,
          ubudeheCategory: 'category_2',
          incomeFrequency: 'monthly',
          otpToken: kOtpToken,
        );

    test('saves token and user, returns Right(user) on success', () async {
      stubRemoteRegister();

      final result = await callRegister();

      expect(result.isRight(), true);
      expect(result.fold((_) => null, (u) => u)?.phoneNumber, kPhone);
      verify(() => mockLocal.saveToken(kAccessToken)).called(1);
      verify(() => mockLocal.saveUser(kUserModel)).called(1);
    });

    test('returns Left(ServerFailure) on ServerException', () async {
      when(() => mockRemote.register(
            phoneNumber: any(named: 'phoneNumber'),
            fullName: any(named: 'fullName'),
            password: any(named: 'password'),
            ubudeheCategory: any(named: 'ubudeheCategory'),
            incomeFrequency: any(named: 'incomeFrequency'),
            otpToken: any(named: 'otpToken'),
          )).thenThrow(const ServerException(message: 'Already registered'));

      final result = await callRegister();

      expect(result.isLeft(), true);
      expect(result.fold((l) => l, (_) => null), isA<ServerFailure>());
    });

    test('returns Left(CacheFailure) when saveToken throws CacheException', () async {
      stubRemoteRegister();
      when(() => mockLocal.saveToken(any()))
          .thenThrow(const CacheException(message: 'Storage full'));

      final result = await callRegister();

      expect(result.isLeft(), true);
      expect(result.fold((l) => l, (_) => null), isA<CacheFailure>());
    });
  });

  // ── login ────────────────────────────────────────────────────────────────

  group('login', () {
    void stubRemoteLogin() {
      when(() => mockRemote.login(
            phoneNumber: any(named: 'phoneNumber'),
            password: any(named: 'password'),
            otpToken: any(named: 'otpToken'),
          )).thenAnswer((_) async => kAuthResponse);
    }

    Future<Either<Failure, dynamic>> callLogin() => repo.login(
          phoneNumber: kPhone,
          password: kPassword,
          otpToken: kOtpToken,
        );

    test('returns Right(user) and saves credentials on success', () async {
      stubRemoteLogin();

      final result = await callLogin();

      expect(result.isRight(), true);
      verify(() => mockLocal.saveToken(kAccessToken)).called(1);
      verify(() => mockLocal.saveUser(kUserModel)).called(1);
    });

    test('returns Left(AuthFailure) on ServerException — not ServerFailure', () async {
      when(() => mockRemote.login(
            phoneNumber: any(named: 'phoneNumber'),
            password: any(named: 'password'),
            otpToken: any(named: 'otpToken'),
          )).thenThrow(const ServerException(message: 'Invalid credentials'));

      final result = await callLogin();

      expect(result.isLeft(), true);
      // login specifically maps ServerException → AuthFailure
      expect(result.fold((l) => l, (_) => null), isA<AuthFailure>());
    });

    test('returns Left(CacheFailure) when saveToken throws', () async {
      stubRemoteLogin();
      when(() => mockLocal.saveToken(any()))
          .thenThrow(const CacheException(message: 'Write failed'));

      final result = await callLogin();

      expect(result.isLeft(), true);
      expect(result.fold((l) => l, (_) => null), isA<CacheFailure>());
    });
  });

  // ── checkAuth ────────────────────────────────────────────────────────────

  group('checkAuth', () {
    test('returns Left(AuthFailure) when no token stored', () async {
      when(() => mockLocal.getToken()).thenAnswer((_) async => null);

      final result = await repo.checkAuth();

      expect(result.isLeft(), true);
      expect(result.fold((l) => l, (_) => null), isA<AuthFailure>());
    });

    test('returns Right(user) when token valid and API succeeds', () async {
      when(() => mockLocal.getToken()).thenAnswer((_) async => kAccessToken);
      when(() => mockRemote.getCurrentUser()).thenAnswer((_) async => kUserModel);

      final result = await repo.checkAuth();

      expect(result.isRight(), true);
      expect(result.fold((_) => null, (u) => u)?.phoneNumber, kPhone);
      verify(() => mockLocal.saveUser(kUserModel)).called(1);
    });

    test('returns Right(cachedUser) when API fails but cache exists', () async {
      when(() => mockLocal.getToken()).thenAnswer((_) async => kAccessToken);
      when(() => mockRemote.getCurrentUser())
          .thenThrow(const ServerException(message: 'Offline'));
      when(() => mockLocal.getCachedUser()).thenAnswer((_) async => kUserModel);

      final result = await repo.checkAuth();

      expect(result.isRight(), true);
      expect(result.fold((_) => null, (u) => u)?.id, 1);
    });

    test('returns Left(AuthFailure) when API fails and no cached user', () async {
      when(() => mockLocal.getToken()).thenAnswer((_) async => kAccessToken);
      when(() => mockRemote.getCurrentUser())
          .thenThrow(const ServerException(message: 'Offline'));
      when(() => mockLocal.getCachedUser()).thenAnswer((_) async => null);

      final result = await repo.checkAuth();

      expect(result.isLeft(), true);
      expect(result.fold((l) => l, (_) => null), isA<AuthFailure>());
    });
  });

  // ── logout ───────────────────────────────────────────────────────────────

  group('logout', () {
    test('returns Right(null) and calls clearAll', () async {
      when(() => mockLocal.clearAll()).thenAnswer((_) async {});

      final result = await repo.logout();

      expect(result, const Right(null));
      verify(() => mockLocal.clearAll()).called(1);
    });

    test('returns Left(CacheFailure) when clearAll throws CacheException', () async {
      when(() => mockLocal.clearAll())
          .thenThrow(const CacheException(message: 'Cannot clear storage'));

      final result = await repo.logout();

      expect(result.isLeft(), true);
      expect(result.fold((l) => l, (_) => null), isA<CacheFailure>());
    });
  });

  // ── getCachedUser ────────────────────────────────────────────────────────

  group('getCachedUser', () {
    test('returns Right(user) when cache hit', () async {
      when(() => mockLocal.getCachedUser()).thenAnswer((_) async => kUserModel);

      final result = await repo.getCachedUser();

      expect(result.isRight(), true);
      expect(result.fold((_) => null, (u) => u)?.fullName, 'Test User');
    });

    test('returns Right(null) when no cached user', () async {
      when(() => mockLocal.getCachedUser()).thenAnswer((_) async => null);

      final result = await repo.getCachedUser();

      expect(result.isRight(), true);
      expect(result.fold((_) => null, (u) => u), isNull);
    });

    test('returns Left(CacheFailure) on exception', () async {
      when(() => mockLocal.getCachedUser())
          .thenThrow(Exception('Corrupted storage'));

      final result = await repo.getCachedUser();

      expect(result.isLeft(), true);
      expect(result.fold((l) => l, (_) => null), isA<CacheFailure>());
    });
  });
}
