/*
 * Login Use Case
 * ==============
 * Business logic for user login
 */

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

/// Login use case
class LoginUseCase {
  final AuthRepository _repository;

  LoginUseCase(this._repository);

  /// Execute login with credentials
  Future<Either<Failure, User>> call(LoginParams params) async {
    return _repository.login(
      phoneNumber: params.phoneNumber,
      password: params.password,
      otpToken: params.otpToken,
    );
  }
}

/// Login parameters
class LoginParams extends Equatable {
  final String phoneNumber;
  final String password;
  final String otpToken;

  const LoginParams({
    required this.phoneNumber,
    required this.password,
    required this.otpToken,
  });

  @override
  List<Object?> get props => [phoneNumber, password, otpToken];
}
