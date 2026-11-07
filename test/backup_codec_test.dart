import 'dart:convert';
import 'dart:io';

import 'package:birthday_app/models/custom_event_type.dart';
import 'package:birthday_app/models/event.dart';
import 'package:birthday_app/services/backup_codec.dart';
import 'package:birthday_app/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

Event sample({
  String id = '1',
  String name = 'Ada Lovelace',
  EventType type = EventType.birthday,
  DateTime? date,
  String group = 'Family',
  String? notes = 'Cake, "vanilla"',
  String? customEventTypeId,
}) {
  return Event(
    id: id,
    name: name,
    eventType: type,
    originalDate: date ?? DateTime(2000, 2, 29),
    group: group,
    notes: notes,
    customEventTypeId: customEventTypeId,
  );
}

CustomEventType partyType() {
  return CustomEventType(
    id: 'party',
    name: 'Party',
    primaryColorValue: 1,
    backgroundColorValue: 2,
    iconCodePoint: 3,
    turningTextTemplate: 'Turning {years}',
    nowTextTemplate: 'Now {years}!',
    currentTextTemplate: 'Currently {years}',
  );
}

void main() {
  const codec = BackupCodec();

  test('JSON and CSV round-trip events, types, and settings', () async {
    final events = [
      sample(),
      sample(
        id: '2',
        name: 'Mom & Dad',
        type: EventType.anniversary,
        date: DateTime(2012, 3, 4),
        group: '',
        notes: 'line\nbreak',
      ),
      sample(
        id: '3',
        name: 'Office',
        date: DateTime(2019, 6, 1),
        group: 'Work',
        notes: null,
        customEventTypeId: 'party',
      ),
    ];
    final types = [partyType()];
    final settings = {
      'notificationsEnabled': true,
      'notificationDays': [0, 1, 7],
      'themeMode': 'dark',
    };

    final json = codec.exportJson(events: events, customTypes: types, settings: settings);
    final jsonPreview = codec.preview(
      fileName: 'happaroo-backup.json',
      contents: json,
      existingEvents: const [],
      existingTypes: const [],
    );
    expect(jsonPreview.fileError, isNull);
    expect(jsonPreview.problems, isEmpty);
    expect(jsonPreview.added, hasLength(3));
    expect(jsonPreview.newCustomTypes.single.name, 'Party');
    expect(jsonPreview.newCustomTypes.single.primaryColorValue, 1);
    expect(jsonPreview.settings?['themeMode'], 'dark');
    expect(jsonPreview.added[2].event.customEventTypeId, 'party');
    expect(jsonPreview.added[2].typeLabel, 'Party');
    expect(jsonPreview.added.first.event.originalDate.month, 2);
    expect(jsonPreview.added.first.event.originalDate.day, 29);

    final csv = codec.exportCsv(events: events, customTypes: types);
    expect(csv, contains('Name,Date,Type,Group,Notes'));
    expect(csv, contains('"Cake, ""vanilla"""'));
    expect(csv, contains('2000-02-29'));
    expect(csv, contains('Party'));

    final csvPreview = codec.preview(
      fileName: 'events.csv',
      contents: csv,
      existingEvents: const [],
      existingTypes: const [],
    );
    expect(csvPreview.fileError, isNull);
    expect(csvPreview.problems, isEmpty);
    expect(csvPreview.added, hasLength(3));
    expect(csvPreview.added.map((row) => row.typeLabel), ['Birthday', 'Anniversary', 'Party']);
    expect(csvPreview.added[1].event.notes, 'line\nbreak');
    expect(csvPreview.added[1].event.group, '');
    expect(csvPreview.settings, isNull);
    expect(csvPreview.newCustomTypes.single.name, 'Party');

    final dir = Directory.systemTemp.createTempSync('happaroo_backup');
    await StorageService().init(directory: dir.path);
    await codec.apply(StorageService(), jsonPreview);
    final stored = StorageService().getAllEvents();
    expect(stored, hasLength(3));
    expect(StorageService().getCustomEventType('party')?.name, 'Party');
    expect(StorageService().getSetting('themeMode'), 'dark');

    final again = codec.preview(
      fileName: 'happaroo-backup.json',
      contents: json,
      existingEvents: stored,
      existingTypes: StorageService().getAllCustomEventTypes(),
    );
    expect(again.added, isEmpty);
    expect(again.duplicates, hasLength(3));
    expect(again.newCustomTypes, isEmpty);
    final kept = stored.length;
    await codec.apply(StorageService(), again);
    expect(StorageService().getAllEvents(), hasLength(kept));

    await StorageService().addEvent(sample(id: 'local-only', name: 'Local Only', date: DateTime(1999, 1, 2)));
    final partial = codec.preview(
      fileName: 'events.csv',
      contents: csv,
      existingEvents: StorageService().getAllEvents(),
      existingTypes: StorageService().getAllCustomEventTypes(),
    );
    await codec.apply(StorageService(), partial);
    expect(
      StorageService().getAllEvents().map((event) => event.name),
      contains('Local Only'),
    );
    await StorageService.resetForTest();
  });

  test('CSV accepts columns in any order and reports row errors', () {
    const codec = BackupCodec();
    const csv = 'Notes,Type,Group,Date,Name\r\n'
        '"Hello, friend",birthday,Neighbors,3/4/2001,Grace\n'
        'note,Birthday,Neighbors,2/29/2025,Bad leap\n'
        'note,Anniversary,Neighbors,3/14,No year\n'
        'ok,,Club,2001-03-04,Blank type\n'
        'ok,Graduation,,02/03/2000,New type\n';

    final preview = codec.preview(
      fileName: 'people.csv',
      contents: '\uFEFF$csv',
      existingEvents: [
        sample(name: 'Grace', date: DateTime(2001, 3, 4), group: 'Old', notes: 'other'),
      ],
      existingTypes: const [],
    );

    expect(preview.fileError, isNull);
    expect(preview.duplicates.single.event.name, 'Grace');
    expect(preview.added.single.typeLabel, 'Graduation');
    expect(preview.added.single.event.originalDate, DateTime(2000, 2, 3));
    expect(preview.newCustomTypes.single.name, 'Graduation');
    expect(preview.problems.map((problem) => problem.rowNumber), containsAll([3, 4, 5]));
    expect(preview.problems.map((problem) => problem.message).join('\n'), contains('February 29'));
    expect(preview.problems.map((problem) => problem.message).join('\n'), contains('no year'));
    expect(preview.problems.map((problem) => problem.message).join('\n'), contains('Type is blank'));
    expect(preview.canApply, isTrue);
  });

  test('unreadable files and unknown schema versions do not throw', () {
    const codec = BackupCodec();
    expect(
      codec.preview(fileName: 'x.csv', contents: '"unterminated', existingEvents: const [], existingTypes: const []).fileError,
      contains('quoted'),
    );
    expect(
      codec.preview(fileName: 'x.csv', contents: 'Hello\n', existingEvents: const [], existingTypes: const []).fileError,
      contains('header'),
    );
    expect(
      codec.preview(fileName: 'x.json', contents: '{"schemaVersion": 9}', existingEvents: const [], existingTypes: const []).fileError,
      contains('schema version'),
    );
    expect(
      codec.preview(fileName: 'x.json', contents: '[]', existingEvents: const [], existingTypes: const []).fileError,
      isNotNull,
    );
    final parsed = jsonDecode(codec.exportJson(events: const [], customTypes: const [], settings: const {}));
    expect(parsed['schemaVersion'], 1);
    expect(parseEventDate('01/02/2003').date, DateTime(2003, 1, 2));
    expect(parseEventDate('not-a-date').error, contains('not a valid date'));
    expect(parseEventDate('').error, contains('blank'));
    expect(parseCsv('a,b\r\n1,2\r\n'), [
      ['a', 'b'],
      ['1', '2'],
    ]);
  });
}
