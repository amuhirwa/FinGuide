/*
 * Auth Remote Data Source
 * =======================
 * Remote API operations for authentication
 */

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../models/auth_response_model.dart';
import '../models/user_model.dart';

/// Auth remote data source interface
abstract class AuthRemoteDataSource {
  /// Send OTP via Twilio SMS to the given phone number
  Future<void> sendOtp({required String phoneNumber});

  /// Verify OTP and receive a short-lived otp_token
  Future<String> verifyOtp({
    required String phoneNumber,
    required String otpCode,
  });

  /// Register a new user (requires otp_token)
  Future<AuthResponseModel> register({
    required String phoneNumber,
    required String fullName,
    required String password,
    required String ubudeheCategory,
    required String incomeFrequency,
    required String otpToken,
  });

  /// Login user (requires otp_token)
  Future<AuthResponseModel> login({
    required String phoneNumber,
    required String password,
    required String otpToken,
  });

  /// Get current user profile
  Future<UserModel> getCurrentUser();

  /// Update user profile
  Future<UserModel> updateProfile(Map<String, dynamic> data);

  /// Permanently delete the current user's account and all data
  Future<void> deleteAccount();
}

/// Auth remote data source implementation
class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiClient _apiClient;

  AuthRemoteDataSourceImpl({required ApiClient apiClient})
      : _apiClient = apiClient;

  @override
  Future<void> sendOtp({required String phoneNumber}) async {
    try {
      await _apiClient.sendOtp(phoneNumber: phoneNumber);
    } catch (e) {
      throw ServerException(message: _extractErrorMessage(e));
    }
  }

  @override
  Future<String> verifyOtp({
    required String phoneNumber,
    required String otpCode,
  }) async {
    try {
      return await _apiClient.verifyOtp(
        phoneNumber: phoneNumber,
        otpCode: otpCode,
      );
    } catch (e) {
      throw ServerException(message: _extractErrorMessage(e));
    }
  }

  @override
  Future<AuthResponseModel> register({
    required String phoneNumber,
    required String fullName,
    required String password,
    required String ubudeheCategory,
    required String incomeFrequency,
    required String otpToken,
  }) async {
    try {
      return await _apiClient.register(
        phoneNumber: phoneNumber,
        fullName: fullName,
        password: password,
        ubudeheCategory: ubudeheCategory,
        incomeFrequency: incomeFrequency,
        otpToken: otpToken,
      );
    } catch (e) {
      throw ServerException(message: _extractErrorMessage(e));
    }
  }

  @override
  Future<AuthResponseModel> login({
    required String phoneNumber,
    required String password,
    required String otpToken,
  }) async {
    try {
      return await _apiClient.login(
        phoneNumber: phoneNumber,
        password: password,
        otpToken: otpToken,
      );
    } catch (e) {
      throw ServerException(message: _extractErrorMessage(e));
    }
  }

  @override
  Future<UserModel> getCurrentUser() async {
    try {
      return await _apiClient.getCurrentUser();
    } catch (e) {
      throw ServerException(message: _extractErrorMessage(e));
    }
  }

  @override
  Future<UserModel> updateProfile(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.updateProfile(data);
      return UserModel.fromJson(response);
    } catch (e) {
      throw ServerException(message: _extractErrorMessage(e));
    }
  }

  @override
  Future<void> deleteAccount() async {
    try {
      await _apiClient.deleteAccount();
    } catch (e) {
      throw ServerException(message: _extractErrorMessage(e));
    }
  }

  /// Extract error message from exception
  String _extractErrorMessage(dynamic error) {
    if (error.toString().contains('detail')) {
      // Try to extract detail from DioError response
      return 'Authentication failed';
    }
    return error.toString();
  }
}
