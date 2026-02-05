/*
 * Auth Local Data Source
 * ======================
 * Local storage operations for authentication data
 */

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../../../core/error/exceptions.dart';
import '../models/user_model.dart';

/// Auth local data source interface
abstract class AuthLocalDataSource {
  /// Save access token
  Future<void> saveToken(String token);

  /// Get access token
  Future<String?> getToken();

  /// Delete access token
  Future<void> deleteToken();

  /// Save user data
  Future<void> saveUser(UserModel user);

  /// Get cached user
  Future<UserModel?> getCachedUser();

  /// Delete user data
  Future<void> deleteUser();

  /// Check if onboarding has been seen
  Future<bool> hasSeenOnboarding();

  /// Set onboarding as seen
  Future<void> setOnboardingSeen();

  /// Clear all auth data
  Future<void> clearAll();
}

/// Auth local data source implementation
class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final FlutterSecureStorage _secureStorage;
  final SharedPreferences _sharedPreferences;

  AuthLocalDataSourceImpl({
    required FlutterSecureStorage secureStorage,
    required SharedPreferences sharedPreferences,
  }) : _secureStorage = secureStorage,
       _sharedPreferences = sharedPreferences;

  @override
  Future<void> saveToken(String token) async {
    try {
      await _secureStorage.write(key: StorageKeys.accessToken, value: token);
    } catch (e) {
      throw const CacheException(message: 'Failed to save token');
    }
  }

  @override
  Future<String?> getToken() async {
    try {
      return await _secureStorage.read(key: StorageKeys.accessToken);
    } catch (e) {
      throw const CacheException(message: 'Failed to get token');
    }
  }

  @override
  Future<void> deleteToken() async {
    try {
      await _secureStorage.delete(key: StorageKeys.accessToken);
    } catch (e) {
      throw const CacheException(message: 'Failed to delete token');
    }
  }

  @override
  Future<void> saveUser(UserModel user) async {
    try {
      final userJson = jsonEncode(user.toJson());
      await _sharedPreferences.setString('cached_user', userJson);

      // Also save individual fields for quick access
      await _sharedPreferences.setInt(StorageKeys.userId, user.id);
      await _sharedPreferences.setString(StorageKeys.userName, user.fullName);
      await _sharedPreferences.setString(
        StorageKeys.userPhone,
        user.phoneNumber,
      );
      await _sharedPreferences.setString(
        StorageKeys.ubudeheCategory,
        user.ubudeheCategory,
      );
      await _sharedPreferences.setString(
        StorageKeys.incomeFrequency,
        user.incomeFrequency,
      );
    } catch (e) {
      throw const CacheException(message: 'Failed to save user');
    }
  }

  @override
  Future<UserModel?> getCachedUser() async {
    try {
      final userJson = _sharedPreferences.getString('cached_user');

      if (userJson == null) {
        return null;
      }

      return UserModel.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> deleteUser() async {
    try {
      await _sharedPreferences.remove('cached_user');
      await _sharedPreferences.remove(StorageKeys.userId);
      await _sharedPreferences.remove(StorageKeys.userName);
      await _sharedPreferences.remove(StorageKeys.userPhone);
      await _sharedPreferences.remove(StorageKeys.ubudeheCategory);
      await _sharedPreferences.remove(StorageKeys.incomeFrequency);
    } catch (e) {
      throw const CacheException(message: 'Failed to delete user');
    }
  }

  @override
  Future<bool> hasSeenOnboarding() async {
    return _sharedPreferences.getBool(StorageKeys.hasSeenOnboarding) ?? false;
  }

  @override
  Future<void> setOnboardingSeen() async {
    await _sharedPreferences.setBool(StorageKeys.hasSeenOnboarding, true);
  }

  @override
  Future<void> clearAll() async {
    await deleteToken();
    await deleteUser();
  }
}
