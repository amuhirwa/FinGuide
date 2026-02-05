/*
 * Auth Repository Implementation
 * ==============================
 * Data layer implementation of auth repository
 */

import 'package:dartz/dartz.dart';

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

  AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required AuthLocalDataSource localDataSource,
  }) : _remoteDataSource = remoteDataSource,
       _localDataSource = localDataSource;

  @override
  Future<Either<Failure, User>> register({
    required String phoneNumber,
    required String fullName,
    required String password,
    required String ubudeheCategory,
    required String incomeFrequency,
  }) async {
    try {
      final response = await _remoteDataSource.register(
        phoneNumber: phoneNumber,
        fullName: fullName,
        password: password,
        ubudeheCategory: ubudeheCategory,
        incomeFrequency: incomeFrequency,
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
  }) async {
    try {
      final response = await _remoteDataSource.login(
        phoneNumber: phoneNumber,
        password: password,
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
}
