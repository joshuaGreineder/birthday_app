import 'package:birthday_app/models/event.dart';
import 'package:birthday_app/utils/event_calculator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

Event birthday(String name, DateTime date, {String? id}) {
  return Event(
    id: id ?? name,
    name: name,
    eventType: EventType.birthday,
    originalDate: date,
  );
}

Event anniversary(String name, DateTime date) {
  return Event(
    id: name,
    name: name,
    eventType: EventType.anniversary,
    originalDate: date,
  );
}

void main() {
  final leapBaby = birthday('Leap', DateTime(2000, 2, 29));

  test('February 29 is stored as month 2 day 29', () {
    expect(leapBaby.originalDate.month, 2);
    expect(leapBaby.originalDate.day, 29);
    final kept = EventCalculator.observedOn(2024, 2, 29);
    expect(kept.month, 2);
    expect(kept.day, 29);
  });

  test('February 29 in a non-leap year is observed on February 28', () {
    expect(EventCalculator.observedOn(2025, 2, 29), DateTime(2025, 2, 28));
    expect(EventCalculator.observedOn(2025, 2, 29).month, isNot(3));

    final before = DateTime(2025, 2, 27);
    final next = EventCalculator.getNextOccurrence(leapBaby, now: before);
    expect(next, DateTime(2025, 2, 28));
    expect(EventCalculator.getAge(leapBaby, now: before), 24);
    expect(EventCalculator.getAgeText(leapBaby, now: before), 'Turning 25 tomorrow');
    expect(EventCalculator.getAgeText(leapBaby, now: DateTime(2025, 2, 26)), 'Turning 25');

    final onDay = DateTime(2025, 2, 28);
    expect(EventCalculator.getDaysUntil(leapBaby, now: onDay), 0);
    expect(EventCalculator.getAge(leapBaby, now: onDay), 24);
    expect(EventCalculator.getAgeText(leapBaby, now: onDay), 'Now 25 years old!');

    final after = DateTime(2025, 3, 1);
    final later = EventCalculator.getNextOccurrence(leapBaby, now: after);
    expect(later.isBefore(after), isFalse);
    expect(later, DateTime(2026, 2, 28));
    expect(EventCalculator.getAge(leapBaby, now: after), 25);
    expect(EventCalculator.getUpcomingEvents([leapBaby], now: after), [leapBaby]);
    expect(
      EventCalculator.getEventsForDate([leapBaby], DateTime(2025, 2, 28)),
      [leapBaby],
    );
    expect(EventCalculator.getEventsForDate([leapBaby], DateTime(2025, 3, 1)), isEmpty);
    expect(
      EventCalculator.getEventsForDate([leapBaby], DateTime(2024, 2, 29)),
      [leapBaby],
    );
  });

  test('year rollover and an event today', () {
    final newYear = birthday('New Year', DateTime(1990, 1, 1));
    final newYearsEve = DateTime(2026, 12, 31);
    expect(
      EventCalculator.getNextOccurrence(newYear, now: newYearsEve),
      DateTime(2027, 1, 1),
    );
    expect(EventCalculator.getDaysUntil(newYear, now: newYearsEve), 1);
    expect(EventCalculator.getAge(newYear, now: newYearsEve), 36);

    final eve = birthday('Eve', DateTime(2000, 12, 31));
    final january = DateTime(2026, 1, 1);
    expect(EventCalculator.getAge(eve, now: january), 25);
    expect(
      EventCalculator.getNextOccurrence(eve, now: january),
      DateTime(2026, 12, 31),
    );

    final today = DateTime(2026, 6, 15);
    final ada = birthday('Ada', DateTime(1990, 6, 15));
    expect(EventCalculator.getDaysUntil(ada, now: today), 0);
    expect(EventCalculator.getAgeText(ada, now: today), 'Now 36 years old!');
    expect(EventCalculator.getUpcomingEvents([ada], now: today), [ada]);
    expect(EventCalculator.getAgeText(ada, now: DateTime(2026, 6, 14)), 'Turning 36 tomorrow');
    expect(EventCalculator.getAgeText(ada, now: DateTime(2026, 5, 1)), 'Turning 36');
  });

  test('a first birthday is one year old, not 12 months', () {
    final baby = birthday('Sam', DateTime(2025, 11, 7));
    final first = DateTime(2026, 11, 7);
    expect(EventCalculator.getBabyAge(baby, now: first), isNull);
    expect(EventCalculator.getAge(baby, now: first), 0);
    expect(EventCalculator.getAgeText(baby, now: first), 'Now 1 year old!');

    final dayBefore = DateTime(2026, 11, 6);
    expect(EventCalculator.getAgeText(baby, now: dayBefore), 'Turning 1 year');
    expect(EventCalculator.getBabyAge(baby, now: dayBefore), isNotNull);

    final bornToday = birthday('New', DateTime(2026, 11, 7));
    expect(EventCalculator.getAgeText(bornToday, now: DateTime(2026, 11, 7)), 'Born today! 🎂');

    final weeks = birthday('Weeks', DateTime(2026, 10, 20));
    expect(
      EventCalculator.getAgeText(weeks, now: DateTime(2026, 11, 7)),
      'Turning 1 year',
    );
    final age = EventCalculator.getBabyAge(weeks, now: DateTime(2026, 11, 7));
    expect(age!['months'], 0);
    expect(age['days'], greaterThan(0));
  });

  test('anniversary ordinals', () {
    final day = DateTime(2026, 11, 7);
    String textFor(int startYear) {
      return EventCalculator.getAgeText(
        anniversary('Us', DateTime(startYear, 11, 7)),
        now: day,
      );
    }

    expect(textFor(2025), '1st anniversary today!');
    expect(textFor(2024), '2nd anniversary today!');
    expect(textFor(2023), '3rd anniversary today!');
    expect(textFor(2015), '11th anniversary today!');
    expect(textFor(2014), '12th anniversary today!');
    expect(textFor(2013), '13th anniversary today!');
    expect(textFor(2005), '21st anniversary today!');
    expect(textFor(2004), '22nd anniversary today!');
    expect(textFor(2003), '23rd anniversary today!');
    expect(
      EventCalculator.getAgeText(anniversary('Us', DateTime(2020, 11, 8)), now: day),
      '6th anniversary tomorrow',
    );
    expect(
      EventCalculator.getAgeText(anniversary('Us', DateTime(2020, 12, 1)), now: day),
      '6th anniversary',
    );
    expect(EventCalculator.getAge(anniversary('Us', DateTime(2020, 1, 1)), now: day), 0);
  });

  test('spring-forward does not shorten a calendar-day count', () {
    tzdata.initializeTimeZones();
    final ny = tz.getLocation('America/New_York');
    final start = tz.TZDateTime(ny, 2026, 3, 7);
    final end = tz.TZDateTime(ny, 2026, 3, 9);
    expect(end.difference(start).inDays, 1);
    expect(EventCalculator.calendarDaysBetween(start, end), 2);

    final event = birthday('March', DateTime(2000, 3, 9));
    expect(EventCalculator.getDaysUntil(event, now: DateTime(2026, 3, 7)), 2);
    expect(EventCalculator.calendarDaysBetween(DateTime(2026, 3, 1), DateTime(2026, 5, 20)), 80);
  });

  test('upcoming events sort and an empty list stays empty', () {
    expect(EventCalculator.getUpcomingEvents([]), isEmpty);
    final later = birthday('Later', DateTime(1990, 12, 1));
    final sooner = birthday('Sooner', DateTime(1990, 11, 8));
    final ordered = EventCalculator.getUpcomingEvents(
      [later, sooner],
      now: DateTime(2026, 11, 7),
    );
    expect(ordered.map((event) => event.name), ['Sooner', 'Later']);
    expect(EventCalculator.getYearsTogether(sooner, now: DateTime(2026, 11, 7)), 35);
  });

  test('a baby birthday that crosses a month boundary counts calendar days', () {
    final baby = birthday('Month', DateTime(2026, 1, 31));
    final age = EventCalculator.getBabyAge(baby, now: DateTime(2026, 3, 10));
    expect(age, isNotNull);
    expect(age!['months'], greaterThanOrEqualTo(0));
  });
}
