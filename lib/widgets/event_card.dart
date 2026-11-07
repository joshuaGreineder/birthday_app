import 'package:flutter/material.dart';

import '../models/custom_event_type.dart';
import '../models/event.dart';
import '../services/storage_service.dart';
import '../theme/app_space.dart';
import '../theme/app_theme.dart';
import '../utils/event_calculator.dart';
import '../utils/yearless_date.dart';

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
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final daysUntil = EventCalculator.getDaysUntil(event);
    final isBirthday = event.eventType == EventType.birthday;
    final knownYear = EventCalculator.hasKnownYear(event);

    CustomEventType? customType;
    if (event.customEventTypeId != null) {
      customType = StorageService().getCustomEventType(event.customEventTypeId!);
    }

    final accent = customType == null
        ? EventPalette.accent(context, birthday: isBirthday)
        : scheme.onSurface;
    final iconColor = customType?.primaryColor ?? accent;

    final String milestone;
    final String detail;
    if (!knownYear) {
      milestone = customType?.name ?? (isBirthday ? 'Birthday' : 'Anniversary');
      detail = formatMonthDay(event.originalDate);
    } else if (customType != null) {
      final years = EventCalculator.getYearsTogether(event);
      final nextYears = years + 1;
      if (daysUntil == 0) {
        milestone = customType.nowTextTemplate.replaceAll('{years}', nextYears.toString());
        detail = 'Today';
      } else {
        milestone = customType.turningTextTemplate.replaceAll('{years}', nextYears.toString());
        detail = customType.currentTextTemplate.replaceAll('{years}', years.toString());
      }
    } else if (isBirthday) {
      final age = EventCalculator.getAge(event);
      final babyAge = EventCalculator.getBabyAge(event);
      if (babyAge != null) {
        final months = babyAge['months']!;
        final days = babyAge['days']!;
        if (daysUntil == 0) {
          final now = DateTime.now();
          final wasBornThisYear = now.year == event.originalDate.year;
          if (months == 0 && days == 0 && wasBornThisYear) {
            milestone = 'Born today!';
            detail = 'Birthday today';
          } else if (months == 0) {
            milestone = 'Now $days ${days == 1 ? 'day' : 'days'} old!';
            detail = 'Birthday today';
          } else if (days == 0) {
            milestone = 'Now $months ${months == 1 ? 'month' : 'months'} old!';
            detail = 'Birthday today';
          } else {
            milestone = 'Now $months ${months == 1 ? 'month' : 'months'}, $days ${days == 1 ? 'day' : 'days'} old!';
            detail = 'Birthday today';
          }
        } else {
          milestone = 'Turning 1 year';
          if (months == 0) {
            detail = 'Currently $days ${days == 1 ? 'day' : 'days'} old';
          } else if (days == 0) {
            detail = 'Currently $months ${months == 1 ? 'month' : 'months'} old';
          } else {
            detail = 'Currently $months ${months == 1 ? 'month' : 'months'}, $days ${days == 1 ? 'day' : 'days'} old';
          }
        }
      } else if (daysUntil == 0) {
        final now = DateTime.now();
        final wasBornThisYear = now.year == event.originalDate.year;
        if (age == 0 && wasBornThisYear) {
          milestone = 'Born today!';
          detail = 'Birthday today';
        } else {
          milestone = EventCalculator.nowYearsText(age + 1);
          detail = 'Birthday today';
        }
      } else {
        milestone = 'Turning ${age + 1}';
        detail = 'Currently $age years old';
      }
    } else {
      final years = EventCalculator.getYearsTogether(event);
      final nextMilestone = years + 1;
      milestone = daysUntil == 0
          ? '${_ordinal(nextMilestone)} Anniversary!'
          : '${_ordinal(nextMilestone)} Anniversary';
      detail = daysUntil == 0 ? 'Anniversary today' : '$years years together';
    }

    final when = daysUntil == 0
        ? 'Today'
        : daysUntil == 1
            ? 'Tomorrow'
            : 'In $daysUntil days';

    return Semantics(
      button: onTap != null,
      label: '${event.name}, ${event.displayGroup}, $milestone, $detail, $when',
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: AppSpace.xs),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpace.md),
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: AppSpace.touch,
                  height: AppSpace.touch,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppSpace.sm),
                  ),
                  child: Icon(
                    customType?.icon ?? (isBirthday ? Icons.cake_rounded : Icons.favorite_rounded),
                    color: iconColor,
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event.name, style: text.titleMedium),
                      Text(
                        event.displayGroup,
                        style: text.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: AppSpace.xxs),
                      Text(milestone, style: text.titleSmall?.copyWith(color: accent)),
                      Text(detail, style: text.bodyMedium),
                      const SizedBox(height: AppSpace.xs),
                      Text(when, style: text.titleSmall?.copyWith(color: scheme.primary)),
                    ],
                  ),
                ),
              ],
            ),
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
