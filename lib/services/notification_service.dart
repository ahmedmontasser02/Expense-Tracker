import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Thin wrapper around flutter_local_notifications: init, permissions,
/// immediate alerts and a repeating daily summary slot.
class NotificationService {
  NotificationService._();

  static final instance = NotificationService._();

  static const _channelId = 'finance_alerts';
  static const _channelName = 'Financial alerts';
  static const _summaryId = 1001;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(settings: settings);

    final android =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.requestNotificationsPermission();
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: 'Low balance, savings and budget warnings',
          importance: Importance.high,
        ),
      );
    }
    try {
      tzdata.initializeTimeZones();
      final local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));
    } catch (e) {
      debugPrint('timezone init failed: $e');
    }
    _ready = true;
  }

  NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );

  Future<void> showAlert(int id, String title, String body) async {
    if (!_ready) return;
    try {
      await _plugin.show(id: id, title: title, body: body, notificationDetails: _details);
    } catch (e) {
      debugPrint('notify failed: $e');
    }
  }

  /// Schedules (or replaces) the daily reminder at [hour]:00 local time.
  Future<void> scheduleDailySummary(int hour, String title, String body) async {
    if (!_ready) return;
    final now = tz.TZDateTime.now(tz.local);
    var when = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour);
    if (!when.isAfter(now)) {
      when = when.add(const Duration(days: 1));
    }
    try {
      await _plugin.zonedSchedule(
        id: _summaryId,
        title: title,
        body: body,
        scheduledDate: when,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('schedule failed: $e');
    }
  }

  Future<void> cancelDailySummary() async {
    if (!_ready) return;
    await _plugin.cancel(id: _summaryId);
  }
}
