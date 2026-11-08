import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../app_config.dart';
import '../models/event.dart';
import '../utils/yearless_date.dart';
import 'storage_service.dart';

/// Feeds Happaroo's Android home-screen widgets (Next up, Upcoming, Calendar).
///
/// The app hands over every event once: name, type, custom label, month, day and
/// year (0 when unknown). The widgets work out the next date and the countdown on
/// the phone each time they refresh, so they stay correct after midnight even if
/// the app is not opened.
class WidgetService {
  static const MethodChannel _channel = MethodChannel(kWidgetChannel);

  /// Compact JSON the native widgets read. Public for tests.
  static String encodeEvents(List<Event> events, {Map<String, String> customTypeNames = const {}}) {
    final rows = events.map((e) {
      final yearless = isYearlessDate(e.originalDate);
      return {
        'n': e.name,
        't': e.eventType == EventType.birthday ? 'b' : 'a',
        'l': customTypeNames[e.customEventTypeId] ?? '',
        'm': e.originalDate.month,
        'd': e.originalDate.day,
        'y': yearless ? 0 : e.originalDate.year,
      };
    }).toList();
    return jsonEncode(rows);
  }

  /// Sends the current events to the widgets and redraws them. Safe to call often.
  static Future<void> updateWidgetData() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final storage = StorageService();
      await storage.init();
      final names = {for (final t in storage.getAllCustomEventTypes()) t.id: t.name};
      final json = encodeEvents(storage.getAllEvents(), customTypeNames: names);
      await _channel.invokeMethod('setWidgetEvents', {'json': json});
      await _channel.invokeMethod('updateWidgets');
    } catch (e) {
      debugPrint('Could not update home-screen widgets: $e');
    }
  }

  /// Kept for existing callers; nothing to set up.
  static Future<void> initialize() async {}
}
