import 'dart:async';

import 'package:flutter/material.dart';
import '../models/event.dart';
import '../services/storage_service.dart';
import '../theme/app_space.dart';
import '../utils/event_calculator.dart';
import '../widgets/event_card.dart';
import '../utils/user_message.dart';
import '../widgets/screen_status.dart';
import 'add_edit_event_screen.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  final StorageService _storage = StorageService();
  late PageController _pageController;
  StreamSubscription<dynamic>? _eventsSubscription;
  List<Event> _events = [];
  bool _isLoading = true;
  String? _error;
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
    _eventsSubscription?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _initializeAndLoad() async {
    try {
      await _storage.init();
      _loadEvents();
      _setupListener();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      debugPrint('Failed to load timeline: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = couldNot('load events');
        });
      }
    }
  }

  void _setupListener() {
    _eventsSubscription = _storage.watchEvents().listen((event) {
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
      return Scaffold(body: ScreenStatus.loading());
    }
    if (_error != null) {
      return Scaffold(
        body: ScreenStatus.error(title: _error!, onRetry: _initializeAndLoad),
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
        tooltip: 'Add event',
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
            tooltip: 'Previous month',
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
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
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
            tooltip: 'Next month',
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
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: AppSpace.touch,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 12,
        itemBuilder: (context, index) {
          final isSelected = index == _currentPage;
          final hasEvents = _getEventCountForMonth(index + 1) > 0;
          return Semantics(
            button: true,
            selected: isSelected,
            label: _months[index],
            child: InkWell(
              onTap: () => _goToMonth(index),
              child: SizedBox(
                width: AppSpace.touch,
                height: AppSpace.touch,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: isSelected ? AppSpace.lg : AppSpace.xs,
                    height: AppSpace.xs,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? scheme.primary
                          : hasEvents
                              ? scheme.primary.withValues(alpha: 0.45)
                              : scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(AppSpace.xs),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMonthPage(int month) {
    final events = _getEventsForMonth(month);

    if (events.isEmpty) {
      return ScreenStatus.empty(
        icon: Icons.event_available_rounded,
        title: 'No events in ${_months[month - 1]}',
        body: 'Swipe to see other months, or add someone.',
      );
    }

    // Same compact rows as Home. Earlier this month shows as passed rather
    // than "in 360 days".
    final now = DateTime.now();
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: events.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final event = events[index];
        final thisYear = EventCalculator.observedOn(now.year, month, event.originalDate.day);
        final passed = month == now.month &&
            thisYear.isBefore(DateTime(now.year, now.month, now.day)) &&
            (!EventCalculator.hasKnownYear(event) || event.originalDate.year <= now.year);
        return EventCard(
          event: event,
          passedOn: passed ? thisYear : null,
          onTap: () => _editEvent(event),
        );
      },
    );
  }



}
