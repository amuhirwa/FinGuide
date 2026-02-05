/*
 * Auth Repository Interface
 * =========================
 * Domain layer repository contract
 */

import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/user.dart';

/// Authentication repository interface
abstract class AuthRepository {
  /// Register a new user
  Future<Either<Failure, User>> register({
    required String phoneNumber,
    required String fullName,
    required String password,
    required String ubudeheCategory,
    required String incomeFrequency,
  });

  /// Login user with phone and password
  Future<Either<Failure, User>> login({
    required String phoneNumber,
    required String password,
  });

  /// Logout current user
  Future<Either<Failure, void>> logout();

  /// Check if user is authenticated
  Future<Either<Failure, User>> checkAuth();

  /// Get cached user data
  Future<Either<Failure, User?>> getCachedUser();
}
