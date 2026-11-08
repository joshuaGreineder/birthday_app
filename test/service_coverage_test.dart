import 'dart:convert';
import 'dart:io';

import 'package:birthday_app/app_config.dart';
import 'package:birthday_app/models/event.dart';
import 'package:birthday_app/services/contact_parser_service.dart';
import 'package:birthday_app/services/google_calendar_service.dart';
import 'package:birthday_app/services/link_service.dart';
import 'package:birthday_app/services/notification_service.dart';
import 'package:birthday_app/services/storage_service.dart';
import 'package:birthday_app/services/widget_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as contacts;
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    expect(found.map((item) => item.name), contains('No year'));
    expect(found.map((item) => item.name), isNot(contains('Anniversary only')));
    final noYear = found.firstWhere((item) => item.name == 'No year');
    expect(noYear.date.year, 4);
    expect(noYear.date.month, 5);
    expect(noYear.date.day, 1);
    final yearZero = found.firstWhere((item) => item.name == 'Year zero');
    expect(yearZero.date.year, 4);
    expect(yearZero.date.month, 4);
    expect(yearZero.date.day, 4);
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

    final yearless = Event(
      id: 'ny',
      name: 'Sam',
      eventType: EventType.birthday,
      originalDate: DateTime(4, 5, 1),
    );
    final yearlessMessage = service.reminderMessage(yearless, daysBefore: 0);
    expect(yearlessMessage, contains('birthday'));
    expect(yearlessMessage, isNot(contains('year')));
    expect(yearlessMessage, isNot(contains('4')));

    await service.init();
    expect(await service.notificationAccess(), NotificationAccess.unavailable);
    expect(await service.requestNotificationAccess(), NotificationAccess.denied);
    expect(await service.scheduleDailyNotifications(), isFalse);
    await service.cancelAllNotifications();
    await service.onAppResumed();
    await service.onTimezoneChanged('UTC');
    final status = await service.getNotificationStatus();
    // No plugin under test: start-up fails and is reported instead of hidden.
    expect(status['initialized'], isFalse);
    expect(status['initError'], isNotNull);
    expect(await service.sendTestNotification(), isNotNull);
    expect(status.containsKey('scheduledCount'), isTrue);
  });

  test('calendar sync without a Google client ID stays unavailable and harmless', () async {
    final calendar = GoogleCalendarService();
    expect(kCalendarSyncEnabled, isTrue);
    expect(kGoogleServerClientId, isEmpty);
    expect(calendar.isConfigured, isFalse);
    expect(calendar.isConnected, isFalse);
    final connect = await calendar.connect();
    expect(connect.ok, isFalse);
    expect(connect.message, contains('not set up'));
    final sync = await calendar.syncNow();
    expect(sync.ok, isFalse);
    calendar.syncInBackground(); // no-op when not connected
    expect(await ContactParserService().parseGoogleCalendar(), isEmpty);
  });

  test('widget data sends every event to the native widgets', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('happaroo_widget_svc');
    await StorageService().init(directory: dir.path);
    await StorageService().addEvent(Event(
      id: 'w1',
      name: 'Widget Ada',
      eventType: EventType.birthday,
      originalDate: DateTime(1991, 8, 8),
    ));
    await StorageService().addEvent(Event(
      id: 'w2',
      name: 'No Year',
      eventType: EventType.anniversary,
      originalDate: DateTime(4, 2, 29),
    ));

    const channel = MethodChannel(kWidgetChannel);
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
    await WidgetService.initialize();
    await WidgetService.updateWidgetData();
    expect(calls.map((c) => c.method), ['setWidgetEvents', 'updateWidgets']);
    final rows = jsonDecode((calls.first.arguments as Map)['json'] as String) as List;
    final byName = {for (final r in rows) (r as Map)['n']: r};
    expect(byName['Widget Ada'], {'n': 'Widget Ada', 't': 'b', 'l': '', 'm': 8, 'd': 8, 'y': 1991});
    expect(byName['No Year'], {'n': 'No Year', 't': 'a', 'l': '', 'm': 2, 'd': 29, 'y': 0});

    // A missing native side is logged, never thrown.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'missing');
    });
    await WidgetService.updateWidgetData();
    await StorageService().clearAllEvents();

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
