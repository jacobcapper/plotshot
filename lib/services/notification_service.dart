import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

abstract class NotificationService {
  Future<void> init();

  /// Asks for permission to post notifications. Returns whether granted.
  Future<bool> requestPermission();

  /// Replaces any scheduled reminders with one at each of [times].
  Future<void> scheduleReminders(
    List<DateTime> times, {
    required String title,
    required String body,
  });

  Future<void> cancelReminders();
}

class LocalNotificationService implements NotificationService {
  static const _firstId = 1;
  static const _maxReminders = 8;
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'jab_reminders',
      'Jab reminders',
      channelDescription: 'Reminds you when your next jab is due',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  @override
  Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Fall back to UTC; reminders may then be off by the UTC offset.
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_launcher_foreground'),
      ),
    );
    _ready = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool> requestPermission() async =>
      await _android?.requestNotificationsPermission() ?? false;

  @override
  Future<void> scheduleReminders(
    List<DateTime> times, {
    required String title,
    required String body,
  }) async {
    if (!_ready) return;
    await cancelReminders();
    for (var i = 0; i < times.length && i < _maxReminders; i++) {
      await _plugin.zonedSchedule(
        id: _firstId + i,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(times[i], tz.local),
        notificationDetails: _details,
        // Inexact avoids needing the exact-alarm permission; a few minutes of
        // slack is fine for a weekly reminder.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  @override
  Future<void> cancelReminders() async {
    if (!_ready) return;
    for (var i = 0; i < _maxReminders; i++) {
      await _plugin.cancel(id: _firstId + i);
    }
  }
}

class NoopNotificationService implements NotificationService {
  @override
  Future<void> init() async {}
  @override
  Future<bool> requestPermission() async => false;
  @override
  Future<void> scheduleReminders(
    List<DateTime> times, {
    required String title,
    required String body,
  }) async {}
  @override
  Future<void> cancelReminders() async {}
}
