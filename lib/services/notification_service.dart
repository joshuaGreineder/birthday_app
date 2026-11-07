import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../app_config.dart';
import '../models/event.dart';
import '../utils/event_calculator.dart';
import 'storage_service.dart';

enum NotificationAccess { granted, denied, permanentlyDenied, unavailable }

class NotificationService {
  static NotificationService? _instance;
  factory NotificationService() {
    _instance ??= NotificationService._internal();
    return _instance!;
  }
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  Future<bool> _scheduleQueue = Future<bool>.value(false);
  static const MethodChannel _timezoneChannel = MethodChannel(kTimezoneChannel);

  Future<void> init() async {
    if (_initialized) return;

    if (kIsWeb) {
      debugPrint('Notification service not supported on web platform');
      _initialized = true;
      return;
    }

    try {
      _timezoneChannel.setMethodCallHandler((call) async {
        if (call.method == 'timezoneChanged') {
          final name = call.arguments is String ? call.arguments as String : null;
          await onTimezoneChanged(name);
        }
        return null;
      });

      await _applyTimezone(null);

      const androidSettings = AndroidInitializationSettings('@drawable/ic_stat_notification');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );
      await _createNotificationChannels();
      _initialized = true;
      debugPrint('Notification service initialized');
    } catch (e) {
      debugPrint('Error initializing notification service: $e');
      _initialized = true;
    }
  }

  Future<void> _createNotificationChannels() async {
    if (kIsWeb) return;
    try {
      const androidEventChannel = AndroidNotificationChannel(
        'event_reminder',
        'Event Reminders',
        description: 'Notifications for birthdays and anniversaries',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(androidEventChannel);
    } catch (e) {
      debugPrint('Error creating notification channels: $e');
    }
  }

  Future<void> _applyTimezone(String? timezoneName) async {
    tzdata.initializeTimeZones();
    var name = timezoneName;
    if (name == null || name.isEmpty) {
      try {
        name = await _timezoneChannel.invokeMethod<String>('getLocalTimezone');
      } catch (e) {
        debugPrint('Could not get timezone from platform: $e');
        name = _timezoneFromOffset();
      }
    }
    name ??= 'UTC';
    try {
      tz.setLocalLocation(tz.getLocation(name));
      debugPrint('Timezone set to: $name');
    } catch (e) {
      debugPrint('Error setting timezone to $name: $e');
      tz.setLocalLocation(tz.UTC);
    }
  }

  String _timezoneFromOffset() {
    return timezoneForOffsetHours(DateTime.now().timeZoneOffset.inHours);
  }

  String timezoneForOffsetHours(int offsetHours) {
    switch (offsetHours) {
      case -5:
        return 'America/New_York';
      case -6:
        return 'America/Chicago';
      case -7:
        return 'America/Denver';
      case -8:
        return 'America/Los_Angeles';
      default:
        return 'UTC';
    }
  }

  /// Recomputes local-day reminders after the device zone changes.
  Future<void> onTimezoneChanged([String? timezoneName]) async {
    await _applyTimezone(timezoneName);
    await scheduleDailyNotifications();
  }

  /// On resume, reschedule only when the zone id actually changed.
  Future<void> onAppResumed() async {
    if (kIsWeb || !_initialized) return;
    final previous = tz.local.name;
    await _applyTimezone(null);
    if (tz.local.name != previous) {
      await scheduleDailyNotifications();
    }
  }

  Future<NotificationAccess> notificationAccess() async {
    if (kIsWeb) return NotificationAccess.unavailable;
    try {
      final status = await Permission.notification.status;
      return _accessFromStatus(status);
    } catch (e) {
      debugPrint('Error reading notification permission: $e');
      return NotificationAccess.unavailable;
    }
  }

  /// Call this only after the in-app explanation. Does not open system settings.
  Future<NotificationAccess> requestNotificationAccess() async {
    if (kIsWeb) return NotificationAccess.unavailable;
    try {
      final current = await Permission.notification.status;
      if (current.isGranted) return NotificationAccess.granted;
      final status = await Permission.notification.request();
      return _accessFromStatus(status);
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
      return NotificationAccess.denied;
    }
  }

  NotificationAccess _accessFromStatus(PermissionStatus status) {
    if (status.isGranted) return NotificationAccess.granted;
    if (status.isPermanentlyDenied || status.isRestricted) {
      return NotificationAccess.permanentlyDenied;
    }
    return NotificationAccess.denied;
  }

  Future<void> cancelAllNotifications() async {
    if (!_initialized || kIsWeb) return;
    try {
      await _notifications.cancelAll();
    } catch (e) {
      debugPrint('Error canceling notifications: $e');
    }
  }

  Future<bool> scheduleDailyNotifications() {
    final run = _scheduleQueue.then((_) => _scheduleDailyNotifications());
    _scheduleQueue = run.catchError((Object e) {
      debugPrint('Error scheduling notifications: $e');
      return false;
    });
    return run;
  }

  Future<bool> _scheduleDailyNotifications() async {
    if (kIsWeb) return false;
    if (!_initialized) {
      debugPrint('Notification service not initialized, cannot schedule notifications');
      return false;
    }
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.macOS) {
      return false;
    }

    try {
      final access = await notificationAccess();
      if (access != NotificationAccess.granted) {
        debugPrint('Notification permission is not granted. Reminders were not scheduled.');
        return false;
      }

      final storage = StorageService();
      await storage.init();
      if (!storage.getNotificationsEnabled()) {
        await _notifications.cancelAll();
        return false;
      }

      await _notifications.cancelAll();
      await _scheduleEventNotifications(
        storage.getNotificationHour(),
        storage.getNotificationMinute(),
        storage.getNotificationDays(),
      );
      return true;
    } catch (e) {
      debugPrint('Error scheduling notifications: $e');
      return false;
    }
  }

  Future<void> _scheduleEventNotifications(int hour, int minute, List<int> daysBefore) async {
    final storage = StorageService();
    await storage.init();
    final events = storage.getAllEvents();
    final now = tz.TZDateTime.now(tz.local);
    final today = DateTime(now.year, now.month, now.day);
    var notificationId = 100;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'event_reminder',
        'Event Reminders',
        channelDescription: 'Notifications for birthdays and anniversaries',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@drawable/ic_stat_notification',
      ),
    );

    for (final event in events) {
      final nextOccurrence = EventCalculator.getNextOccurrence(event);
      final eventDate = DateTime(nextOccurrence.year, nextOccurrence.month, nextOccurrence.day);

      for (final days in daysBefore) {
        final notificationDate = eventDate.subtract(Duration(days: days));
        if (notificationDate.isBefore(today)) continue;

        final scheduledTime = tz.TZDateTime(
          tz.local,
          notificationDate.year,
          notificationDate.month,
          notificationDate.day,
          hour,
          minute,
        );
        if (!scheduledTime.isAfter(now)) continue;

        final title = days == 0
            ? 'Today: ${event.name}'
            : days == 1
                ? 'Tomorrow: ${event.name}'
                : 'In $days days: ${event.name}';
        final message = _formatNotificationMessage(event, daysBefore: days);
        final id = notificationId++;

        try {
          await _notifications.zonedSchedule(
            id,
            title,
            message,
            scheduledTime,
            details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
        } catch (e) {
          debugPrint('Error scheduling notification for ${event.name}: $e');
        }
      }
    }
  }

  String _formatNotificationMessage(Event event, {required int daysBefore}) {
    if (!EventCalculator.hasKnownYear(event)) {
      final kind = event.eventType == EventType.birthday ? 'birthday' : 'anniversary';
      if (daysBefore == 0) return "${event.name}'s $kind is today!";
      if (daysBefore == 1) return "${event.name}'s $kind is tomorrow!";
      return "${event.name}'s $kind is in $daysBefore days!";
    }
    if (event.eventType == EventType.birthday) {
      final age = EventCalculator.getAge(event);
      final nextAge = age + 1;
      if (daysBefore == 0) {
        final now = DateTime.now();
        final wasBornThisYear = now.year == event.originalDate.year;
        if (age == 0 && wasBornThisYear) {
          return "${event.name} was born today! 🎂";
        }
        return "${event.name}'s ${_ordinal(nextAge)} Birthday is today!";
      }
      if (daysBefore == 1) {
        return "${event.name}'s ${_ordinal(nextAge)} Birthday is tomorrow!";
      }
      return "${event.name}'s ${_ordinal(nextAge)} Birthday is in $daysBefore days!";
    }

    final years = EventCalculator.getYearsTogether(event);
    final nextMilestone = years + 1;
    final ordinal = _ordinal(nextMilestone);
    if (daysBefore == 0) {
      return "${event.name}'s $ordinal Anniversary is today!";
    }
    if (daysBefore == 1) {
      return "${event.name}'s $ordinal Anniversary is tomorrow!";
    }
    return "${event.name}'s $ordinal Anniversary is in $daysBefore days!";
  }

  String _ordinal(int number) {
    if (number % 100 >= 11 && number % 100 <= 13) {
      return '${number}th';
    }
    switch (number % 10) {
      case 1:
        return '${number}st';
      case 2:
        return '${number}nd';
      case 3:
        return '${number}rd';
      default:
        return '${number}th';
    }
  }

  String reminderMessage(Event event, {required int daysBefore}) {
    return _formatNotificationMessage(event, daysBefore: daysBefore);
  }

  NotificationAccess accessFor(PermissionStatus status) => _accessFromStatus(status);

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: id=${response.id}');
  }

  Future<Map<String, dynamic>> getNotificationStatus() async {
    final status = <String, dynamic>{
      'initialized': _initialized,
      'permissionGranted': false,
      'notificationsEnabled': false,
      'scheduledCount': 0,
      'pendingNotifications': <Map<String, dynamic>>[],
    };
    if (kIsWeb) return status;

    try {
      status['permissionGranted'] =
          await notificationAccess() == NotificationAccess.granted;
      final storage = StorageService();
      await storage.init();
      status['notificationsEnabled'] = storage.getNotificationsEnabled();
      status['notificationHour'] = storage.getNotificationHour();
      status['notificationMinute'] = storage.getNotificationMinute();
      status['notificationDays'] = storage.getNotificationDays();
      final pending = await _notifications.pendingNotificationRequests();
      status['scheduledCount'] = pending.length;
      status['pendingNotifications'] = pending
          .map((n) => {'id': n.id, 'title': n.title, 'body': n.body})
          .toList();
    } catch (e) {
      debugPrint('Error getting notification status: $e');
    }
    return status;
  }
}
