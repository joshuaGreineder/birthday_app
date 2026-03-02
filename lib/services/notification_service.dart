import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import '../models/event.dart';
import '../services/storage_service.dart';
import '../utils/event_calculator.dart';

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
  static const MethodChannel _notificationChannel = MethodChannel('com.example.birthday_app/notifications');
  static const MethodChannel _timezoneChannel = MethodChannel('com.example.birthday_app/timezone');

  Future<void> init() async {
    if (_initialized) return;
    
    // Skip initialization on web platform
    if (kIsWeb) {
      debugPrint('Notification service not supported on web platform');
      _initialized = true; // Mark as initialized to prevent retries
      return;
    }

    try {
      tz.initializeTimeZones();
      
      // Get the device's timezone name from the platform
      String timezoneName = 'UTC'; // Default fallback
      try {
        final result = await _timezoneChannel.invokeMethod<String>('getLocalTimezone');
        if (result != null) {
          timezoneName = result;
        }
      } catch (e) {
        debugPrint('⚠️ Could not get timezone from platform: $e');
        // Fallback: try to determine from offset
        final now = DateTime.now();
        final utcNow = now.toUtc();
        final offset = now.difference(utcNow);
        final offsetHours = offset.inHours;
        
        // Common timezone mappings based on offset
        if (offsetHours == -5) {
          timezoneName = 'America/New_York'; // EST/EDT
        } else if (offsetHours == -6) {
          timezoneName = 'America/Chicago'; // CST/CDT
        } else if (offsetHours == -7) {
          timezoneName = 'America/Denver'; // MST/MDT
        } else if (offsetHours == -8) {
          timezoneName = 'America/Los_Angeles'; // PST/PDT
        } else {
          timezoneName = 'UTC';
        }
        debugPrint('⚠️ Using offset-based timezone detection: $timezoneName (offset: $offsetHours hours)');
      }
      
      try {
        final location = tz.getLocation(timezoneName);
        tz.setLocalLocation(location);
        debugPrint('✓ Timezone set to: $timezoneName');
      } catch (e) {
        debugPrint('⚠️ Error setting timezone to $timezoneName: $e');
        // Fallback to UTC
        tz.setLocalLocation(tz.UTC);
      }

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Create notification channels explicitly
      await _createNotificationChannels();
      
      // Log timezone info for debugging
      debugPrint('Timezone info:');
      debugPrint('  Local timezone: ${tz.local.name}');
      debugPrint('  Current local time: ${tz.TZDateTime.now(tz.local)}');
      debugPrint('  Current UTC time: ${DateTime.now().toUtc()}');

      _initialized = true;
      debugPrint('Notification service initialized successfully - notifications will work even when app is closed');
    } catch (e) {
      debugPrint('Error initializing notification service: $e');
      // Mark as initialized to prevent retry loops, but service won't work
      _initialized = true;
    }
  }

  /// Create notification channels explicitly
  Future<void> _createNotificationChannels() async {
    if (kIsWeb) return;
    
    try {
      // Create event reminder channel
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
      
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(androidEventChannel);
        debugPrint('✓ Created notification channel: event_reminder');
        
        // Verify channels were created
        try {
          final channels = await androidPlugin.getNotificationChannels();
          if (channels != null) {
            debugPrint('📋 Total notification channels: ${channels.length}');
            for (var channel in channels) {
              debugPrint('  📋 Channel: ${channel.id}, Name: ${channel.name}, Importance: ${channel.importance}');
            }
          } else {
            debugPrint('⚠️ Could not get notification channels list (null)');
          }
        } catch (e) {
          debugPrint('⚠️ Could not list notification channels: $e');
        }
      } else {
        debugPrint('⚠️ Android notification plugin not available');
      }
      
      debugPrint('Notification channels created successfully');
    } catch (e) {
      debugPrint('Error creating notification channels: $e');
    }
  }

  Future<bool> requestPermissions() async {
    // Skip on web platform
    if (kIsWeb) {
      return false;
    }
    
    try {
      // Check if permission is already granted
      if (await Permission.notification.isGranted) {
        return true;
      }

      // Request permission
      final status = await Permission.notification.request();
      
      // If permanently denied, open app settings
      if (status.isPermanentlyDenied) {
        await openAppSettings();
        return false;
      }
      
      return status.isGranted;
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
      return false;
    }
  }
  
  /// Check if exact alarm permission is granted (required for Android 12+)
  Future<bool> canScheduleExactAlarms() async {
    if (kIsWeb) {
      return false;
    }
    
    try {
      final result = await _notificationChannel.invokeMethod<bool>('canScheduleExactAlarms');
      return result ?? false;
    } catch (e) {
      debugPrint('Error checking exact alarm permission: $e');
      // Assume true for older Android versions
      return true;
    }
  }
  
  /// Open exact alarm settings (Android 12+)
  Future<void> openExactAlarmSettings() async {
    if (kIsWeb) {
      return;
    }
    
    try {
      await _notificationChannel.invokeMethod('openExactAlarmSettings');
    } catch (e) {
      debugPrint('Error opening exact alarm settings: $e');
    }
  }
  
  /// Check if battery optimization is disabled
  Future<bool> isBatteryOptimizationDisabled() async {
    if (kIsWeb) {
      return false;
    }
    
    try {
      final result = await _notificationChannel.invokeMethod<bool>('isBatteryOptimizationDisabled');
      return result ?? false;
    } catch (e) {
      debugPrint('Error checking battery optimization: $e');
      // Assume false if we can't check
      return false;
    }
  }
  
  /// Request to disable battery optimization
  Future<void> requestDisableBatteryOptimization() async {
    if (kIsWeb) {
      return;
    }
    
    try {
      await _notificationChannel.invokeMethod('requestDisableBatteryOptimization');
    } catch (e) {
      debugPrint('Error requesting battery optimization disable: $e');
    }
  }
  
  Future<void> cancelAllNotifications() async {
    if (!_initialized) {
      debugPrint('Notification service not initialized, skipping cancel');
      return;
    }
    try {
      await _notifications.cancelAll();
    } catch (e) {
      debugPrint('Error canceling notifications: $e');
    }
  }

  Future<void> scheduleDailyNotifications() async {
    // Skip on web platform
    if (kIsWeb) {
      debugPrint('Notifications not supported on web platform');
      return;
    }
    
    if (!_initialized) {
      debugPrint('Notification service not initialized, cannot schedule notifications');
      return;
    }
    
    // Check if permissions are granted before scheduling
    final hasPermission = await Permission.notification.isGranted;
    if (!hasPermission) {
      debugPrint('Notification permission not granted, cannot schedule notifications');
      debugPrint('Please grant notification permission in app settings');
      return;
    }
    debugPrint('Notification permission: GRANTED');
    
    // Check exact alarm permission (required for Android 12+)
    final canScheduleExact = await canScheduleExactAlarms();
    if (!canScheduleExact) {
      debugPrint('⚠️ Exact alarm permission not granted - notifications may not work when app is closed');
      debugPrint('⚠️ Please enable "Schedule exact alarms" in app settings');
      // Don't return - still try to schedule, but warn the user
    } else {
      debugPrint('Exact alarm permission: GRANTED');
    }
    
    // Check battery optimization
    final batteryOptimizationDisabled = await isBatteryOptimizationDisabled();
    if (!batteryOptimizationDisabled) {
      debugPrint('⚠️ Battery optimization is ENABLED - notifications may not work when app is closed');
      debugPrint('⚠️ Please disable battery optimization for this app in system settings');
    } else {
      debugPrint('Battery optimization: DISABLED (good for notifications)');
    }

    // Get notification settings
    final storage = StorageService();
    
    // Ensure storage is initialized
    await storage.init();
    
    // Check if notifications are enabled
    final notificationsEnabled = storage.getNotificationsEnabled();
    if (!notificationsEnabled) {
      debugPrint('Notifications are disabled in settings');
      await _notifications.cancelAll();
      return;
    }
    debugPrint('Notifications enabled in settings: true');
    
    // Cancel all Flutter plugin notifications
    await _notifications.cancelAll();
    debugPrint('Cancelled all existing Flutter plugin notifications');
    
    // Cancel all native AlarmManager alarms
    try {
      await _notificationChannel.invokeMethod('cancelAllNotificationAlarms');
      debugPrint('Cancelled all existing native AlarmManager alarms');
    } catch (e) {
      debugPrint('Error cancelling native alarms: $e');
    }

    final notificationHour = storage.getNotificationHour();
    final notificationMinute = storage.getNotificationMinute();
    final notificationDays = storage.getNotificationDays();
    
    debugPrint('Notification settings - Hour: $notificationHour, Minute: $notificationMinute, Days: $notificationDays');
    
    // Schedule individual notifications for each event based on notification days
    await _scheduleEventNotifications(notificationHour, notificationMinute, notificationDays);
    
    // Log pending notifications for debugging
    try {
      final pending = await _notifications.pendingNotificationRequests();
      debugPrint('Total pending notifications after scheduling: ${pending.length}');
      for (var notif in pending) {
        debugPrint('  - ID: ${notif.id}, Title: ${notif.title}, Body: ${notif.body}');
      }
    } catch (e) {
      debugPrint('Error checking pending notifications: $e');
    }
  }
  
  Future<void> _scheduleEventNotifications(int hour, int minute, List<int> daysBefore) async {
    final storage = StorageService();
    
    // Ensure storage is initialized
    await storage.init();
    
    final events = storage.getAllEvents();
    debugPrint('Scheduling notifications for ${events.length} events');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    int notificationId = 100; // Start IDs at 100 to avoid conflicts with daily reminder (0)
    
    for (final event in events) {
      final nextOccurrence = EventCalculator.getNextOccurrence(event);
      final eventDate = DateTime(nextOccurrence.year, nextOccurrence.month, nextOccurrence.day);
      
      // Check if the event is today (for message formatting - message should refer to event date, not notification date)
      final eventIsToday = eventDate.isAtSameMomentAs(today);
      
      for (final days in daysBefore) {
        final notificationDate = eventDate.subtract(Duration(days: days));
        
        // Only schedule if the notification date is today or in the future
        if (notificationDate.isAfter(today) || notificationDate.isAtSameMomentAs(today)) {
          final scheduledTime = tz.TZDateTime(
            tz.local,
            notificationDate.year,
            notificationDate.month,
            notificationDate.day,
            hour,
            minute,
          );
          
          debugPrint('📅 Creating scheduled time for ${event.name}:');
          debugPrint('   Notification date: $notificationDate (days before: $days)');
          debugPrint('   Event date: $eventDate');
          debugPrint('   Hour: $hour, Minute: $minute');
          debugPrint('   Scheduled time (local): $scheduledTime');
          debugPrint('   Scheduled time (UTC): ${scheduledTime.toUtc()}');
          debugPrint('   Milliseconds since epoch: ${scheduledTime.millisecondsSinceEpoch}');
          
          // Check if the scheduled time is in the past
          final now = tz.TZDateTime.now(tz.local);
          debugPrint('   Current time (local): $now');
          debugPrint('   Current time (UTC): ${now.toUtc()}');
          
          if (scheduledTime.isBefore(now)) {
            debugPrint('Scheduled time is in the past for ${event.name}, skipping. Scheduled: $scheduledTime, Now: $now');
            continue;
          }
          
          // Use the event date to determine if it's "today", not the notification date
          // The message should refer to when the event is, not when the notification fires
          final message = _formatNotificationMessage(event, isToday: eventIsToday, daysBefore: days);
          
          try {
            // Use native AlarmManager instead of Flutter plugin (more reliable)
            final title = days == 0 ? 'Today: ${event.name}' : '${days == 1 ? "Tomorrow" : "In $days days"}: ${event.name}';
            final triggerTime = scheduledTime.millisecondsSinceEpoch;
            
            await _notificationChannel.invokeMethod('scheduleNotificationAlarm', {
              'notificationId': notificationId++,
              'title': title,
              'body': message,
              'channelId': 'event_reminder',
              'triggerTime': triggerTime,
            });
            
            final timeUntil = scheduledTime.difference(tz.TZDateTime.now(tz.local));
            final hoursUntil = timeUntil.inHours;
            final minutesUntil = timeUntil.inMinutes % 60;
            final daysUntil = timeUntil.inDays;
            
            String timeString;
            if (daysUntil > 0) {
              timeString = '$daysUntil day${daysUntil > 1 ? 's' : ''} ${hoursUntil % 24}h ${minutesUntil}m';
            } else if (hoursUntil > 0) {
              timeString = '${hoursUntil}h ${minutesUntil}m';
            } else {
              timeString = '${minutesUntil}m';
            }
            
            debugPrint('✓ Scheduled notification (via native AlarmManager) for "${event.name}" on ${scheduledTime.toString()} (in $timeString)');
            debugPrint('  → This uses Android AlarmManager directly - should be more reliable');
          } catch (e) {
            debugPrint('Error scheduling notification for ${event.name}: $e');
          }
        }
      }
    }
  }

  // This method is kept for backward compatibility but notifications are now scheduled individually
  Future<void> checkAndSendNotifications() async {
    // Reschedule all notifications to ensure they're up to date
    await scheduleDailyNotifications();
  }

  String _formatNotificationMessage(Event event, {required bool isToday, int daysBefore = 0}) {
    if (event.eventType == EventType.birthday) {
      final age = EventCalculator.getAge(event);
      final nextAge = age + 1;
      
      if (isToday) {
        // Special case: if born today (same year)
        final now = DateTime.now();
        final wasBornThisYear = now.year == event.originalDate.year;
        if (age == 0 && wasBornThisYear) {
          return "${event.name} was born today! 🎂";
        }
        return "${event.name}'s ${_ordinal(nextAge)} Birthday is today!";
      } else if (daysBefore == 1) {
        return "${event.name}'s ${_ordinal(nextAge)} Birthday is tomorrow!";
      } else {
        return "${event.name}'s ${_ordinal(nextAge)} Birthday is in $daysBefore days!";
      }
    } else {
      final years = EventCalculator.getYearsTogether(event);
      final nextMilestone = years + 1;
      final ordinal = _ordinal(nextMilestone);
      
      if (isToday) {
        return "${event.name}'s $ordinal Anniversary is today!";
      } else if (daysBefore == 1) {
        return "${event.name}'s $ordinal Anniversary is tomorrow!";
      } else {
        return "${event.name}'s $ordinal Anniversary is in $daysBefore days!";
      }
    }
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

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('🔔 NOTIFICATION TAPPED/RECEIVED: ID=${response.id}, Action=${response.actionId}, Payload=${response.payload}');
    debugPrint('🔔 Notification was successfully delivered and shown to user');
    // Handle notification tap if needed
    // You could navigate to a specific screen here
  }


  /// Get notification status for debugging
  Future<Map<String, dynamic>> getNotificationStatus() async {
    final status = <String, dynamic>{
      'initialized': _initialized,
      'permissionGranted': false,
      'exactAlarmPermission': false,
      'batteryOptimizationDisabled': false,
      'notificationsEnabled': false,
      'scheduledCount': 0,
      'pendingNotifications': <Map<String, dynamic>>[],
    };

    if (kIsWeb) {
      return status;
    }

    try {
      status['permissionGranted'] = await Permission.notification.isGranted;
      status['exactAlarmPermission'] = await canScheduleExactAlarms();
      status['batteryOptimizationDisabled'] = await isBatteryOptimizationDisabled();
      
      final storage = StorageService();
      await storage.init();
      status['notificationsEnabled'] = storage.getNotificationsEnabled();
      status['notificationHour'] = storage.getNotificationHour();
      status['notificationMinute'] = storage.getNotificationMinute();
      status['notificationDays'] = storage.getNotificationDays();
      
      // Try to get pending notifications count (if supported)
      try {
        final pendingNotifications = await _notifications.pendingNotificationRequests();
        status['scheduledCount'] = pendingNotifications.length;
        status['pendingNotifications'] = pendingNotifications.map((n) => {
          'id': n.id,
          'title': n.title,
          'body': n.body,
        }).toList();
      } catch (e) {
        debugPrint('Could not get pending notifications: $e');
      }
    } catch (e) {
      debugPrint('Error getting notification status: $e');
    }

    return status;
  }
  
}

