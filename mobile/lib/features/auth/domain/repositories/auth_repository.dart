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
  /// Send OTP via SMS to the given phone number
  Future<Either<Failure, void>> sendOtp({required String phoneNumber});

  /// Verify OTP code – returns short-lived otp_token on success
  Future<Either<Failure, String>> verifyOtp({
    required String phoneNumber,
    required String otpCode,
  });

  /// Register a new user (requires otp_token)
  Future<Either<Failure, User>> register({
    required String phoneNumber,
    required String fullName,
    required String password,
    required String ubudeheCategory,
    required String incomeFrequency,
    required String otpToken,
  });

  /// Login user with phone and password (requires otp_token)
  Future<Either<Failure, User>> login({
    required String phoneNumber,
    required String password,
    required String otpToken,
  });

  /// Logout current user
  Future<Either<Failure, void>> logout();

  /// Check if user is authenticated
  Future<Either<Failure, User>> checkAuth();

  /// Get cached user data
  Future<Either<Failure, User?>> getCachedUser();

  /// Update user profile
  Future<Either<Failure, User>> updateProfile(Map<String, dynamic> data);
}
