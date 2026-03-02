import 'package:flutter/material.dart';
import '../models/event.dart';
import '../models/custom_event_type.dart';
import '../services/storage_service.dart';
import '../utils/event_calculator.dart';

class EventCard extends StatelessWidget {
  final Event event;
  final VoidCallback? onTap;

  const EventCard({
    super.key,
    required this.event,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final daysUntil = EventCalculator.getDaysUntil(event);
    final isToday = daysUntil == 0;
    final isTomorrow = daysUntil == 1;
    final isThisWeek = daysUntil <= 7;

    final isBirthday = event.eventType == EventType.birthday;
    
    // Get custom event type if applicable
    final storage = StorageService();
    CustomEventType? customType;
    if (event.customEventTypeId != null) {
      customType = storage.getCustomEventType(event.customEventTypeId!);
    }
    
    // Colors based on event type (custom type takes precedence)
    final primaryColor = customType != null
        ? customType.primaryColor
        : (isBirthday 
            ? const Color(0xFFF59E0B) // Amber for birthdays
            : const Color(0xFFEC4899)); // Pink for anniversaries
    
    final backgroundColor = customType != null
        ? customType.backgroundColor
        : (isBirthday
            ? const Color(0xFFFEF3C7) // Light amber
            : const Color(0xFFFCE7F3)); // Light pink
    
    final darkBackgroundColor = customType != null
        ? customType.primaryColor.withValues(alpha: 0.3)
        : (isBirthday
            ? const Color(0xFF78350F).withValues(alpha: 0.3)
            : const Color(0xFF831843).withValues(alpha: 0.3));

    // Urgency colors
    Color urgencyColor;
    String urgencyText;
    if (isToday) {
      // Special bright color for today - make it stand out!
      urgencyColor = isBirthday 
          ? const Color(0xFF10B981) // Bright green for birthdays
          : const Color(0xFFEC4899); // Bright pink for anniversaries
      urgencyText = "Today!";
    } else if (isTomorrow) {
      urgencyColor = const Color(0xFF3B82F6); // Blue
      urgencyText = "Tomorrow";
    } else if (isThisWeek) {
      urgencyColor = const Color(0xFF8B5CF6); // Purple
      urgencyText = "$daysUntil days";
    } else {
      urgencyColor = const Color(0xFF64748B); // Slate
      urgencyText = "$daysUntil days";
    }

    // Get age/milestone info
    String milestoneText;
    String currentText;
    
    // Use custom event type templates if available
    if (customType != null) {
      final years = EventCalculator.getYearsTogether(event);
      final nextYears = years + 1;
      
      if (isToday) {
        milestoneText = customType.nowTextTemplate.replaceAll('{years}', nextYears.toString());
        currentText = 'Today!';
      } else {
        milestoneText = customType.turningTextTemplate.replaceAll('{years}', nextYears.toString());
        currentText = customType.currentTextTemplate.replaceAll('{years}', years.toString());
      }
    } else if (isBirthday) {
      final age = EventCalculator.getAge(event);
      final babyAge = EventCalculator.getBabyAge(event);
      
      // Show months/days for babies under 1 year
      if (babyAge != null) {
        final months = babyAge['months']!;
        final days = babyAge['days']!;
        
        if (isToday) {
          // Special case: if born today (same year), show "Born today!"
          final now = DateTime.now();
          final wasBornThisYear = now.year == event.originalDate.year;
          if (months == 0 && days == 0 && wasBornThisYear) {
            milestoneText = "Born today! 🎂";
            currentText = "0 days old";
          } else {
            // On the birthday, show current age
            if (months == 0) {
              milestoneText = "Now $days ${days == 1 ? 'day' : 'days'} old!";
              currentText = "Birthday today! 🎉";
            } else if (days == 0) {
              milestoneText = "Now $months ${months == 1 ? 'month' : 'months'} old!";
              currentText = "Birthday today! 🎉";
            } else {
              milestoneText = "Now $months ${months == 1 ? 'month' : 'months'}, $days ${days == 1 ? 'day' : 'days'} old!";
              currentText = "Birthday today! 🎉";
            }
          }
        } else {
          // For "turning" text, always say "turning 1 year" for newborns
          // But keep current age showing months/days
          milestoneText = "Turning 1 year";
          if (months == 0) {
            currentText = "Currently $days ${days == 1 ? 'day' : 'days'} old";
          } else if (days == 0) {
            currentText = "Currently $months ${months == 1 ? 'month' : 'months'} old";
          } else {
            currentText = "Currently $months ${months == 1 ? 'month' : 'months'}, $days ${days == 1 ? 'day' : 'days'} old";
          }
        }
      } else {
        // For 1 year and older, use the existing logic
        if (isToday) {
          // Special case: if born today (same year), show "Born today!"
          final now = DateTime.now();
          final wasBornThisYear = now.year == event.originalDate.year;
          if (age == 0 && wasBornThisYear) {
            milestoneText = "Born today! 🎂";
            currentText = "0 years old";
          } else {
            // On the birthday, they are turning this age (age already represents completed years)
            milestoneText = "Now ${age + 1} years old!";
            currentText = "Birthday today! 🎉";
          }
        } else {
          final nextAge = age + 1;
          milestoneText = "Turning $nextAge";
          currentText = "Currently $age years old";
        }
      }
    } else {
      final years = EventCalculator.getYearsTogether(event);
      final nextMilestone = years + 1;
      if (isToday) {
        milestoneText = "${_ordinal(nextMilestone)} Anniversary!";
        currentText = "Anniversary today! 💕";
      } else {
        milestoneText = "${_ordinal(nextMilestone)} Anniversary";
        currentText = "$years years together";
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: isToday || isTomorrow
                ? LinearGradient(
                    colors: isToday
                        ? [
                            // More vibrant gradient for today
                            urgencyColor.withValues(alpha: isDark ? 0.3 : 0.2),
                            urgencyColor.withValues(alpha: isDark ? 0.15 : 0.1),
                            Colors.transparent,
                          ]
                        : [
                            urgencyColor.withValues(alpha: isDark ? 0.2 : 0.1),
                            Colors.transparent,
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            // Add a subtle border for today's events to make them stand out more
            border: isToday
                ? Border.all(
                    color: urgencyColor.withValues(alpha: 0.4),
                    width: 2,
                  )
                : null,
          ),
          child: Row(
            children: [
              // Event icon container
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: isDark ? darkBackgroundColor : backgroundColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Icon(
                    customType?.icon ?? (isBirthday ? Icons.cake_rounded : Icons.favorite_rounded),
                    color: primaryColor,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Event details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: isDark ? 0.2 : 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            milestoneText,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentText,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Days remaining badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: urgencyColor.withValues(alpha: isDark ? 0.3 : 0.2),
                  borderRadius: BorderRadius.circular(14),
                  border: isToday || isTomorrow
                      ? Border.all(
                          color: urgencyColor.withValues(alpha: 0.5),
                          width: isToday ? 2 : 1,
                        )
                      : null,
                  // Add a subtle glow effect for today
                  boxShadow: isToday
                      ? [
                          BoxShadow(
                            color: urgencyColor.withValues(alpha: 0.3),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  children: [
                    if (!isToday)
                      Text(
                        daysUntil.toString(),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: urgencyColor,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    Text(
                      urgencyText,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: urgencyColor,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _ordinal(int number) {
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
