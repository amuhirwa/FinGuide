/*
 * Send OTP Use Case
 * =================
 * Business logic for sending an SMS OTP to a phone number
 */

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../repositories/auth_repository.dart';

/// Send OTP use case
class SendOtpUseCase {
  final AuthRepository _repository;

  SendOtpUseCase(this._repository);

  /// Trigger an OTP SMS to [params.phoneNumber]
  Future<Either<Failure, void>> call(SendOtpParams params) async {
    return _repository.sendOtp(phoneNumber: params.phoneNumber);
  }
}

/// Parameters for sending an OTP
class SendOtpParams extends Equatable {
  final String phoneNumber;

  const SendOtpParams({required this.phoneNumber});

  @override
  List<Object?> get props => [phoneNumber];
}
