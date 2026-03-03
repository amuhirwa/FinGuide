/*
 * Theme Cubit
 * ===========
 * Manages the application theme mode (light / dark)
 * Persists the user's preference to SharedPreferences.
 */

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeCubit extends Cubit<ThemeMode> {
  static const _kDarkModeKey = 'dark_mode';

  ThemeCubit() : super(ThemeMode.light);

  /// Load persisted preference on startup.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_kDarkModeKey) ?? false;
    emit(isDark ? ThemeMode.dark : ThemeMode.light);
  }

  bool get isDark => state == ThemeMode.dark;

  /// Toggle between light and dark and persist.
  Future<void> toggle() async {
    final prefs = await SharedPreferences.getInstance();
    final nowDark = !isDark;
    await prefs.setBool(_kDarkModeKey, nowDark);
    emit(nowDark ? ThemeMode.dark : ThemeMode.light);
  }

  /// Explicitly set the theme.
  Future<void> setDark(bool dark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDarkModeKey, dark);
    emit(dark ? ThemeMode.dark : ThemeMode.light);
  }
}
