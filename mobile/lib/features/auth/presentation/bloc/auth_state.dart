part of 'auth_bloc.dart';

/// Base auth state
abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class AuthInitial extends AuthState {}

/// Loading state (generic)
class AuthLoading extends AuthState {}

/// Show onboarding state (first time user)
class AuthShowOnboarding extends AuthState {}

/// Show SMS consent flow (after first login/register)
class AuthShowSmsConsent extends AuthState {}

/// OTP has been sent – waiting for the user's device to auto-read the message.
///
/// The OTP page should navigate to when this state is emitted and start
/// listening for the incoming SMS via telephony.
class AuthOtpPending extends AuthState {
  /// The phone number the OTP was sent to (displayed in the UI)
  final String phoneNumber;

  const AuthOtpPending({required this.phoneNumber});

  @override
  List<Object?> get props => [phoneNumber];
}

/// Verifying the OTP and completing the original auth action (login/register)
class AuthOtpVerifying extends AuthState {}

/// OTP verification (or the subsequent auth call) failed
class AuthOtpError extends AuthState {
  final String message;

  const AuthOtpError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Authenticated state
class AuthAuthenticated extends AuthState {
  final User user;

  const AuthAuthenticated(this.user);

  @override
  List<Object?> get props => [user];
}

/// Unauthenticated state
class AuthUnauthenticated extends AuthState {}

/// Generic error state
class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Profile update in progress
class AuthProfileUpdating extends AuthState {}

/// Profile update succeeded – carries the refreshed user
class AuthProfileUpdated extends AuthState {
  final User user;

  const AuthProfileUpdated(this.user);

  @override
  List<Object?> get props => [user];
}

/// Account deletion in progress
class AuthAccountDeleting extends AuthState {}

/// Account deletion failed
class AuthAccountDeleteError extends AuthState {
  final String message;

  const AuthAccountDeleteError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Profile update failed
class AuthProfileUpdateError extends AuthState {
  final String message;

  const AuthProfileUpdateError(this.message);

  @override
  List<Object?> get props => [message];
}
