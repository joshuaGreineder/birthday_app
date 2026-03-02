import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as cal;
import 'package:http/http.dart' as http;
import '../models/event.dart';
import '../utils/event_calculator.dart';

class GoogleCalendarService {
  static GoogleCalendarService? _instance;
  GoogleSignIn? _googleSignIn;
  cal.CalendarApi? _calendarApi;
  bool _isAuthenticated = false;

  factory GoogleCalendarService() {
    _instance ??= GoogleCalendarService._internal();
    return _instance!;
  }

  GoogleCalendarService._internal();

  /// Initialize GoogleSignIn lazily to avoid web initialization errors
  /// when client ID is not configured
  GoogleSignIn _getGoogleSignIn() {
    _googleSignIn ??= GoogleSignIn(
      scopes: [
        'https://www.googleapis.com/auth/calendar',
        'https://www.googleapis.com/auth/calendar.events',
      ],
    );
    return _googleSignIn!;
  }

  bool get isAuthenticated => _isAuthenticated;

  Future<bool> signIn() async {
    try {
      final googleSignIn = _getGoogleSignIn();
      final account = await googleSignIn.signIn();
      if (account == null) {
        return false;
      }

      final authHeaders = await googleSignIn.currentUser!.authHeaders;
      final authenticatedClient = GoogleAuthClient(authHeaders);
      _calendarApi = cal.CalendarApi(authenticatedClient);
      _isAuthenticated = true;
      return true;
    } catch (e) {
      debugPrint('Google Sign In error: $e');
      _isAuthenticated = false;
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      if (_googleSignIn != null) {
        await _googleSignIn!.signOut();
      }
      _calendarApi = null;
      _isAuthenticated = false;
    } catch (e) {
      debugPrint('Google Sign Out error: $e');
    }
  }

  Future<bool> syncEventToCalendar(Event event) async {
    if (!_isAuthenticated || _calendarApi == null) {
      return false;
    }

    try {
      final nextOccurrence = EventCalculator.getNextOccurrence(event);
      
      // Create recurring event for birthdays/anniversaries
      final eventTitle = _getEventTitle(event);
      final description = event.notes ?? '';
      
      // Create EventDateTime objects for all-day events using fromJson
      // For all-day events, we use the 'date' property (not 'dateTime')
      final endDateNextDay = nextOccurrence.add(const Duration(days: 1));
      
      final startDateTime = cal.EventDateTime.fromJson({
        'date': {
          'year': nextOccurrence.year,
          'month': nextOccurrence.month,
          'day': nextOccurrence.day,
        },
      });
        
      final endDateTime = cal.EventDateTime.fromJson({
        'date': {
          'year': endDateNextDay.year,
          'month': endDateNextDay.month,
          'day': endDateNextDay.day,
        },
      });

      final reminders = cal.EventReminders()
        ..useDefault = false
        ..overrides = [
          cal.EventReminder()..method = 'popup'..minutes = 1440, // 1 day before
        ];

      final calendarEvent = cal.Event()
        ..summary = eventTitle
        ..description = description
        ..start = startDateTime
        ..end = endDateTime
        ..recurrence = [
          'RRULE:FREQ=YEARLY;BYMONTH=${nextOccurrence.month};BYMONTHDAY=${nextOccurrence.day}'
        ]
        ..reminders = reminders;

      await _calendarApi!.events.insert(calendarEvent, 'primary');
      return true;
    } catch (e) {
      debugPrint('Error syncing event to Google Calendar: $e');
      return false;
    }
  }

  Future<bool> syncAllEvents(List<Event> events) async {
    if (!_isAuthenticated || _calendarApi == null) {
      return false;
    }

    bool allSuccess = true;
    for (final event in events) {
      final success = await syncEventToCalendar(event);
      if (!success) {
        allSuccess = false;
      }
    }
    return allSuccess;
  }

  String _getEventTitle(Event event) {
    if (event.eventType == EventType.birthday) {
      return "${event.name}'s Birthday";
    } else if (event.eventType == EventType.anniversary) {
      return "${event.name} Anniversary";
    } else {
      return event.name;
    }
  }
}

// HTTP client that uses Google auth headers
class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}

