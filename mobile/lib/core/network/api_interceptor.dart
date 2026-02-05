/*
 * API Interceptor
 * ===============
 * Handles authentication token injection and error handling
 */

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/storage_keys.dart';

/// Interceptor for adding auth headers and handling errors
class ApiInterceptor extends Interceptor {
  final FlutterSecureStorage _secureStorage;

  ApiInterceptor(this._secureStorage);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Add auth token if available
    final token = await _secureStorage.read(key: StorageKeys.accessToken);

    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Handle specific error codes
    switch (err.response?.statusCode) {
      case 401:
        // Token expired or invalid - could trigger logout
        break;
      case 403:
        // Forbidden
        break;
      case 404:
        // Not found
        break;
      case 500:
        // Server error
        break;
    }

    handler.next(err);
  }
}
