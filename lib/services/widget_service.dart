import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/event.dart';
import '../utils/event_calculator.dart';
import 'storage_service.dart';

class WidgetService {
  /// Update widget data with upcoming events (stores in SharedPreferences for native widgets)
  /// Note: Widgets are only supported on Android/iOS, not web
  static Future<void> updateWidgetData() async {
    // Skip on web platform - widgets not supported
    if (kIsWeb) {
      debugPrint('Widgets not supported on web platform');
      return;
    }
    
    try {
      final storage = StorageService();
      
      // Ensure storage is initialized
      await storage.init();
      
      final events = storage.getAllEvents();
      debugPrint('WidgetService: Found ${events.length} total events');
      
      final upcomingEvents = EventCalculator.getUpcomingEvents(events);
      debugPrint('WidgetService: Found ${upcomingEvents.length} upcoming events');
      
      // Get next event (single widget)
      Event? nextEvent;
      if (upcomingEvents.isNotEmpty) {
        nextEvent = upcomingEvents.first;
        debugPrint('WidgetService: Next event is "${nextEvent.name}"');
      } else {
        debugPrint('WidgetService: No upcoming events found');
      }
      
      // Get next 3 events (multi widget)
      final nextThreeEvents = upcomingEvents.take(3).toList();
      
      // Use a separate SharedPreferences file that widgets can access
      // Create widget_prefs SharedPreferences using method channel
      try {
        const platform = MethodChannel('com.example.birthday_app/widget');
        
        if (nextEvent != null) {
          final daysUntil = EventCalculator.getDaysUntil(nextEvent);
          final ageText = EventCalculator.getAgeText(nextEvent);
          final dateText = '${nextEvent.originalDate.month}/${nextEvent.originalDate.day}';
          
          debugPrint('WidgetService: Writing event data - Name: ${nextEvent.name}, Days: $daysUntil, Date: $dateText');
          
          // Write widget data using method channel
          await platform.invokeMethod('setWidgetData', {
            'hasNextEvent': true,
            'nextEventName': nextEvent.name,
            'nextEventAgeText': ageText,
            'nextEventDaysUntil': daysUntil,
            'nextEventDate': dateText,
            'eventCount': nextThreeEvents.length,
            'events': nextThreeEvents.asMap().entries.map((entry) {
              final i = entry.key;
              final event = entry.value;
              final eventDays = EventCalculator.getDaysUntil(event);
              final eventAgeText = EventCalculator.getAgeText(event);
              final eventDateText = '${event.originalDate.month}/${event.originalDate.day}';
              return {
                'index': i,
                'name': event.name,
                'ageText': eventAgeText,
                'daysUntil': eventDays,
                'date': eventDateText,
              };
            }).toList(),
          });
        } else {
          await platform.invokeMethod('setWidgetData', {
            'hasNextEvent': false,
            'nextEventName': 'No upcoming events',
            'nextEventAgeText': 'Add events to see them here',
            'nextEventDaysUntil': 0,
            'nextEventDate': '',
            'eventCount': 0,
            'events': <Map<String, dynamic>>[],
          });
        }
        
        // Trigger widget update
        await platform.invokeMethod('updateWidgets');
        debugPrint('Widgets updated successfully via method channel');
      } catch (e) {
        debugPrint('Error updating widget data via method channel: $e');
        // Fallback to SharedPreferences if method channel fails
        final prefs = await SharedPreferences.getInstance();
        if (nextEvent != null) {
          final daysUntil = EventCalculator.getDaysUntil(nextEvent);
          final ageText = EventCalculator.getAgeText(nextEvent);
          final dateText = '${nextEvent.originalDate.month}/${nextEvent.originalDate.day}';
          
          await prefs.setBool('hasNextEvent', true);
          await prefs.setString('nextEventName', nextEvent.name);
          await prefs.setString('nextEventAgeText', ageText);
          await prefs.setInt('nextEventDaysUntil', daysUntil);
          await prefs.setString('nextEventDate', dateText);
          await prefs.setInt('eventCount', nextThreeEvents.length);
          
          for (int i = 0; i < 3 && i < nextThreeEvents.length; i++) {
            final event = nextThreeEvents[i];
            final eventDays = EventCalculator.getDaysUntil(event);
            final eventAgeText = EventCalculator.getAgeText(event);
            final eventDateText = '${event.originalDate.month}/${event.originalDate.day}';
            
            await prefs.setString('event${i}_name', event.name);
            await prefs.setString('event${i}_ageText', eventAgeText);
            await prefs.setInt('event${i}_daysUntil', eventDays);
            await prefs.setString('event${i}_date', eventDateText);
          }
        } else {
          await prefs.setBool('hasNextEvent', false);
          await prefs.setString('nextEventName', 'No upcoming events');
          await prefs.setString('nextEventAgeText', 'Add events to see them here');
          await prefs.setInt('eventCount', 0);
        }
      }
    } catch (e) {
      debugPrint('Error updating widget data: $e');
    }
  }
  
  /// Initialize widget service (no-op for SharedPreferences approach)
  static Future<void> initialize() async {
    // SharedPreferences doesn't need initialization
  }
}

