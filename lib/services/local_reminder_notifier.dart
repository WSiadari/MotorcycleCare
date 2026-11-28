import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/models.dart';
import 'reminder_notifier.dart';

/// Shows maintenance reminders as Android notifications (flutter_local_notifications).
/// Needs android.permission.POST_NOTIFICATIONS (Android 13+), asked the first time.
class LocalReminderNotifier implements ReminderNotifier {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool? _ready;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'maintenance_reminders',
      'Maintenance reminders',
      channelDescription: 'Components that are due soon or overdue',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  Future<bool> _init() async {
    if (_ready != null) return _ready!;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      );
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      _ready = await android?.requestNotificationsPermission() ?? true;
    } catch (e) {
      debugPrint('Notifications are not available: $e');
      _ready = false;
    }
    return _ready!;
  }

  @override
  Future<void> show(Reminder reminder, {required String title}) async {
    if (!await _init()) return;
    final id = int.tryParse(reminder.reminderId.replaceAll(RegExp(r'\D'), '')) ?? reminder.hashCode;
    await _plugin.show(id: id & 0x7fffffff, title: title, body: reminder.message, notificationDetails: _details);
  }
}
