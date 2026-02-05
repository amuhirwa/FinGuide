part of 'auth_bloc.dart';

/// Base auth event
abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Check authentication status
class AuthCheckRequested extends AuthEvent {}

/// Login request
class AuthLoginRequested extends AuthEvent {
  final String phoneNumber;
  final String password;

  const AuthLoginRequested({required this.phoneNumber, required this.password});

  @override
  List<Object?> get props => [phoneNumber, password];
}

/// Registration request
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

/// Logout request
class AuthLogoutRequested extends AuthEvent {}
