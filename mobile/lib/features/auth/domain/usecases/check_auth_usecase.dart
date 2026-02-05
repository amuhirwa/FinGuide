/*
 * Check Auth Use Case
 * ===================
 * Business logic for checking authentication status
 */

import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

/// Check authentication status use case
class CheckAuthUseCase {
  final AuthRepository _repository;

  CheckAuthUseCase(this._repository);

  /// Execute auth check
  Future<Either<Failure, User>> call() async {
    return _repository.checkAuth();
  }
}
