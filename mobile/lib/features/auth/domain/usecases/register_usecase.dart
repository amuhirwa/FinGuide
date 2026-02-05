/*
 * Register Use Case
 * =================
 * Business logic for user registration
 */

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

/// Register use case
class RegisterUseCase {
  final AuthRepository _repository;

  RegisterUseCase(this._repository);

  /// Execute registration with user data
  Future<Either<Failure, User>> call(RegisterParams params) async {
    return _repository.register(
      phoneNumber: params.phoneNumber,
      fullName: params.fullName,
      password: params.password,
      ubudeheCategory: params.ubudeheCategory,
      incomeFrequency: params.incomeFrequency,
    );
  }
}

/// Registration parameters
class RegisterParams extends Equatable {
  final String phoneNumber;
  final String fullName;
  final String password;
  final String ubudeheCategory;
  final String incomeFrequency;

  const RegisterParams({
    required this.phoneNumber,
    required this.fullName,
    required this.password,
    required this.ubudeheCategory,
    required this.incomeFrequency,
  });

  @override
  List<Object?> get props => [
    phoneNumber,
    fullName,
    password,
    ubudeheCategory,
    incomeFrequency,
  ];
}
