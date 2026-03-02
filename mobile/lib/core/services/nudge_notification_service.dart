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

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';

class NudgeNotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final Logger _log = Logger();

  static const String _channelId = 'finguide_nudges';
  static const String _channelName = 'FinGuide Smart Nudges';
  static const String _channelDesc =
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
      _channelId,
      _channelName,
      description: _channelDesc,
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
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
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
  dynamic _colorForType(String type) {
    switch (type) {
      case 'investment':
        return const Object(); // placeholder — use theme color in real impl
      case 'spending':
        return const Object();
      case 'savings':
      default:
        return const Object();
    }
  }
}
