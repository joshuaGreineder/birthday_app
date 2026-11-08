import '../models/event.dart';
import 'yearless_date.dart';

class EventCalculator {
  /// False when the date is only a month and day. Age and anniversary counts stay hidden.
  static bool hasKnownYear(Event event) => !isYearlessDate(event.originalDate);

  /// Next observance of [event]. February 29 is kept as month 2 day 29 in
  /// storage. In a non-leap year it is observed on February 28, never March 1.
  static DateTime getNextOccurrence(Event event, {DateTime? now}) {
    final today = _dateOnly(now ?? DateTime.now());
    final month = event.originalDate.month;
    final day = event.originalDate.day;
    var next = observedOn(today.year, month, day);
    if (next.isBefore(today)) {
      next = observedOn(today.year + 1, month, day);
    }
    return next;
  }

  /// Calendar days until the next observance. A spring-forward does not
  /// shorten the count, because the span is measured in dates, not 24-hour chunks.
  static int getDaysUntil(Event event, {DateTime? now}) {
    final today = _dateOnly(now ?? DateTime.now());
    final next = getNextOccurrence(event, now: today);
    return calendarDaysBetween(today, next);
  }

  /// Whole calendar days from [from] to [to]. Ignores the clock and DST.
  static int calendarDaysBetween(DateTime from, DateTime to) {
    final start = DateTime.utc(from.year, from.month, from.day);
    final end = DateTime.utc(to.year, to.month, to.day);
    return end.difference(start).inDays;
  }

  /// February 29 stays February 29 in a leap year. Other years use February 28
  /// so [DateTime] does not roll the day into March.
  static DateTime observedOn(int year, int month, int day) {
    if (month == 2 && day == 29 && !isLeapYear(year)) {
      return DateTime(year, 2, 28);
    }
    return DateTime(year, month, day);
  }

