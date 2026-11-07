import 'dart:io';

import 'package:birthday_app/models/custom_event_type.dart';
import 'package:birthday_app/models/event.dart';
import 'package:birthday_app/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;

  setUp(() async {
    await StorageService.resetForTest();
    dir = Directory.systemTemp.createTempSync('happaroo_storage');
    await StorageService().init(directory: dir.path);
  });

  tearDown(() async {
    await StorageService.resetForTest();
  });

  test('events, custom types, and settings round-trip', () async {
    final storage = StorageService();
    await storage.init();
    final event = Event(
      id: 'e1',
      name: 'Ada',
      eventType: EventType.birthday,
      originalDate: DateTime(2000, 2, 29),
      group: 'Family',
      notes: 'note',
    );
    await storage.addEvent(event);
    expect(storage.getEvent('e1')?.group, 'Family');
    expect(storage.getAllEvents(), hasLength(1));

    await storage.updateEvent(event.copyWith(name: 'Ada L'));
    expect(storage.getEvent('e1')?.name, 'Ada L');

    final type = CustomEventType(
      id: 't1',
      name: 'Party',
      primaryColorValue: 1,
      backgroundColorValue: 2,
      iconCodePoint: 3,
      turningTextTemplate: 'Turning {years}',
      nowTextTemplate: 'Now {years}!',
      currentTextTemplate: 'Currently {years}',
    );
    await storage.saveCustomEventType(type);
    expect(storage.getCustomEventTypeCount(), 1);
    expect(storage.getCustomEventType('t1')?.name, 'Party');
    expect(storage.getAllCustomEventTypes(), hasLength(1));

    expect(storage.getNotificationsEnabled(), isTrue);
    expect(storage.getNotificationDays(), [0, 1, 7]);
    expect(storage.getNotificationHour(), 8);
    expect(storage.getNotificationMinute(), 0);
    await storage.setNotificationTime(9, 30);
    await storage.saveSetting('notificationDays', 'nope');
    expect(storage.getNotificationDays(), [0, 1, 7]);
    await storage.saveSetting('notificationDays', [1, 7]);
    expect(storage.getNotificationDays(), [1, 7]);
    expect(storage.getFilterType(), 'all');
    await storage.setFilterType('birthday');
    expect(storage.getFilterType(), 'birthday');
    expect(storage.getTimeRange(), 365);
    await storage.setTimeRange(30);
    expect(storage.getTimeRange(), 30);
    await storage.saveSetting('themeMode', 'dark');

    final exported = storage.exportSettings();
    expect(exported['themeMode'], 'dark');
    expect(exported['notificationHour'], 9);
    await storage.importSettings({'themeMode': 'light', 'ignored': Object()});
    expect(storage.getSetting('themeMode'), 'light');

    final seen = <String>[];
    final subscription = storage.watchEvents().listen((event) {
      seen.add(event.key.toString());
    });
    await storage.deleteEvent('e1');
    await Future<void>.delayed(Duration.zero);
    expect(storage.getEvent('missing'), isNull);
    expect(storage.getAllEvents(), isEmpty);
    await storage.clearAllEvents();
    await storage.deleteCustomEventType('t1');
    expect(storage.getCustomEventTypeCount(), 0);
    await subscription.cancel();
    expect(seen, isNotEmpty);
  });
}
