/*
 * User Entity
 * ===========
 * Domain layer user entity
 */

import 'package:equatable/equatable.dart';

/// User domain entity
class User extends Equatable {
  final int id;
  final String phoneNumber;
  final String fullName;
  final String ubudeheCategory;
  final String incomeFrequency;
  final bool isActive;
  final bool isVerified;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.phoneNumber,
    required this.fullName,
    required this.ubudeheCategory,
    required this.incomeFrequency,
    required this.isActive,
    required this.isVerified,
    required this.createdAt,
  });

  /// Get display name for Ubudehe category
  String get ubudeheCategoryDisplay {
    switch (ubudeheCategory) {
      case 'category_1':
        return 'Category 1';
      case 'category_2':
        return 'Category 2';
      case 'category_3':
        return 'Category 3';
      case 'category_4':
        return 'Category 4';
      default:
        return ubudeheCategory;
    }
  }

  /// Get display name for income frequency
  String get incomeFrequencyDisplay {
    switch (incomeFrequency) {
      case 'daily':
        return 'Daily';
      case 'weekly':
        return 'Weekly';
      case 'bi_weekly':
        return 'Bi-weekly';
      case 'monthly':
        return 'Monthly';
      case 'irregular':
        return 'Irregular';
      case 'seasonal':
        return 'Seasonal';
      default:
        return incomeFrequency;
    }
  }

  @override
  List<Object?> get props => [
    id,
    phoneNumber,
    fullName,
    ubudeheCategory,
    incomeFrequency,
    isActive,
    isVerified,
    createdAt,
  ];
}
