import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/event.dart';
import '../utils/event_calculator.dart';
import '../models/custom_event_type.dart';
import '../services/storage_service.dart';

class CustomCalendar extends StatefulWidget {
  final DateTime selectedDate;
  final List<Event> events;
  final Function(DateTime) onDateSelected;

  const CustomCalendar({
    super.key,
    required this.selectedDate,
    required this.events,
    required this.onDateSelected,
  });

  @override
  State<CustomCalendar> createState() => _CustomCalendarState();
}

class _CustomCalendarState extends State<CustomCalendar> {
  late DateTime _currentMonth;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(widget.selectedDate.year, widget.selectedDate.month);
    _selectedDate = widget.selectedDate;
  }

  @override
  void didUpdateWidget(CustomCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDate != oldWidget.selectedDate) {
      _selectedDate = widget.selectedDate;
      _currentMonth = DateTime(widget.selectedDate.year, widget.selectedDate.month);
    }
  }

  List<DateTime> _getDaysInMonth() {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final firstDayOfWeek = firstDay.weekday;
    
    final days = <DateTime>[];
    
    // Add days from previous month
    for (int i = firstDayOfWeek - 1; i > 0; i--) {
      days.add(firstDay.subtract(Duration(days: i)));
    }
    
    // Add days of current month
    for (int i = 1; i <= lastDay.day; i++) {
      days.add(DateTime(_currentMonth.year, _currentMonth.month, i));
    }
    
    // Add days from next month to fill grid
    final remainingDays = 42 - days.length;
    for (int i = 1; i <= remainingDays; i++) {
      days.add(DateTime(_currentMonth.year, _currentMonth.month + 1, i));
    }
    
    return days;
  }

  List<Event> _getEventsForDate(DateTime date) {
    return EventCalculator.getEventsForDate(widget.events, date);
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool _isSelected(DateTime date) {
    return _selectedDate.year == date.year &&
        _selectedDate.month == date.month &&
        _selectedDate.day == date.day;
  }

  bool _isCurrentMonth(DateTime date) {
    return date.month == _currentMonth.month &&
        date.year == _currentMonth.year;
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
    widget.onDateSelected(date);
  }

  Color _getEventBackgroundColor(
    bool hasBirthday,
    bool hasAnniversary,
    List<CustomEventType> customTypes,
    bool isDark,
  ) {
    // If there are custom types, use the first custom type's background color (lighter color)
    // The backgroundColor is already calculated as a light color (primaryColor.withOpacity(0.15))
    // so we use it directly, just adjust slightly for dark mode
    if (customTypes.isNotEmpty) {
      final bgColor = customTypes.first.backgroundColor;
      // For dark mode, make it slightly more visible, but keep it light
      return isDark 
          ? bgColor.withValues(alpha: bgColor.a * 0.6)
          : bgColor;
    }
    
    // Otherwise use default colors
    if (hasBirthday && hasAnniversary) {
      return const Color(0xFFDDD6FE).withValues(alpha: isDark ? 0.3 : 1.0);
    } else if (hasBirthday) {
      return const Color(0xFFFEF3C7).withValues(alpha: isDark ? 0.3 : 1.0);
    } else if (hasAnniversary) {
      return const Color(0xFFFCE7F3).withValues(alpha: isDark ? 0.3 : 1.0);
    }
    
    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    final days = _getDaysInMonth();
    final monthName = DateFormat('MMMM yyyy').format(_currentMonth);
    final weekDays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(8),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Previous month',
                  icon: Icon(Icons.chevron_left_rounded, color: scheme.onSurface),
                  onPressed: _previousMonth,
                ),
                Expanded(
                  child: Text(
                    monthName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Next month',
                  icon: Icon(Icons.chevron_right_rounded, color: scheme.onSurface),
                  onPressed: _nextMonth,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: weekDays.map((day) {
                return Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
              ),
              itemCount: days.length,
              itemBuilder: (context, index) {
                final date = days[index];
                final isCurrentMonth = _isCurrentMonth(date);
                final isToday = _isToday(date);
                final isSelected = _isSelected(date);
                final events = _getEventsForDate(date);
                final hasEvents = events.isNotEmpty;
                final hasBirthday = events.any((e) => e.eventType == EventType.birthday && e.customEventTypeId == null);
                final hasAnniversary = events.any((e) => e.eventType == EventType.anniversary && e.customEventTypeId == null);
                
                // Get custom event types for this date
                final storage = StorageService();
                final customTypes = events
                    .where((e) => e.customEventTypeId != null)
                    .map((e) => storage.getCustomEventType(e.customEventTypeId!))
                    .whereType<CustomEventType>()
                    .toList();

                return GestureDetector(
                  onTap: () => _selectDate(date),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : isToday
                              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
                              : hasEvents
                                  ? _getEventBackgroundColor(
                                      hasBirthday,
                                      hasAnniversary,
                                      customTypes,
                                      isDark,
                                    )
                                  : null,
                      borderRadius: BorderRadius.circular(12),
                      border: isToday && !isSelected
                          ? Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            )
                          : null,
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Text(
                            '${date.day}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : isCurrentMonth
                                          ? Theme.of(context).colorScheme.onSurface
                                          : Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontWeight: isToday || isSelected || hasEvents
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                          ),
                        ),
                        if (hasEvents && !isSelected)
                          Positioned(
                            bottom: 4,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (hasBirthday)
                                  Container(
                                    width: 6,
                                    height: 6,
                                    margin: const EdgeInsets.symmetric(horizontal: 1),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFF59E0B),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                if (hasAnniversary)
                                  Container(
                                    width: 6,
                                    height: 6,
                                    margin: const EdgeInsets.symmetric(horizontal: 1),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFEC4899),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                // Show custom event type indicators
                                ...customTypes.take(2).map((customType) => Container(
                                      width: 6,
                                      height: 6,
                                      margin: const EdgeInsets.symmetric(horizontal: 1),
                                      decoration: BoxDecoration(
                                        color: customType.primaryColor,
                                        shape: BoxShape.circle,
                                      ),
                                    )),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
            ),
          ),
        );
      },
    );
  }
}
