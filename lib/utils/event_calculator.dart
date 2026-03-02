import '../models/event.dart';

class EventCalculator {
  /// Calculate the next occurrence of an event
  static DateTime getNextOccurrence(Event event) {
    final now = DateTime.now();
    final originalDate = event.originalDate;
    
    // Get today's date without time for comparison
    final today = DateTime(now.year, now.month, now.day);
    
    // Get the date for this year
    var nextDate = DateTime(
      now.year,
      originalDate.month,
      originalDate.day,
    );
    
    // If the date has already passed this year (comparing dates only, not times), move to next year
    if (nextDate.isBefore(today)) {
      nextDate = DateTime(
        now.year + 1,
        originalDate.month,
        originalDate.day,
      );
    }
    
    // Handle February 29 for non-leap years
    if (originalDate.month == 2 && originalDate.day == 29) {
      if (!_isLeapYear(nextDate.year)) {
        // Use February 28 for non-leap years
        nextDate = DateTime(nextDate.year, 2, 28);
      }
    }
    
    return nextDate;
  }

  /// Calculate days until the next occurrence
  static int getDaysUntil(Event event) {
    final nextOccurrence = getNextOccurrence(event);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final nextDate = DateTime(
      nextOccurrence.year,
      nextOccurrence.month,
      nextOccurrence.day,
    );
    
    return nextDate.difference(today).inDays;
  }

  /// Get months and days for babies under 1 year old
  /// Returns a map with 'months' and 'days' keys, or null if 1 year or older
  static Map<String, int>? getBabyAge(Event event) {
    if (event.eventType != EventType.birthday) {
      return null;
    }
    
    final now = DateTime.now();
    final birthDate = event.originalDate;
    final age = getAge(event);
    
    // Only calculate months/days if under 1 year old
    if (age > 0) {
      return null;
    }
    
    // Calculate the difference
    final today = DateTime(now.year, now.month, now.day);
    final birth = DateTime(birthDate.year, birthDate.month, birthDate.day);
    
    // If it's the exact birth day, return 0 months, 0 days
    if (today.year == birth.year && today.month == birth.month && today.day == birth.day) {
      return {'months': 0, 'days': 0};
    }
    
    // Calculate months
    int months = (now.year - birthDate.year) * 12 + (now.month - birthDate.month);
    
    // Adjust if the day hasn't occurred yet this month
    if (now.day < birthDate.day) {
      months--;
    }
    
    // Calculate days remaining in the current month
    int days;
    if (now.day >= birthDate.day) {
      // Days since the birth day this month
      days = now.day - birthDate.day;
    } else {
      // Need to calculate days from the birth day of the previous month
      // Get the last month's date with the birth day
      DateTime lastMonthDate;
      if (now.month == 1) {
        lastMonthDate = DateTime(now.year - 1, 12, birthDate.day);
      } else {
        lastMonthDate = DateTime(now.year, now.month - 1, birthDate.day);
      }
      days = today.difference(lastMonthDate).inDays;
    }
    
    return {'months': months, 'days': days};
  }

  /// Get current age for birthdays
  /// Returns the age the person has completed (before their birthday)
  /// On the birthday itself, returns the age they've completed (so age + 1 is what they're turning)
  /// If born today, returns 0 (they're 0 years old, not turning 1 yet)
  static int getAge(Event event) {
    if (event.eventType != EventType.birthday) {
      return 0;
    }
    
    final now = DateTime.now();
    final birthDate = event.originalDate;
    
    // Compare dates only (ignore time)
    final today = DateTime(now.year, now.month, now.day);
    final birthdayThisYear = DateTime(now.year, birthDate.month, birthDate.day);
    
    int age = now.year - birthDate.year;
    
    // If born this year (same year), they're 0 years old
    if (age == 0) {
      return 0;
    }
    
    // If today IS the birthday, they've completed (age - 1) years
    // Example: born 2024, today 2025 on birthday = completed 0 years, turning 1
    if (today.year == birthdayThisYear.year &&
        today.month == birthdayThisYear.month &&
        today.day == birthdayThisYear.day) {
      return age - 1;
    }
    
    // Adjust if birthday hasn't occurred yet this year
    // If today is before the birthday, subtract 1
    if (today.isBefore(birthdayThisYear)) {
      age--;
    }
    
    // Handle February 29
    if (birthDate.month == 2 && birthDate.day == 29) {
      if (!_isLeapYear(now.year) && now.month == 2 && now.day == 28) {
        // On Feb 28 of non-leap year, consider it the birthday
        return age;
      } else if (!_isLeapYear(now.year) && now.month == 2 && now.day < 28) {
        age--;
      }
    }
    
    return age;
  }

