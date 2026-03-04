/*
 * Nudge Notification Service
 * ==========================
 * Displays local push notifications for AI-generated financial nudges.
 *
 * Uses flutter_local_notifications to show nudge cards when:
 *   - Income SMS is detected (trigger_type = "income")
 *   - Daily savings quota check fires
 *   - Weekly financial review runs
 */

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';

class NudgeNotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final Logger _log = Logger();

  static const String channelId = 'finguide_nudges';
  static const String channelName = 'FinGuide Smart Nudges';
  static const String channelDesc =
      'Personalized saving and investment reminders';

  /// Initialise the plugin. Must be called before [showNudge].
  Future<void> initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings);

    // Create Android notification channel
    const channel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDesc,
      importance: Importance.high,
      playSound: true,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _log.i('NudgeNotificationService initialised');
  }

  /// Show a nudge notification.
  ///
  /// [id] should be unique per nudge (use the backend recommendation id).
  /// [type] controls the icon color: "savings" | "investment" | "spending".
  Future<void> showNudge({
    required int id,
    required String title,
    required String body,
    String type = 'savings',
  }) async {
    final color = _colorForType(type);

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      color: color,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(body),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _plugin.show(id, title, body, details);
      _log.i('Nudge notification shown: [$type] $title');
    } catch (e) {
      _log.e('Failed to show nudge notification', error: e);
    }
  }

  /// Returns an accent color for each nudge type.
  Color? _colorForType(String type) {
    switch (type) {
      case 'investment':
        return const Color(0xFF10B981); // teal
      case 'spending':
        return const Color(0xFFEF4444); // red
      case 'savings':
      default:
        return const Color(0xFFFFB81C); // gold
    }
  }
}
