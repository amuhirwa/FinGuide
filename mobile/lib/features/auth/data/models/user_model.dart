/*
 * User Model
 * ==========
 * Data layer user model with JSON serialization
 */

import '../../domain/entities/user.dart';

/// User data model
class UserModel extends User {
  const UserModel({
    required super.id,
    required super.phoneNumber,
    required super.fullName,
    required super.ubudeheCategory,
    required super.incomeFrequency,
    required super.isActive,
    required super.isVerified,
    required super.createdAt,
  });

  /// Create from JSON
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      phoneNumber: json['phone_number'] as String,
      fullName: json['full_name'] as String,
      ubudeheCategory: json['ubudehe_category'] as String,
      incomeFrequency: json['income_frequency'] as String,
      isActive: json['is_active'] as bool? ?? true,
      isVerified: json['is_verified'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone_number': phoneNumber,
      'full_name': fullName,
      'ubudehe_category': ubudeheCategory,
      'income_frequency': incomeFrequency,
      'is_active': isActive,
      'is_verified': isVerified,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Convert to entity
  User toEntity() {
    return User(
      id: id,
      phoneNumber: phoneNumber,
      fullName: fullName,
      ubudeheCategory: ubudeheCategory,
      incomeFrequency: incomeFrequency,
      isActive: isActive,
      isVerified: isVerified,
      createdAt: createdAt,
    );
  }
}
