import 'dart:io';

import 'package:birthday_app/app_config.dart';
import 'package:birthday_app/models/event.dart';
import 'package:birthday_app/services/contact_parser_service.dart';
import 'package:birthday_app/services/google_calendar_service.dart';
import 'package:birthday_app/services/link_service.dart';
import 'package:birthday_app/services/notification_service.dart';
import 'package:birthday_app/services/storage_service.dart';
import 'package:birthday_app/services/widget_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as contacts;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeClient extends http.BaseClient {
  http.BaseRequest? sent;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    sent = request;
    return http.StreamedResponse(Stream<List<int>>.value(const []), 204);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('contact parsing reads birthdays and skips other rows', () {
    final parser = ContactParserService();
    final found = parser.birthdaysFromContacts([
      contacts.Contact(
        displayName: 'Ada Lovelace',
        events: [contacts.Event(year: 1815, month: 12, day: 10)],
      ),
      contacts.Contact(
        displayName: 'No year',
        events: [contacts.Event(month: 5, day: 1)],
      ),
      contacts.Contact(
        displayName: '',
        name: contacts.Name(),
        events: [contacts.Event(year: 2000, month: 1, day: 1)],
      ),
      contacts.Contact(
        displayName: 'Anniversary only',
        events: [
          contacts.Event(year: 2010, month: 2, day: 2, label: contacts.EventLabel.anniversary),
        ],
      ),
      contacts.Contact(
        displayName: 'Other',
        events: [contacts.Event(year: 2011, month: 3, day: 3, label: contacts.EventLabel.other)],
      ),
      contacts.Contact(
        displayName: 'Year zero',
        events: [contacts.Event(year: 0, month: 4, day: 4)],
      ),
    ]);

    expect(found.map((item) => item.name), contains('Ada Lovelace'));
    expect(found.map((item) => item.name), contains('Year zero'));
    expect(found.map((item) => item.name), isNot(contains('Anniversary only')));
    expect(found.map((item) => item.name), isNot(contains('No year')));
    final event = found.first.toEvent(0);
    expect(event.eventType, EventType.birthday);
    expect(event.name, found.first.name);
    expect(found.first.toEvent().id, isNotEmpty);
  });

  test('notification helpers and guarded plugin calls stay user-safe', () async {
    final service = NotificationService();
    expect(service.timezoneForOffsetHours(-5), 'America/New_York');
    expect(service.timezoneForOffsetHours(-6), 'America/Chicago');
    expect(service.timezoneForOffsetHours(-7), 'America/Denver');
    expect(service.timezoneForOffsetHours(-8), 'America/Los_Angeles');
    expect(service.timezoneForOffsetHours(0), 'UTC');
    expect(service.accessFor(PermissionStatus.granted), NotificationAccess.granted);
    expect(service.accessFor(PermissionStatus.denied), NotificationAccess.denied);
    expect(
      service.accessFor(PermissionStatus.permanentlyDenied),
      NotificationAccess.permanentlyDenied,
    );
    expect(service.accessFor(PermissionStatus.restricted), NotificationAccess.permanentlyDenied);

    final birthday = Event(
      id: 'b',
      name: 'Ada',
      eventType: EventType.birthday,
      originalDate: DateTime(1990, 6, 15),
    );
    final anniversary = Event(
      id: 'a',
      name: 'Us',
      eventType: EventType.anniversary,
      originalDate: DateTime(2020, 6, 15),
    );
    expect(service.reminderMessage(birthday, daysBefore: 0), contains('Birthday'));
    expect(service.reminderMessage(birthday, daysBefore: 1), contains('tomorrow'));
    expect(service.reminderMessage(birthday, daysBefore: 7), contains('7 days'));
    expect(service.reminderMessage(anniversary, daysBefore: 0), contains('Anniversary'));
    expect(service.reminderMessage(anniversary, daysBefore: 1), contains('tomorrow'));
    expect(service.reminderMessage(anniversary, daysBefore: 3), contains('3 days'));

    final bornToday = Event(
      id: 'today',
      name: 'New',
      eventType: EventType.birthday,
      originalDate: DateTime.now(),
    );
    expect(service.reminderMessage(bornToday, daysBefore: 0), contains('born today'));

    await service.init();
    expect(await service.notificationAccess(), NotificationAccess.unavailable);
    expect(await service.requestNotificationAccess(), NotificationAccess.denied);
    expect(await service.scheduleDailyNotifications(), isFalse);
    await service.cancelAllNotifications();
    await service.onAppResumed();
    await service.onTimezoneChanged('UTC');
    final status = await service.getNotificationStatus();
    expect(status['initialized'], isTrue);
    expect(status.containsKey('scheduledCount'), isTrue);
  });

  test('calendar sync stays off and the auth client forwards headers', () async {
    final calendar = GoogleCalendarService();
    expect(kCalendarSyncEnabled, isFalse);
    expect(calendar.isAuthenticated, isFalse);
    expect(await calendar.signIn(), isFalse);
    await calendar.signOut();
    final event = Event(
      id: '1',
      name: 'Ada',
      eventType: EventType.birthday,
      originalDate: DateTime(2000, 1, 1),
    );
    expect(await calendar.syncEventToCalendar(event), isFalse);
    expect(await calendar.syncAllEvents([event]), isFalse);
    expect(await ContactParserService().parseGoogleCalendar(), isEmpty);

    final fake = _FakeClient();
    final client = GoogleAuthClient({'Authorization': 'Bearer test'}, client: fake);
    final request = http.Request('GET', Uri.parse('https://example.com/calendars'));
    final response = await client.send(request);
    expect(response.statusCode, 204);
    expect(fake.sent?.headers['Authorization'], 'Bearer test');
  });

  test('widget data is written through the channel and the preferences fallback', () async {
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('happaroo_widget_svc');
    await StorageService().init(directory: dir.path);
    await StorageService().addEvent(Event(
      id: 'w1',
      name: 'Widget Ada',
      eventType: EventType.birthday,
      originalDate: DateTime(1991, 8, 8),
    ));

    const channel = MethodChannel(kWidgetChannel);
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return true;
    });
    await WidgetService.initialize();
    await WidgetService.updateWidgetData();
    expect(calls, contains('setWidgetData'));

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'missing');
    });
    await WidgetService.updateWidgetData();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('nextEventName'), 'Widget Ada');

    await StorageService().clearAllEvents();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => true);
    await WidgetService.updateWidgetData();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'missing');
    });
    await WidgetService.updateWidgetData();
    expect(prefs.getBool('hasNextEvent'), isFalse);

    const platform = MethodChannel(kPlatformChannel);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(platform, (call) async => true);
    expect(await LinkService.open('https://happaroo.com/privacy'), isTrue);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(platform, (call) async {
      throw PlatformException(code: 'no-browser');
    });
    expect(await LinkService.open('https://happaroo.com/privacy'), isFalse);

    await StorageService.resetForTest();
  });
}
