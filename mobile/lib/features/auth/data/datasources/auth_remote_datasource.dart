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
  /// Register a new user
  Future<AuthResponseModel> register({
    required String phoneNumber,
    required String fullName,
    required String password,
    required String ubudeheCategory,
    required String incomeFrequency,
  });

  /// Login user
  Future<AuthResponseModel> login({
    required String phoneNumber,
    required String password,
  });

  /// Get current user profile
  Future<UserModel> getCurrentUser();
}

/// Auth remote data source implementation
class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiClient _apiClient;

  AuthRemoteDataSourceImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  @override
  Future<AuthResponseModel> register({
    required String phoneNumber,
    required String fullName,
    required String password,
    required String ubudeheCategory,
    required String incomeFrequency,
  }) async {
    try {
      return await _apiClient.register(
        phoneNumber: phoneNumber,
        fullName: fullName,
        password: password,
        ubudeheCategory: ubudeheCategory,
        incomeFrequency: incomeFrequency,
      );
    } catch (e) {
      throw ServerException(message: _extractErrorMessage(e));
    }
  }

  @override
  Future<AuthResponseModel> login({
    required String phoneNumber,
    required String password,
  }) async {
    try {
      return await _apiClient.login(
        phoneNumber: phoneNumber,
        password: password,
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

  /// Extract error message from exception
  String _extractErrorMessage(dynamic error) {
    if (error.toString().contains('detail')) {
      // Try to extract detail from DioError response
      return 'Authentication failed';
    }
    return error.toString();
  }
}
