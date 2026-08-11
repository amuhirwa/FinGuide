/*
 * Auth Repository Implementation
 * ==============================
 * Data layer implementation of auth repository
 */

import 'package:dartz/dartz.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';

/// Auth repository implementation
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;
  final AuthLocalDataSource _localDataSource;
  final AppDatabase _database;
  final SharedPreferences _prefs;

  AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required AuthLocalDataSource localDataSource,
    required AppDatabase database,
    required SharedPreferences prefs,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource,
        _database = database,
        _prefs = prefs;

  @override
  Future<Either<Failure, void>> sendOtp({required String phoneNumber}) async {
    try {
      await _remoteDataSource.sendOtp(phoneNumber: phoneNumber);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> verifyOtp({
    required String phoneNumber,
    required String otpCode,
  }) async {
    try {
      final otpToken = await _remoteDataSource.verifyOtp(
        phoneNumber: phoneNumber,
        otpCode: otpCode,
      );
      return Right(otpToken);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, User>> register({
    required String phoneNumber,
    required String fullName,
    required String password,
    required String ubudeheCategory,
    required String incomeFrequency,
    required String otpToken,
  }) async {
    try {
      final response = await _remoteDataSource.register(
        phoneNumber: phoneNumber,
        fullName: fullName,
        password: password,
        ubudeheCategory: ubudeheCategory,
        incomeFrequency: incomeFrequency,
        otpToken: otpToken,
      );

      // Save token and user data locally
      await _localDataSource.saveToken(response.accessToken);
      await _localDataSource.saveUser(response.user);

      return Right(response.user.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, User>> login({
    required String phoneNumber,
    required String password,
    required String otpToken,
  }) async {
    try {
      final response = await _remoteDataSource.login(
        phoneNumber: phoneNumber,
        password: password,
        otpToken: otpToken,
      );

      // Save token and user data locally
      await _localDataSource.saveToken(response.accessToken);
      await _localDataSource.saveUser(response.user);

      return Right(response.user.toEntity());
    } on ServerException catch (e) {
      return Left(AuthFailure(message: e.message));
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      await _localDataSource.clearAll();

      // The Drift DB is device-scoped, not user-scoped. Without wiping it the
      // next account signing in on this device sees the previous account's
      // transactions.
      await _database.clearAllData();

      // Wiping the tables is only half the job: the flags that record "this
      // data has already been pulled in" have to go too. Leave them set and
      // nothing ever refills the tables, so every aggregate reads zero for
      // good. Clearing lastSmsSyncTimestamp is what does the real work —
      // the startup delta sync then re-reads the whole SMS inbox.
      await _prefs.remove(StorageKeys.dataMigrationDone);
      await _prefs.remove(StorageKeys.smsInitialImportDone);
      await _prefs.remove(StorageKeys.lastSmsSyncTimestamp);

      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, User>> checkAuth() async {
    try {
      // Check if token exists
      final token = await _localDataSource.getToken();

      if (token == null) {
        return const Left(AuthFailure(message: 'No token found'));
      }

      // Try to get user from API
      try {
        final user = await _remoteDataSource.getCurrentUser();
        await _localDataSource.saveUser(user);
        return Right(user.toEntity());
      } catch (e) {
        // If API fails, try cached user
        final cachedUser = await _localDataSource.getCachedUser();

        if (cachedUser != null) {
          return Right(cachedUser.toEntity());
        }

        return const Left(AuthFailure(message: 'Session expired'));
      }
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, User?>> getCachedUser() async {
    try {
      final user = await _localDataSource.getCachedUser();
      return Right(user?.toEntity());
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, User>> updateProfile(Map<String, dynamic> data) async {
    try {
      final updated = await _remoteDataSource.updateProfile(data);
      await _localDataSource.saveUser(updated);
      return Right(updated.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteAccount() async {
    try {
      await _remoteDataSource.deleteAccount();
      await _localDataSource.clearAll();
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }
}
