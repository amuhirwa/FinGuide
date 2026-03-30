part of 'auth_bloc.dart';

/// Base auth event
abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Check authentication status
class AuthCheckRequested extends AuthEvent {}

/// Login request – triggers OTP send before completing login
class AuthLoginRequested extends AuthEvent {
  final String phoneNumber;
  final String password;

  const AuthLoginRequested({required this.phoneNumber, required this.password});

  @override
  List<Object?> get props => [phoneNumber, password];
}

/// Registration request – triggers OTP send before completing registration
class AuthRegisterRequested extends AuthEvent {
  final String phoneNumber;
  final String fullName;
  final String password;
  final String ubudeheCategory;
  final String incomeFrequency;

  const AuthRegisterRequested({
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

/// Dispatched by the OTP page when the SMS OTP is auto-read from telephony
class AuthOtpAutoDetected extends AuthEvent {
  final String otpCode;

  const AuthOtpAutoDetected({required this.otpCode});

  @override
  List<Object?> get props => [otpCode];
}

/// Dispatched from the OTP page when the user taps 'Resend OTP'
class AuthOtpResendRequested extends AuthEvent {}

/// Logout request
class AuthLogoutRequested extends AuthEvent {}

/// Permanently delete the current user's account and all data
class AuthDeleteAccountRequested extends AuthEvent {}

/// Update profile fields (fullName, ubudeheCategory, incomeFrequency)
class AuthProfileUpdateRequested extends AuthEvent {
  final Map<String, dynamic> data;

  const AuthProfileUpdateRequested(this.data);

  @override
  List<Object?> get props => [data];
}