  static bool isLeapYear(int year) {
    return (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
  }

  /// Months and days for a birthday before the first observance.
  /// Returns null once the person has reached that first birthday, including
  /// on the day itself, so a first birthday is not described as 12 months.
  static Map<String, int>? getBabyAge(Event event, {DateTime? now}) {
    if (!hasKnownYear(event) || event.eventType != EventType.birthday) return null;

    final today = _dateOnly(now ?? DateTime.now());
    final birth = _dateOnly(event.originalDate);
    if (!today.isBefore(birth) && !_isBeforeFirstBirthday(birth, today)) {
      return null;
    }
    if (today.isBefore(birth)) {
      return {'months': 0, 'days': 0};
    }
    if (_sameDate(today, birth)) {
      return {'months': 0, 'days': 0};
    }

    var months = (today.year - birth.year) * 12 + (today.month - birth.month);
    if (today.day < birth.day) {
      months--;
    }
    if (months < 0) months = 0;

    final int days;
    if (today.day >= birth.day) {
      days = today.day - birth.day;
    } else {
      final previousMonth = today.month == 1 ? 12 : today.month - 1;
      final previousYear = today.month == 1 ? today.year - 1 : today.year;
      final anchor = DateTime(previousYear, previousMonth, birth.day);
      days = calendarDaysBetween(anchor, today);
    }

    return {'months': months, 'days': days};
  }

  /// Completed years before today's observance.
  /// On the birthday this is one less than the age they are turning, which
  /// callers add back for "Now N years old".
  static int getAge(Event event, {DateTime? now}) {
    if (!hasKnownYear(event) || event.eventType != EventType.birthday) return 0;
    return _yearsBeforeObservance(event.originalDate, now ?? DateTime.now());
  }

  /// Completed years before today's observance for anniversaries and custom events.
  /// Yearless dates return 0 and must not be shown as an anniversary count.
  static int getYearsTogether(Event event, {DateTime? now}) {
    if (!hasKnownYear(event)) return 0;
    if (event.eventType == EventType.birthday) {
      return getAge(event, now: now);
    }
    return _yearsBeforeObservance(event.originalDate, now ?? DateTime.now());
  }

  static List<Event> getUpcomingEvents(List<Event> events, {DateTime? now}) {
    if (events.isEmpty) return [];

    final today = _dateOnly(now ?? DateTime.now());
    final upcoming = events.where((event) {
      try {
        final next = getNextOccurrence(event, now: today);
        return !next.isBefore(today);
      } catch (e) {
        return false;
      }
    }).toList();

    upcoming.sort((a, b) {
      try {
        final nextA = getNextOccurrence(a, now: today);
        final nextB = getNextOccurrence(b, now: today);
        return nextA.compareTo(nextB);
      } catch (e) {
        return 0;
      }
    });
    return upcoming;
  }

  /// Events observed on [date], including a February 29 event on February 28
  /// when [date] is not in a leap year.
  static List<Event> getEventsForDate(List<Event> events, DateTime date) {
    final day = _dateOnly(date);
    return events.where((event) {
      final original = event.originalDate;
      final observed = observedOn(day.year, original.month, original.day);
      return observed.month == day.month && observed.day == day.day;
    }).toList();
  }

  /// Current age in months and days for anyone under 2, e.g. "21 months, 2 days old".
  /// Null for older people, unknown birth years, future births and non-birthdays,
  /// so callers show years as usual.
  static String? youngAgeText(Event event, {DateTime? now}) {
    if (!hasKnownYear(event) || event.eventType != EventType.birthday) return null;
    final today = _dateOnly(now ?? DateTime.now());
    final birth = _dateOnly(event.originalDate);
    if (today.isBefore(birth)) return null;
    final second = observedOn(birth.year + 2, birth.month, birth.day);
    if (!today.isBefore(second)) return null;
    if (_sameDate(today, birth)) return 'Born today';

    var months = (today.year - birth.year) * 12 + (today.month - birth.month);
    if (today.day < birth.day) months--;
    // Day count from the latest monthly anniversary (clamped for short months).
    final anchorYear = birth.year + (birth.month - 1 + months) ~/ 12;
    final anchorMonth = (birth.month - 1 + months) % 12 + 1;
    final lastDay = DateTime(anchorYear, anchorMonth + 1, 0).day;
    final anchor = DateTime(anchorYear, anchorMonth, birth.day > lastDay ? lastDay : birth.day);
    final days = today.difference(anchor).inDays;

    String unit(int n, String one) => '$n $one${n == 1 ? '' : 's'}';
    if (months == 0) return '${unit(days, 'day')} old';
    if (days == 0) return '${unit(months, 'month')} old';
    return '${unit(months, 'month')}, ${unit(days, 'day')} old';
  }

  static String nowYearsText(int years) {
    if (years == 1) return 'Now 1 year old!';
    return 'Now $years years old!';
  }

  static String getAgeText(Event event, {DateTime? now}) {
    if (!hasKnownYear(event)) {
      return event.eventType == EventType.birthday ? 'Birthday' : 'Anniversary';
    }
    final clock = now ?? DateTime.now();
    if (event.eventType == EventType.birthday) {
      final age = getAge(event, now: clock);
      final daysUntil = getDaysUntil(event, now: clock);
      final babyAge = getBabyAge(event, now: clock);

      if (babyAge != null) {
        final months = babyAge['months']!;
        final days = babyAge['days']!;
        if (daysUntil == 0) {
          final wasBornThisYear = clock.year == event.originalDate.year;
          if (months == 0 && days == 0 && wasBornThisYear) {
            return 'Born today! 🎂';
          }
          if (months == 0) {
            return 'Now $days ${days == 1 ? 'day' : 'days'} old!';
          }
          if (days == 0) {
            return 'Now $months ${months == 1 ? 'month' : 'months'} old!';
          }
          return 'Now $months ${months == 1 ? 'month' : 'months'}, $days ${days == 1 ? 'day' : 'days'} old!';
        }
        return 'Turning 1 year';
      }

      if (daysUntil == 0) {
        final wasBornThisYear = clock.year == event.originalDate.year;
        if (age == 0 && wasBornThisYear) {
          return 'Born today! 🎂';
        }
        return nowYearsText(age + 1);
      }
      if (daysUntil == 1) {
        return 'Turning ${age + 1} tomorrow';
      }
      return 'Turning ${age + 1}';
    }

    final years = getYearsTogether(event, now: clock);
    final nextMilestone = years + 1;
    final daysUntil = getDaysUntil(event, now: clock);
    final ordinal = _ordinal(nextMilestone);
    if (daysUntil == 0) {
      return '$ordinal anniversary today!';
    }
    if (daysUntil == 1) {
      return '$ordinal anniversary tomorrow';
    }
    return '$ordinal anniversary';
  }

  static String _ordinal(int number) {
    if (number % 100 >= 11 && number % 100 <= 13) {
      return '${number}th';
    }
    switch (number % 10) {
      case 1:
        return '${number}st';
      case 2:
        return '${number}nd';
      case 3:
        return '${number}rd';
      default:
        return '${number}th';
    }
  }

  static int _yearsBeforeObservance(DateTime original, DateTime now) {
    final today = _dateOnly(now);
    final birth = _dateOnly(original);
    if (_sameDate(today, birth)) return 0;

    var years = today.year - birth.year;
    if (years <= 0) return 0;

    final observed = observedOn(today.year, birth.month, birth.day);
    if (_sameDate(today, observed) || today.isBefore(observed)) {
      years--;
    }
    return years;
  }

  static bool _isBeforeFirstBirthday(DateTime birth, DateTime today) {
    final first = observedOn(birth.year + 1, birth.month, birth.day);
    return today.isBefore(first);
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static bool _sameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
