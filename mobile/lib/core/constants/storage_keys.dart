/*
 * Storage Keys
 * ============
 * Constants for secure storage and shared preferences keys
 */

/// Keys for persistent storage
class StorageKeys {
  StorageKeys._();

  // Secure Storage (sensitive data)
  static const String accessToken = 'access_token';
  static const String refreshToken = 'refresh_token';

  // Shared Preferences (non-sensitive data)
  static const String hasSeenOnboarding = 'has_seen_onboarding';
  static const String userId = 'user_id';
  static const String userName = 'user_name';
  static const String userPhone = 'user_phone';
  static const String ubudeheCategory = 'ubudehe_category';
  static const String incomeFrequency = 'income_frequency';
  static const String themeMode = 'theme_mode';
  static const String languageCode = 'language_code';

  // SMS Consent
  static const String smsConsentGiven = 'sms_consent_given';
  static const String smsInitialImportDone = 'sms_initial_import_done';
}
