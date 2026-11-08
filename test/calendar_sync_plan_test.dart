import 'package:birthday_app/models/event.dart';
import 'package:birthday_app/services/calendar_sync_plan.dart';
import 'package:birthday_app/utils/yearless_date.dart';
import 'package:flutter_test/flutter_test.dart';

Event _event(String id, String name, DateTime date,
        {EventType type = EventType.birthday, String? notes}) =>
    Event(id: id, name: name, eventType: type, originalDate: date, notes: notes);

void main() {
  group('buildCalendarEntry', () {
    test('birthday with a known year is a yearly all-day event from the birth date', () {
      final e = buildCalendarEntry(_event('a', 'Paul Gann', DateTime(1967, 11, 11)));
      expect(e.title, "Paul Gann's birthday");
      expect(e.start, DateTime.utc(1967, 11, 11));
      expect(e.endExclusive, DateTime.utc(1967, 11, 12));
      expect(e.recurrence, 'RRULE:FREQ=YEARLY');
      expect(e.description, startsWith('Born 1967'));
    });

    test('anniversary says Since and keeps notes', () {
      final e = buildCalendarEntry(_event('b', 'Sarah and Cody', DateTime(2017, 10, 9),
          type: EventType.anniversary, notes: 'Lancaster'));
      expect(e.title, "Sarah and Cody's anniversary");
      expect(e.description, contains('Since 2017'));
      expect(e.description, contains('Lancaster'));
    });

    test('custom type label replaces the generic title', () {
      final e = buildCalendarEntry(_event('c', 'Dana', DateTime(2020, 3, 1)),
          customTypeName: 'Work Anniversary');
      expect(e.title, 'Dana · Work Anniversary');
    });

    test('yearless date uses a real leap start year and never shows the sentinel', () {
      final e = buildCalendarEntry(_event('d', 'Friend', yearlessDate(7, 4)));
      expect(e.start, DateTime.utc(kYearlessCalendarStartYear, 7, 4));
      expect(e.description, isNot(contains('Born')));
      expect(e.description, isNot(contains('0004')));
    });

    test('February 29 recurs on the last day of February', () {
      final known = buildCalendarEntry(_event('e', 'Leap', DateTime(1996, 2, 29)));
      expect(known.recurrence, 'RRULE:FREQ=YEARLY;BYMONTH=2;BYMONTHDAY=-1');
      expect(known.start, DateTime.utc(1996, 2, 29));
      final yearless = buildCalendarEntry(_event('f', 'Leap', yearlessDate(2, 29)));
      expect(yearless.start, DateTime.utc(2024, 2, 29));
      expect(yearless.recurrence, contains('BYMONTHDAY=-1'));
    });

    test('December 31 ends on January 1 of the next year', () {
      final e = buildCalendarEntry(_event('g', 'Josh', DateTime(2001, 12, 31)));
      expect(e.endExclusive, DateTime.utc(2002, 1, 1));
    });

    test('fingerprint is stable and changes when content changes', () {
      final a = buildCalendarEntry(_event('h', 'Ann', DateTime(1990, 5, 5)));
      final b = buildCalendarEntry(_event('h', 'Ann', DateTime(1990, 5, 5)));
      final c = buildCalendarEntry(_event('h', 'Anne', DateTime(1990, 5, 5)));
      expect(a.fingerprint, b.fingerprint);
      expect(a.fingerprint, isNot(c.fingerprint));
      expect(fnv1a32(''), '811c9dc5');
      expect(fnv1a32('a'), 'e40c292c');
    });
  });

  group('planSync', () {
    final one = buildCalendarEntry(_event('1', 'One', DateTime(2000, 1, 1)));
    final two = buildCalendarEntry(_event('2', 'Two', DateTime(2000, 2, 2)));

    test('first sync creates everything', () {
      final plan = planSync([one, two], const []);
      expect(plan.create.map((e) => e.happarooId), ['1', '2']);
      expect(plan.update, isEmpty);
      expect(plan.delete, isEmpty);
    });

    test('unchanged events are skipped', () {
      final plan = planSync([one], [RemoteEntry(remoteId: 'r1', happarooId: '1', fingerprint: one.fingerprint)]);
      expect(plan.isEmpty, isTrue);
    });

    test('changed events update, removed events delete, duplicates are cleaned up', () {
      final plan = planSync(
        [one],
        [
          const RemoteEntry(remoteId: 'r1', happarooId: '1', fingerprint: 'old'),
          RemoteEntry(remoteId: 'r1-dup', happarooId: '1', fingerprint: one.fingerprint),
          const RemoteEntry(remoteId: 'r9', happarooId: '9', fingerprint: 'x'),
        ],
      );
      expect(plan.create, isEmpty);
      expect(plan.update.keys, ['r1']);
      expect(plan.delete, unorderedEquals(['r1-dup', 'r9']));
    });
  });
}
