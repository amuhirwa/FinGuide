/*
 * Verify OTP Use Case
 * ===================
 * Business logic for verifying an SMS OTP and obtaining an otp_token
 */

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../repositories/auth_repository.dart';

/// Verify OTP use case – returns the short-lived otp_token on success
class VerifyOtpUseCase {
  final AuthRepository _repository;

  VerifyOtpUseCase(this._repository);

  /// Verify [params.otpCode] for [params.phoneNumber].
  ///
  /// Returns an [otp_token] string that must be passed to register/login.
  Future<Either<Failure, String>> call(VerifyOtpParams params) async {
    return _repository.verifyOtp(
      phoneNumber: params.phoneNumber,
      otpCode: params.otpCode,
    );
  }
}

/// Parameters for OTP verification
class VerifyOtpParams extends Equatable {
  final String phoneNumber;
  final String otpCode;

  const VerifyOtpParams({required this.phoneNumber, required this.otpCode});

  @override
  List<Object?> get props => [phoneNumber, otpCode];
}
