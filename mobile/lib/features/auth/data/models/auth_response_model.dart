/*
 * Auth Response Model
 * ===================
 * Data model for authentication API responses
 */

import 'user_model.dart';

/// Authentication response model
class AuthResponseModel {
  final String accessToken;
  final String tokenType;
  final UserModel user;

  const AuthResponseModel({
    required this.accessToken,
    required this.tokenType,
    required this.user,
  });

  /// Create from JSON
  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    return AuthResponseModel(
      accessToken: json['access_token'] as String,
      tokenType: json['token_type'] as String,
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'token_type': tokenType,
      'user': user.toJson(),
    };
  }
}
