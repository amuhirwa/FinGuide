/*
 * Failure Classes
 * ===============
 * Domain layer failure types for error handling
 */

import 'package:equatable/equatable.dart';

/// Base failure class
abstract class Failure extends Equatable {
  final String message;
  final int? code;

  const Failure({required this.message, this.code});

  @override
  List<Object?> get props => [message, code];
}

/// Server-side failures
class ServerFailure extends Failure {
  const ServerFailure({super.message = 'Server error occurred', super.code});
}

/// Network connectivity failures
class NetworkFailure extends Failure {
  const NetworkFailure({super.message = 'No internet connection', super.code});
}

/// Authentication failures
class AuthFailure extends Failure {
  const AuthFailure({super.message = 'Authentication failed', super.code});
}

/// Validation failures
class ValidationFailure extends Failure {
  const ValidationFailure({super.message = 'Validation error', super.code});
}

/// Cache/storage failures
class CacheFailure extends Failure {
  const CacheFailure({super.message = 'Cache error occurred', super.code});
}

/// Unknown failures
class UnknownFailure extends Failure {
  const UnknownFailure({
    super.message = 'An unexpected error occurred',
    super.code,
  });
}
