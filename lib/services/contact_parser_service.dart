import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/event.dart' as event_model;

class ContactParserService {
  static ContactParserService? _instance;

  factory ContactParserService() {
    _instance ??= ContactParserService._internal();
    return _instance!;
  }

  ContactParserService._internal();

  Future<List<PotentialBirthday>> parseContacts() async {
    if (kIsWeb) {
      return []; // Contacts not available on web
    }

    try {
      // Check and request contacts permission
      final permissionStatus = await Permission.contacts.status;
      debugPrint('Contacts permission status: $permissionStatus');
      
      if (!permissionStatus.isGranted) {
        final permission = await Permission.contacts.request();
        debugPrint('Contacts permission request result: $permission');
        if (!permission.isGranted) {
          debugPrint('Contacts permission denied');
          return [];
        }
      }

      // Request read permission specifically for flutter_contacts
      if (!await FlutterContacts.requestPermission(readonly: true)) {
        debugPrint('FlutterContacts permission denied');
        return [];
      }

      // Get all contacts with properties (including events/birthdays)
      debugPrint('Fetching contacts with properties...');
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withThumbnail: false,
      );
      debugPrint('Found ${contacts.length} contacts');
      
      // Count contacts with events
      int contactsWithEvents = 0;
      int totalEvents = 0;
      for (final contact in contacts) {
        if (contact.events.isNotEmpty) {
          contactsWithEvents++;
          totalEvents += contact.events.length;
        }
      }
      debugPrint('Contacts with events: $contactsWithEvents, Total events: $totalEvents');

      final potentialBirthdays = <PotentialBirthday>[];

      for (final contact in contacts) {
        DateTime? birthdayDate;
        
        // Check events for birthday
        // In flutter_contacts, birthdays are stored in the events list
        try {
          debugPrint('Checking contact: ${contact.displayName}, events count: ${contact.events.length}');
          
          // Debug: Print all event labels to see what we have
          if (contact.events.isNotEmpty) {
            debugPrint('Contact ${contact.displayName} has ${contact.events.length} events');
            for (var i = 0; i < contact.events.length; i++) {
              final event = contact.events[i];
              debugPrint('  Event $i: label=${event.label}, toString=${event.toString()}');
            }
          }
          
          for (final event in contact.events) {
            // Check event label - can be EventLabel enum or string
            final label = event.label;
            
            // Check if this is a birthday event
            bool isBirthday = false;
            try {
              // Try EventLabel enum comparison
              if (label == EventLabel.birthday) {
                isBirthday = true;
                debugPrint('Matched birthday via EventLabel enum');
              } else {
                // Fallback: check string representation
                final labelStr = label.toString().toLowerCase();
                isBirthday = labelStr.contains('birthday') || labelStr.contains('birth');
                if (isBirthday) {
                  debugPrint('Matched birthday via string: $labelStr');
                }
              }
            } catch (e) {
              // If EventLabel comparison fails, use string check
              final labelStr = label.toString().toLowerCase();
              isBirthday = labelStr.contains('birthday') || labelStr.contains('birth');
              if (isBirthday) {
                debugPrint('Matched birthday via string (after error): $labelStr');
              }
            }
            
            if (isBirthday) {
              debugPrint('Processing birthday event for ${contact.displayName}');
              
              // In flutter_contacts, Event has a date property (DateTime?)
              // Try multiple methods to access it, as different Android versions/devices may store it differently
              DateTime? eventDate;
              
              // Method 1: Try accessing date property directly via dynamic
              try {
                final dynamicEvent = event as dynamic;
                final dateValue = dynamicEvent.date;
                debugPrint('  event.date (raw): $dateValue, type: ${dateValue?.runtimeType}');
                
                if (dateValue != null) {
                  if (dateValue is DateTime) {
                    eventDate = dateValue;
                    debugPrint('Found birthday date (DateTime): $eventDate');
                  } else if (dateValue is String) {
                    // Try parsing if it's a string
                    try {
                      eventDate = DateTime.parse(dateValue);
                      debugPrint('Found birthday date (parsed from string): $eventDate');
                    } catch (e) {
                      debugPrint('Failed to parse date string: $e');
                    }
                  } else {
                    debugPrint('Date value is not DateTime or String: ${dateValue.runtimeType}');
                  }
                }
              } catch (e) {
                debugPrint('Error accessing event.date: $e');
              }
              
              // Method 2: Try accessing via reflection/mirrors if date is null
              if (eventDate == null) {
                try {
                  final dynamicEvent = event as dynamic;
                  // Try alternative property names
                  final value = dynamicEvent.value;
                  debugPrint('  event.value: $value, type: ${value?.runtimeType}');
                  if (value != null && value is DateTime) {
                    eventDate = value;
                    debugPrint('Found via event.value: $eventDate');
                  }
                } catch (e) {
                  debugPrint('Error accessing event.value: $e');
                }
              }
              
              // Method 3: Try to construct from year/month/day properties
              if (eventDate == null) {
                try {
                  final dynamicEvent = event as dynamic;
                  final year = dynamicEvent.year;
                  final month = dynamicEvent.month;
                  final day = dynamicEvent.day;
                  debugPrint('  year: $year, month: $month, day: $day');
                  
                  if (year != null && month != null && day != null) {
                    // Handle year-only birthdays (some contacts don't have year)
                    // Use a default year if year is 0 or invalid
                    final actualYear = (year is int && year > 0) ? year : DateTime.now().year;
                    final actualMonth = month is int ? month : (month is String ? int.tryParse(month) : null);
                    final actualDay = day is int ? day : (day is String ? int.tryParse(day) : null);
                    
                    if (actualMonth != null && actualDay != null && actualMonth > 0 && actualMonth <= 12 && actualDay > 0 && actualDay <= 31) {
                      eventDate = DateTime(actualYear, actualMonth, actualDay);
                      debugPrint('Found via year/month/day: $eventDate');
                    }
                  }
                } catch (e) {
                  debugPrint('Error accessing year/month/day: $e');
                }
              }
              
              // Method 4: Try accessing all properties via toString and parsing
              if (eventDate == null) {
                try {
                  final eventStr = event.toString();
                  debugPrint('  Event toString: $eventStr');
                  // Look for date patterns in the string representation
                  // This is a fallback method
                } catch (e) {
                  debugPrint('Error in toString fallback: $e');
                }
              }
              
              if (eventDate != null) {
                birthdayDate = eventDate;
                debugPrint('Successfully extracted birthday: $birthdayDate');
                break;
              } else {
                debugPrint('Warning: Found birthday event but could not extract date.');
                debugPrint('  Event details: label=$label, event=$event');
                // Try to get more info about the event structure
                try {
                  final dynamicEvent = event as dynamic;
                  debugPrint('  Event properties: ${dynamicEvent.toString()}');
                } catch (e) {
                  debugPrint('  Could not inspect event properties: $e');
                }
              }
            }
          }
        } catch (e) {
          debugPrint('Error processing events for ${contact.displayName}: $e');
        }
        
        if (birthdayDate == null) {
          continue;
        }

        final name = contact.displayName.isNotEmpty 
            ? contact.displayName 
            : '${contact.name.first} ${contact.name.last}'.trim();
        
        if (name.isEmpty) {
          continue;
        }

        potentialBirthdays.add(
          PotentialBirthday(
            name: name,
            date: birthdayDate,
            source: 'Contacts',
          ),
        );
      }

      debugPrint('Found ${potentialBirthdays.length} contacts with birthdays');
      debugPrint('Summary: ${contacts.length} total contacts, $contactsWithEvents contacts with events, $totalEvents total events');
      
      // If we found contacts with events but no birthdays, log this for debugging
      if (contactsWithEvents > 0 && potentialBirthdays.isEmpty) {
        debugPrint('WARNING: Found $contactsWithEvents contacts with events but extracted 0 birthdays.');
        debugPrint('This might indicate an issue with date extraction on this device.');
      }
      
      return potentialBirthdays;
    } catch (e, stackTrace) {
      debugPrint('Error parsing contacts: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  }

  Future<List<PotentialBirthday>> parseGoogleCalendar() async {
    // This would require Google Calendar API integration
    // For now, return empty list - can be implemented later
    return [];
  }
}

class PotentialBirthday {
  final String name;
  final DateTime date;
  final String source;

  PotentialBirthday({
    required this.name,
    required this.date,
    required this.source,
  });

  event_model.Event toEvent([int? index]) {
    // Use index to ensure unique IDs when importing multiple events
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final uniqueId = index != null ? '${timestamp}_$index' : timestamp.toString();
    return event_model.Event(
      id: uniqueId,
      name: name,
      eventType: event_model.EventType.birthday,
      originalDate: date,
    );
  }
}

