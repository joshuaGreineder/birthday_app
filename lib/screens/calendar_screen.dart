import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/event.dart';
import '../models/custom_event_type.dart';
import '../services/storage_service.dart';
import '../utils/event_calculator.dart';
import '../widgets/custom_calendar.dart';
import 'add_edit_event_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final StorageService _storage = StorageService();
  List<Event> _events = [];
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeAndLoad();
  }

  Future<void> _initializeAndLoad() async {
    try {
      await _storage.init();
      _loadEvents();
      _setupListener();
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _setupListener() {
    _storage.watchEvents().listen((event) {
      _loadEvents();
    });
  }

  void _loadEvents() {
    setState(() {
      _events = _storage.getAllEvents();
    });
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
  }

  Future<void> _addEvent() async {
    final result = await Navigator.of(context).push<bool>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const AddEditEventScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );

    if (result == true) {
      _loadEvents();
    }
  }

  Future<void> _editEvent(Event event) async {
    final result = await Navigator.of(context).push<bool>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            AddEditEventScreen(event: event),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );

    if (result == true) {
      _loadEvents();
    }
  }

  List<Event> _getEventsForSelectedDate() {
    return EventCalculator.getEventsForDate(_events, _selectedDate);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

    final eventsForDate = _getEventsForSelectedDate();
    final formattedDate = DateFormat('MMMM d, yyyy').format(_selectedDate);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                'Calendar',
                style: Theme.of(context).appBarTheme.titleTextStyle,
              ),
            ),
            // Calendar widget
            Expanded(
              flex: 3,
              child: CustomCalendar(
                selectedDate: _selectedDate,
                events: _events,
                onDateSelected: _onDateSelected,
              ),
            ),
            // Events section
            Expanded(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag handle indicator
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.event_rounded,
                              color: Theme.of(context).colorScheme.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  formattedDate,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                Text(
                                  '${eventsForDate.length} event${eventsForDate.length != 1 ? 's' : ''}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.5),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: eventsForDate.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.event_available_rounded,
                                    size: 48,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.2),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No events on this date',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.4),
                                        ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              itemCount: eventsForDate.length,
                              itemBuilder: (context, index) {
                                final event = eventsForDate[index];
                                return _buildEventTile(event);
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "calendar_fab",
        onPressed: _addEvent,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildEventTile(Event event) {
    final isBirthday = event.eventType == EventType.birthday;
    
    // Get custom event type if applicable
    final storage = StorageService();
    CustomEventType? customType;
    if (event.customEventTypeId != null) {
      customType = storage.getCustomEventType(event.customEventTypeId!);
    }
    
    // Colors based on event type (custom type takes precedence)
    final color = customType != null
        ? customType.primaryColor
        : (isBirthday ? const Color(0xFFF59E0B) : const Color(0xFFEC4899));
    
    final daysUntil = EventCalculator.getDaysUntil(event);
    final isToday = daysUntil == 0;

    String milestoneText;
    
    // Use custom event type templates if available
    if (customType != null) {
      final years = EventCalculator.getYearsTogether(event);
      final nextYears = years + 1;
      
      if (isToday) {
        milestoneText = customType.nowTextTemplate.replaceAll('{years}', nextYears.toString());
      } else {
        milestoneText = customType.turningTextTemplate.replaceAll('{years}', nextYears.toString());
      }
    } else if (isBirthday) {
      final age = EventCalculator.getAge(event);
      final babyAge = EventCalculator.getBabyAge(event);
      
      if (isToday) {
        // Special case: if born today (same year), show "Born today!"
        final now = DateTime.now();
        final wasBornThisYear = now.year == event.originalDate.year;
        if (age == 0 && wasBornThisYear) {
          milestoneText = "Born today! 🎂";
        } else {
          // On the birthday, they are now that age
          milestoneText = EventCalculator.nowYearsText(age + 1);
        }
      } else {
        // For newborns, always say "Turning 1 year" instead of months
        if (babyAge != null) {
          milestoneText = "Turning 1 year";
        } else {
          milestoneText = "Turning ${age + 1}";
        }
      }
    } else {
      final years = EventCalculator.getYearsTogether(event);
      if (isToday) {
        milestoneText = "${years + 1} years today!";
      } else {
        milestoneText = "${years + 1} years";
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () => _editEvent(event),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    customType?.icon ?? (isBirthday ? Icons.cake_rounded : Icons.favorite_rounded),
                    color: color,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      milestoneText,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
