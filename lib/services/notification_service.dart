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

  /// Called when the user taps a notification or one of its action buttons.
  /// The payload carries an app command, e.g. 'quick_add'.
  void Function(String payload)? onPayload;

  Future<void> init() async {
    if (_ready) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          onPayload?.call(payload);
        }
      },
    );

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
          actions: [
            AndroidNotificationAction(
              'quick_add',
              'Add expense',
              showsUserInterface: true,
            ),
          ],
        ),
        iOS: DarwinNotificationDetails(),
      );

  Future<void> showAlert(int id, String title, String body,
      {String payload = 'quick_add'}) async {
    if (!_ready) return;
    try {
      await _plugin.show(
          id: id,
          title: title,
          body: body,
          notificationDetails: _details,
          payload: payload);
    } catch (e) {
      debugPrint('notify failed: $e');
    }
  }

  /// Schedules (or replaces) the daily reminder at [hour]:00 local time.
  Future<void> scheduleDailySummary(int hour, String title, String body,
      {String payload = 'quick_add'}) async {
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
        payload: payload,
      );
    } catch (e) {
      debugPrint('schedule failed: $e');
    }
  }

  Future<void> cancelDailySummary() async {
    if (!_ready) return;
    await _plugin.cancel(id: _summaryId);
  }

  /// Details when the app was launched by tapping a notification.
  Future<NotificationAppLaunchDetails?> launchDetails() {
    if (!_ready) return Future.value(null);
    return _plugin.getNotificationAppLaunchDetails();
  }
}
