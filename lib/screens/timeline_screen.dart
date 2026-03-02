import 'package:flutter/material.dart';
import '../models/event.dart';
import '../models/custom_event_type.dart';
import '../services/storage_service.dart';
import '../utils/event_calculator.dart';
import 'add_edit_event_screen.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  final StorageService _storage = StorageService();
  late PageController _pageController;
  List<Event> _events = [];
  bool _isLoading = true;
  int _currentPage = 0;
  
  // All 12 months for the perpetual calendar
  final List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  void initState() {
    super.initState();
    // Start on current month
    _currentPage = DateTime.now().month - 1;
    _pageController = PageController(initialPage: _currentPage);
    _initializeAndLoad();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _initializeAndLoad() async {
    try {
      await _storage.init();
      _loadEvents();
      _setupListener();
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setupListener() {
    _storage.watchEvents().listen((event) {
      if (mounted) _loadEvents();
    });
  }

  void _loadEvents() {
    if (mounted) {
      setState(() {
        _events = _storage.getAllEvents();
      });
    }
  }

  // Get events for a specific month (1-12)
  List<Event> _getEventsForMonth(int month) {
    return _events.where((event) {
      return event.originalDate.month == month;
    }).toList()
      ..sort((a, b) => a.originalDate.day.compareTo(b.originalDate.day));
  }

  int _getEventCountForMonth(int month) {
    return _events.where((e) => e.originalDate.month == month).length;
  }

  Future<void> _editEvent(Event event) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => AddEditEventScreen(event: event)),
    );
    if (result == true) _loadEvents();
  }

  Future<void> _addEvent() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => const AddEditEventScreen()),
    );
    if (result == true) _loadEvents();
  }

  void _goToMonth(int month) {
    _pageController.animateToPage(
      month,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header with month navigation
            _buildHeader(),
            // Month indicator dots
            _buildMonthDots(),
            // Swipeable month pages
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemCount: 12,
                itemBuilder: (context, index) {
                  return _buildMonthPage(index + 1);
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "timeline_fab",
        onPressed: _addEvent,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildHeader() {
    final eventCount = _getEventCountForMonth(_currentPage + 1);
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          // Previous month button
          IconButton(
            onPressed: _currentPage > 0 ? () => _goToMonth(_currentPage - 1) : null,
            icon: Icon(
              Icons.chevron_left_rounded,
              color: _currentPage > 0 
                  ? Theme.of(context).colorScheme.onSurface 
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  _months[_currentPage],
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '$eventCount event${eventCount != 1 ? 's' : ''}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Next month button
          IconButton(
            onPressed: _currentPage < 11 ? () => _goToMonth(_currentPage + 1) : null,
            icon: Icon(
              Icons.chevron_right_rounded,
              color: _currentPage < 11 
                  ? Theme.of(context).colorScheme.onSurface 
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthDots() {
    return Container(
      height: 24,
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(12, (index) {
          final isSelected = index == _currentPage;
          final hasEvents = _getEventCountForMonth(index + 1) > 0;
          
          return GestureDetector(
            onTap: () => _goToMonth(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isSelected ? 24 : 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: isSelected 
                    ? Theme.of(context).colorScheme.primary
                    : hasEvents
                        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMonthPage(int month) {
    final events = _getEventsForMonth(month);

    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_available_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
            ),
            const SizedBox(height: 16),
            Text(
              'No events in ${_months[month - 1]}',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Swipe to see other months',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      );
    }

    // Group events by day
    final groupedEvents = <int, List<Event>>{};
    for (final event in events) {
      final day = event.originalDate.day;
      groupedEvents.putIfAbsent(day, () => []).add(event);
    }
    final sortedDays = groupedEvents.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: sortedDays.length,
      itemBuilder: (context, index) {
        final day = sortedDays[index];
        final dayEvents = groupedEvents[day]!;
        final isToday = _isToday(month, day);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date badge
              Container(
                width: 56,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 56,
                      decoration: BoxDecoration(
                        color: isToday
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: !isToday ? Border.all(
                          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
                        ) : null,
                        boxShadow: isToday ? [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ] : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _getOrdinalSuffix(day),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isToday 
                                  ? Colors.white.withValues(alpha: 0.8) 
                                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                          Text(
                            '$day',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: isToday ? Colors.white : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Connector line
                    if (index < sortedDays.length - 1)
                      Container(
                        width: 2,
                        height: 24,
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Events list
              Expanded(
                child: Column(
                  children: dayEvents.map((event) => _buildEventCard(event, isToday)).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEventCard(Event event, bool isToday) {
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

    String milestoneText;
    String subtitleText;
    final daysUntil = EventCalculator.getDaysUntil(event);
    
    // Use custom event type templates if available
    if (customType != null) {
      final years = EventCalculator.getYearsTogether(event);
      final nextYears = years + 1;
      
      if (isToday) {
        milestoneText = customType.nowTextTemplate.replaceAll('{years}', nextYears.toString());
      } else {
        milestoneText = customType.turningTextTemplate.replaceAll('{years}', nextYears.toString());
      }
      subtitleText = "Since ${event.originalDate.year}";
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
          milestoneText = "Now ${age + 1} years old!";
        }
      } else {
        // For newborns, always say "Turning 1 year" instead of months
        if (babyAge != null) {
          milestoneText = "Turning 1 year";
        } else {
          milestoneText = "Turning ${age + 1}";
        }
      }
      subtitleText = "Born ${event.originalDate.year}";
    } else {
      final years = EventCalculator.getYearsTogether(event);
      if (isToday) {
        milestoneText = "${_ordinal(years + 1)} Anniversary!";
      } else {
        milestoneText = "${_ordinal(years + 1)} Anniversary";
      }
      subtitleText = "Since ${event.originalDate.year}";
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _editEvent(event),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: isToday ? BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                const Color(0xFF10B981).withValues(alpha: 0.1),
                Colors.transparent,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ) : null,
          child: Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  customType?.icon ?? (isBirthday ? Icons.cake_rounded : Icons.favorite_rounded),
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            milestoneText,
                            style: TextStyle(
                              fontSize: 11,
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          subtitleText,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Days until badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: daysUntil == 0
                      ? const Color(0xFF10B981).withValues(alpha: 0.12)
                      : daysUntil <= 7
                          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      daysUntil == 0 ? 'Today!' : '$daysUntil',
                      style: TextStyle(
                        fontSize: daysUntil == 0 ? 11 : 16,
                        fontWeight: FontWeight.w700,
                        color: daysUntil == 0
                            ? const Color(0xFF10B981)
                            : daysUntil <= 7
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    if (daysUntil > 0)
                      Text(
                        'days',
                        style: TextStyle(
                          fontSize: 10,
                          color: daysUntil <= 7
                              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.7)
                              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
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

  bool _isToday(int month, int day) {
    final now = DateTime.now();
    return now.month == month && now.day == day;
  }

  String _getOrdinalSuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1: return 'st';
      case 2: return 'nd';
      case 3: return 'rd';
      default: return 'th';
    }
  }

  String _ordinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    switch (n % 10) {
      case 1: return '${n}st';
      case 2: return '${n}nd';
      case 3: return '${n}rd';
      default: return '${n}th';
    }
  }
}
