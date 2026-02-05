/*
 * Application Constants
 * =====================
 * Global constants used throughout the app
 */

/// API-related constants
class ApiConstants {
  ApiConstants._();

  static const int connectionTimeout = 30000;
  static const int receiveTimeout = 30000;
}

/// Validation constants
class ValidationConstants {
  ValidationConstants._();

  static const int minPasswordLength = 6;
  static const int maxNameLength = 100;
  static const int phoneNumberLength = 10;
}

/// Rwanda-specific constants
class RwandaConstants {
  RwandaConstants._();

  static const String countryCode = '+250';
  static const String currencyCode = 'RWF';
  static const String currencySymbol = 'FRw';

  /// Ubudehe categories with descriptions
  static const Map<String, String> ubudeheCategories = {
    'category_1': 'Category 1 - Extremely poor',
    'category_2': 'Category 2 - Poor',
    'category_3': 'Category 3 - Middle class',
    'category_4': 'Category 4 - Wealthy',
  };

  /// Income frequency options with descriptions
  static const Map<String, String> incomeFrequencies = {
    'daily': 'Daily wages',
    'weekly': 'Weekly payments',
    'bi_weekly': 'Every two weeks',
    'monthly': 'Monthly salary',
    'irregular': 'Irregular / Gig work',
    'seasonal': 'Seasonal income',
  };
}
