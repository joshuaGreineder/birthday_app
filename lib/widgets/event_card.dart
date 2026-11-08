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

  /// Set when the row shows an occurrence that has already happened this year
  /// (Timeline, earlier this month). The row is dimmed and says "Passed".
  final DateTime? passedOn;

  const EventCard({
    super.key,
    required this.event,
    this.onTap,
    this.passedOn,
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

    String milestone;
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

    final next = passedOn ?? EventCalculator.getNextOccurrence(event);
    final past = passedOn != null;
    if (past) milestone = _pastMilestone(milestone, knownYear, isBirthday, customType != null);
    const weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final when = past
        ? 'Passed'
        : daysUntil == 0
            ? 'Today'
            : daysUntil == 1
                ? 'Tomorrow'
                : '$daysUntil days';
    final soon = !past && daysUntil <= 7;
    final hasGroup = event.group.trim().isNotEmpty;
    // At very large text the pill moves under the name so the name keeps its width.
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: !past && daysUntil == 0
            ? scheme.primary
            : soon
                ? scheme.primary.withValues(alpha: 0.12)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        when,
        style: text.labelLarge?.copyWith(
          color: !past && daysUntil == 0
              ? scheme.onPrimary
              : soon
                  ? scheme.primary
                  : scheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
    final subtitle = hasGroup ? '$milestone · ${event.displayGroup}' : milestone;

    // One scannable row: date | name + what's happening | countdown.
    return Semantics(
      button: onTap != null,
      label: '${event.name}, ${event.displayGroup}, $milestone, $detail, '
          '${formatMonthDay(next)}, ${past ? 'already passed this year' : daysUntil == 0 ? 'today' : 'in $daysUntil days'}',
      excludeSemantics: true,
      child: Opacity(
        opacity: past ? 0.6 : 1,
        child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpace.sm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpace.sm),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: AppSpace.xs),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: EventPalette.tint(context, iconColor),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          weekdays[next.weekday - 1],
                          style: text.labelSmall?.copyWith(
                            color: iconColor,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                        Text(
                          '${next.day}',
                          style: text.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(
                              customType?.icon ??
                                  (isBirthday ? Icons.cake_rounded : Icons.favorite_rounded),
                              size: 16,
                              color: iconColor,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                event.name,
                                maxLines: stacked ? 3 : 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: stacked ? 3 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        if (stacked) ...[
                          const SizedBox(height: 4),
                          pill,
                        ],
                      ],
                    ),
                  ),
                  if (!stacked) ...[
                    const SizedBox(width: AppSpace.sm),
                    pill,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }

  String _pastMilestone(String upcoming, bool knownYear, bool isBirthday, bool custom) {
    if (!knownYear || custom) return upcoming;
    final years = passedOn!.year - event.originalDate.year;
    if (isBirthday) return years <= 0 ? 'Born' : 'Turned $years';
    return '${_ordinal(years)} anniversary';
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