  /// Get years together for anniversaries and custom events
  /// Returns the years completed (before the anniversary/event)
  /// On the event itself, returns the years completed (so years + 1 is the milestone)
  static int getYearsTogether(Event event) {
    // For birthdays, use getAge instead
    if (event.eventType == EventType.birthday) {
      return getAge(event);
    }
    
    // For anniversaries and custom events, calculate years from original date
    final now = DateTime.now();
    final startDate = event.originalDate;
    
    // Compare dates only (ignore time)
    final today = DateTime(now.year, now.month, now.day);
    final eventThisYear = DateTime(now.year, startDate.month, startDate.day);
    
    int years = now.year - startDate.year;
    
    // If started this year (same year), they're at 0 years
    if (years == 0) {
      return 0;
    }
    
    // If today IS the event, they've completed (years - 1) years
    // Example: started 2023, today 2025 on event = completed 1 year, celebrating 2nd
    if (today.year == eventThisYear.year &&
        today.month == eventThisYear.month &&
        today.day == eventThisYear.day) {
      return years - 1;
    }
    
    // Adjust if event hasn't occurred yet this year
    // If today is before the event, subtract 1
    if (today.isBefore(eventThisYear)) {
      years--;
    }
    
    // Handle February 29
    if (startDate.month == 2 && startDate.day == 29) {
      if (!_isLeapYear(now.year) && now.month == 2 && now.day == 28) {
        return years;
      } else if (!_isLeapYear(now.year) && now.month == 2 && now.day < 28) {
        years--;
      }
    }
    
    return years;
  }

  /// Get upcoming events sorted by next occurrence
  static List<Event> getUpcomingEvents(List<Event> events) {
    if (events.isEmpty) return [];
    
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    
    final upcoming = events.where((event) {
      try {
        final next = getNextOccurrence(event);
        final nextDate = DateTime(next.year, next.month, next.day);
        return nextDate.isAfter(todayDate) || nextDate.isAtSameMomentAs(todayDate);
      } catch (e) {
        return false;
      }
    }).toList();
    
    upcoming.sort((a, b) {
      try {
        final nextA = getNextOccurrence(a);
        final nextB = getNextOccurrence(b);
        return nextA.compareTo(nextB);
      } catch (e) {
        return 0;
      }
    });
    
    return upcoming;
  }

  /// Get events for a specific date
  static List<Event> getEventsForDate(List<Event> events, DateTime date) {
    return events.where((event) {
      final original = event.originalDate;
      return original.month == date.month && original.day == date.day;
    }).toList();
  }

  /// Check if a year is a leap year
  static bool _isLeapYear(int year) {
    return (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
  }

  /// Get the age/milestone text for display
  static String getAgeText(Event event) {
    if (event.eventType == EventType.birthday) {
      final age = getAge(event);
      final daysUntil = getDaysUntil(event);
      final babyAge = getBabyAge(event);
      
      // Show months/days for babies under 1 year
      if (babyAge != null) {
        final months = babyAge['months']!;
        final days = babyAge['days']!;
        
        if (daysUntil == 0) {
          // Special case: if born today (same year), show "Born today!"
          final now = DateTime.now();
          final wasBornThisYear = now.year == event.originalDate.year;
          if (months == 0 && days == 0 && wasBornThisYear) {
            return "Born today! 🎂";
          }
          // On the birthday, show current age
          if (months == 0) {
            return "Now $days ${days == 1 ? 'day' : 'days'} old!";
          } else if (days == 0) {
            return "Now $months ${months == 1 ? 'month' : 'months'} old!";
          } else {
            return "Now $months ${months == 1 ? 'month' : 'months'}, $days ${days == 1 ? 'day' : 'days'} old!";
          }
        } else {
          // For "turning" text, always say "turning 1 year" for newborns
          // But show current age in months/days
          return "Turning 1 year";
        }
      }
      
      // For 1 year and older, use the existing logic
      if (daysUntil == 0) {
        // Special case: if born today (same year), show "Born today!"
        final now = DateTime.now();
        final wasBornThisYear = now.year == event.originalDate.year;
        if (age == 0 && wasBornThisYear) {
          return "Born today! 🎂";
        }
        // On the birthday, they are now that age
        return "Now ${age + 1} years old!";
      } else if (daysUntil == 1) {
        final nextAge = age + 1;
        return "Turning $nextAge tomorrow";
      } else {
        final nextAge = age + 1;
        return "Turning $nextAge";
      }
    } else {
      final years = getYearsTogether(event);
      final nextMilestone = years + 1;
      final daysUntil = getDaysUntil(event);
      
      if (daysUntil == 0) {
        // On the anniversary, they are now at that milestone
        return "${_ordinal(nextMilestone)} anniversary today!";
      } else if (daysUntil == 1) {
        return "${_ordinal(nextMilestone)} anniversary tomorrow";
      } else {
        return "${_ordinal(nextMilestone)} anniversary";
      }
    }
  }

  /// Get ordinal suffix (1st, 2nd, 3rd, etc.)
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
}

