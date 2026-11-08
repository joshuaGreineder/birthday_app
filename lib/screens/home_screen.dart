import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../app_config.dart';
import '../models/event.dart';
import '../models/custom_event_type.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/google_calendar_service.dart';
import '../services/widget_service.dart';
import '../widgets/permission_prompts.dart';
import '../theme/app_space.dart';
import '../theme/app_theme.dart';
import '../utils/event_calculator.dart';
import '../utils/user_message.dart';
import '../widgets/event_card.dart';
import '../widgets/screen_status.dart';
import 'add_edit_event_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final StorageService _storage = StorageService();
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription<dynamic>? _eventsSubscription;
  List<Event> _allEvents = [];
  List<Event> _upcomingEvents = [];
  List<Event> _filteredEvents = [];
  bool _isLoading = true;
  bool _remindersBlocked = false;
  String? _error;
  String _filterType = 'all'; // all, birthday, anniversary, or custom event type ID
  String _groupFilter = 'all'; // all, or a display group such as Ungrouped
  int _timeRange = 365; // days: 7, 30, 90, 180, 365 (all)
  bool _showSearch = false;
  List<CustomEventType> _customEventTypes = [];

  // Time range options
  final List<Map<String, dynamic>> _timeRangeOptions = [
    {'value': 365, 'label': 'All', 'shortLabel': 'All'},
    {'value': 7, 'label': 'This Week', 'shortLabel': '7d'},
    {'value': 30, 'label': 'This Month', 'shortLabel': '30d'},
    {'value': 90, 'label': '3 Months', 'shortLabel': '90d'},
    {'value': 180, 'label': '6 Months', 'shortLabel': '6mo'},
  ];

  @override
  void initState() {
    super.initState();
    _initializeAndLoad();
  }

  @override
  void dispose() {
    _eventsSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshReminderAccess() async {
    if (kIsWeb) return;
    try {
      final enabled = _storage.getNotificationsEnabled();
      final access = await NotificationService().notificationAccess();
      final blocked = enabled &&
          access != NotificationAccess.granted &&
          access != NotificationAccess.unavailable;
      if (mounted) setState(() => _remindersBlocked = blocked);
    } catch (e) {
      debugPrint('Reminder access check failed: $e');
    }
  }

  Future<void> _allowReminders() async {
    final result = await requestNotificationsWithExplanation(context);
    if (!mounted) return;
    if (result == PermissionPromptResult.granted) {
      await _storage.saveSetting('notificationsEnabled', true);
      await NotificationService().scheduleDailyNotifications();
    } else if (result == PermissionPromptResult.dismissed) {
      await _storage.saveSetting('notificationsEnabled', false);
      await NotificationService().cancelAllNotifications();
    }
    await _refreshReminderAccess();
  }

  Future<void> _initializeAndLoad() async {
    try {
      // Storage init is idempotent (checks if already initialized)
      await _storage.init();
      
      // Load saved filters
      _filterType = _storage.getFilterType();
      _groupFilter = _storage.getGroupFilter();
      _timeRange = _storage.getTimeRange();
      
      // Load custom event types
      _customEventTypes = _storage.getAllCustomEventTypes();
      
      await _loadEvents();
      _setupListener();
      await _refreshReminderAccess();
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Failed to load events: $e');
      if (mounted) {
        setState(() {
          _error = couldNot('load events');
          _isLoading = false;
        });
      }
    }
  }

  void _setupListener() {
    _eventsSubscription = _storage.watchEvents().listen((event) {
      if (mounted) {
        _loadEvents(); // Fire and forget - don't await in stream listener
      }
    });
  }

  Future<void> _loadEvents() async {
    final events = _storage.getAllEvents();
    if (mounted) {
      setState(() {
        _allEvents = events;
        _upcomingEvents = EventCalculator.getUpcomingEvents(events);
        // Reload custom event types in case they changed
        final newCustomTypes = _storage.getAllCustomEventTypes();
        _customEventTypes = newCustomTypes;
        
        // If the current filter is a custom event type that no longer exists, reset to 'all'
        if (_filterType != 'all' && 
            _filterType != 'birthday' && 
            _filterType != 'anniversary' &&
            !newCustomTypes.any((t) => t.id == _filterType)) {
          _filterType = 'all';
          _storage.setFilterType('all');
        }
        
        _applyFilters();
      });
      // Update widget data in background (non-blocking)
      WidgetService.updateWidgetData().catchError((e) {
        debugPrint('Error updating widget data: $e');
      });
    }
  }

  void _applyFilters() {
    var filtered = _upcomingEvents;
    
    // Apply time range filter
    if (_timeRange < 365) {
      filtered = filtered.where((e) => EventCalculator.getDaysUntil(e) <= _timeRange).toList();
    }
    
    // Apply type filter
    if (_filterType == 'birthday') {
      filtered = filtered.where((e) => 
        e.eventType == EventType.birthday && e.customEventTypeId == null
      ).toList();
    } else if (_filterType == 'anniversary') {
      filtered = filtered.where((e) => 
        e.eventType == EventType.anniversary && e.customEventTypeId == null
      ).toList();
    } else if (_filterType != 'all') {
      // Custom event type filter
      filtered = filtered.where((e) => 
        e.customEventTypeId == _filterType
      ).toList();
    }
    
    if (_groupFilter != 'all') {
      filtered = filtered.where((e) => e.displayGroup == _groupFilter).toList();
    }

    // Apply search filter
    final searchQuery = _searchController.text.toLowerCase().trim();
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((e) => 
        e.name.toLowerCase().contains(searchQuery) ||
        e.group.toLowerCase().contains(searchQuery) ||
        (e.notes?.toLowerCase().contains(searchQuery) ?? false)
      ).toList();
    }
    
    setState(() {
      _filteredEvents = filtered;
    });
  }

  Future<void> _addEvent() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => const AddEditEventScreen()),
    );
    if (result == true) await _loadEvents();
  }

  Future<void> _editEvent(Event event) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => AddEditEventScreen(event: event)),
    );
    if (result == true) await _loadEvents();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(body: ScreenStatus.loading());
    }

    if (_error != null) {
      return Scaffold(
        body: ScreenStatus.error(
          title: _error!,
          onRetry: _initializeAndLoad,
        ),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // App bar with search toggle
          SliverAppBar(
            pinned: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            toolbarHeight: _toolbarHeight(context),
            title: _showSearch
                ? TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search events',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: IconButton(
                        tooltip: 'Close search',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _showSearch = false);
                          _applyFilters();
                        },
                      ),
                    ),
                    onChanged: (value) => _applyFilters(),
                  )
                : Text(kAppDisplayName, style: Theme.of(context).textTheme.headlineSmall),
            actions: _showSearch
                ? null
                : [
                    IconButton(
                      tooltip: 'Search events',
                      icon: const Icon(Icons.search_rounded),
                      onPressed: () => setState(() => _showSearch = true),
                    ),
                  ],
          ),
          if (_remindersBlocked)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Material(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reminders will not fire until notifications are allowed.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _allowReminders,
                            child: const Text('Allow notifications'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (_upcomingEvents.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 120),
              sliver: SliverToBoxAdapter(child: _buildEmptyState()),
            )
          else ...[
            // Stats row
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.xs, AppSpace.md, AppSpace.sm),
                child: _buildStatsRow(),
              ),
            ),
            // Filters: two single-line rows that scroll sideways instead of wrapping.
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.xs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _chipRow([
                      _buildFilterChip('All', 'all', null),
                      _buildFilterChip('Birthdays', 'birthday', Icons.cake_rounded),
                      _buildFilterChip('Anniversaries', 'anniversary', Icons.favorite_rounded),
                      ..._customEventTypes.map(
                        (customType) => _buildFilterChip(customType.name, customType.id, customType.icon),
                      ),
                      _chipDivider(),
                      ..._timeRangeOptions.map(_buildTimeChip),
                    ]),
                    const SizedBox(height: AppSpace.xs),
                    _chipRow([
                      _buildGroupChip('All groups', 'all'),
                      ..._groupNames.map((name) => _buildGroupChip(name, name)),
                    ]),
                  ],
                ),
              ),
            ),
            // Results count
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Row(
                  children: [
                    Text(
                      '${_filteredEvents.length} event${_filteredEvents.length != 1 ? 's' : ''}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_timeRange < 365 || _filterType != 'all' || _groupFilter != 'all') ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _buildActiveFiltersText(),
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Event list
            if (_filteredEvents.isEmpty)
              SliverFillRemaining(
                        child: ScreenStatus.empty(
                  icon: Icons.search_off_rounded,
                  title: 'No events in this range',
                  body: 'Clear the filters to see every upcoming event.',
                  actionLabel: 'Clear filters',
                  onAction: () {
                    setState(() {
                      _timeRange = 365;
                      _filterType = 'all';
                      _groupFilter = 'all';
                    });
                    _storage.setTimeRange(365);
                    _storage.setFilterType('all');
                    _storage.setGroupFilter('all');
                    _applyFilters();
                  },
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final row = _listRows[index];
                      if (row is String) return _buildMonthHeader(row);
                      final event = row as Event;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Dismissible(
                        key: Key(event.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.error,
                            borderRadius: BorderRadius.circular(AppSpace.sm),
                          ),
                          child: Icon(Icons.delete_rounded, color: Theme.of(context).colorScheme.onError),
                        ),
                        confirmDismiss: (direction) async {
                          return await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              title: const Text('Delete Event'),
                              content: Text('Delete "${event.name}"?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Theme.of(context).colorScheme.error,
                                    foregroundColor: Theme.of(context).colorScheme.onError,
                                  ),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                        },
                        onDismissed: (direction) async {
                          await _storage.deleteEvent(event.id);
                          await _loadEvents();
                          // Drop the deleted event's reminders and calendar entry.
                          if (_storage.getNotificationsEnabled()) {
                            NotificationService().scheduleDailyNotifications();
                          }
                          GoogleCalendarService().syncInBackground();
                        },
                        child: EventCard(
                          event: event,
                          onTap: () => _editEvent(event),
                        ),
                        ),
                      );
                    },
                    childCount: _listRows.length,
                  ),
                ),
              ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: "home_fab",
        tooltip: 'Add event',
        onPressed: _addEvent,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Event'),
      ),
    );
  }

  String _buildActiveFiltersText() {
    final parts = <String>[];
    if (_timeRange < 365) {
      final option = _timeRangeOptions.firstWhere((o) => o['value'] == _timeRange);
      parts.add(option['shortLabel']);
    }
    if (_groupFilter != 'all') {
      parts.add(_groupFilter);
    }
    if (_filterType != 'all') {
      if (_filterType == 'birthday') {
        parts.add('Birthdays');
      } else if (_filterType == 'anniversary') {
        parts.add('Anniversaries');
      } else {
        // Custom event type
        final customType = _customEventTypes.firstWhere(
          (t) => t.id == _filterType,
          orElse: () => CustomEventType(
            id: '', 
            name: '', 
            primaryColorValue: Colors.blue.toARGB32(),
            backgroundColorValue: Colors.lightBlue.toARGB32(),
            iconCodePoint: Icons.event_rounded.codePoint,
            turningTextTemplate: '',
            nowTextTemplate: '',
            currentTextTemplate: '',
          ),
        );
        if (customType.id.isNotEmpty) {
          parts.add(customType.name);
        }
      }
    }
    return parts.join(' · ');
  }

  static const List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  /// Filtered events with a month heading before each new month.
  List<Object> get _listRows {
    final rows = <Object>[];
    String? current;
    final thisYear = DateTime.now().year;
    for (final event in _filteredEvents) {
      final next = EventCalculator.getNextOccurrence(event);
      final heading = next.year == thisYear
          ? _monthNames[next.month - 1]
          : '${_monthNames[next.month - 1]} ${next.year}';
      if (heading != current) {
        rows.add(heading);
        current = heading;
      }
      rows.add(event);
    }
    return rows;
  }

  Widget _buildMonthHeader(String title) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, AppSpace.sm, 4, 6),
      child: Semantics(
        header: true,
        child: Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
        ),
      ),
    );
  }

  Widget _chipRow(List<Widget> chips) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
      child: Row(
        children: [
          for (var i = 0; i < chips.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpace.xs),
            chips[i],
          ],
        ],
      ),
    );
  }

  Widget _chipDivider() {
    return Container(
      width: 1,
      height: 24,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }

  Widget _buildTimeChip(Map<String, dynamic> option) {
    final value = option['value'] as int;
    final selected = _timeRange == value;
    final scheme = Theme.of(context).colorScheme;
    const labels = {365: 'Any time', 7: '7 days', 30: '30 days', 90: '3 months', 180: '6 months'};
    return ChoiceChip(
      label: Text(labels[value] ?? option['label'] as String),
      selected: selected,
      onSelected: (next) {
        if (!next) return;
        setState(() => _timeRange = value);
        _storage.setTimeRange(_timeRange);
        _applyFilters();
      },
      selectedColor: scheme.secondaryContainer,
      labelStyle: TextStyle(
        color: selected ? scheme.onSecondaryContainer : scheme.onSurface,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      ),
      showCheckmark: false,
    );
  }

  Widget _buildFilterChip(String label, String value, IconData? icon) {
    final isSelected = _filterType == value;
    final scheme = Theme.of(context).colorScheme;
    return FilterChip(
      avatar: icon == null
          ? null
          : Icon(
              icon,
              color: isSelected ? scheme.onPrimary : scheme.onSurfaceVariant,
            ),
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _filterType = value);
        _storage.setFilterType(_filterType);
        _applyFilters();
      },
      selectedColor: Theme.of(context).colorScheme.primary,
      labelStyle: TextStyle(
        color: isSelected
            ? Theme.of(context).colorScheme.onPrimary
            : Theme.of(context).colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
      ),
      checkmarkColor: Theme.of(context).colorScheme.onPrimary,
      showCheckmark: false,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  /// One quiet line of totals: "37 birthdays · 6 anniversaries · 3 this week".
  Widget _buildStatsRow() {
    final birthdays = _allEvents.where((e) => e.eventType == EventType.birthday).length;
    final anniversaries = _allEvents.where((e) => e.eventType == EventType.anniversary).length;
    final thisWeek = _upcomingEvents.where((e) => EventCalculator.getDaysUntil(e) <= 7).length;
    return Wrap(
      spacing: AppSpace.md,
      runSpacing: AppSpace.xs,
      children: [
        _buildStat(Icons.cake_rounded, birthdays, birthdays == 1 ? 'birthday' : 'birthdays',
            EventPalette.accent(context, birthday: true)),
        _buildStat(Icons.favorite_rounded, anniversaries,
            anniversaries == 1 ? 'anniversary' : 'anniversaries',
            EventPalette.accent(context, birthday: false)),
        _buildStat(Icons.notifications_active_rounded, thisWeek, 'this week',
            Theme.of(context).colorScheme.primary),
      ],
    );
  }

  Widget _buildStat(IconData icon, int value, String label, Color color) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Semantics(
      label: '$value $label',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text('$value', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(label, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupChip(String label, String value) {
    final selected = _groupFilter == value;
    final scheme = Theme.of(context).colorScheme;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (next) {
        if (!next && selected) return;
        setState(() => _groupFilter = value);
        _storage.setGroupFilter(value);
        _applyFilters();
      },
      selectedColor: scheme.secondaryContainer,
      labelStyle: TextStyle(
        color: selected ? scheme.onSecondaryContainer : scheme.onSurface,
      ),
      showCheckmark: false,
    );
  }

  List<String> get _groupNames {
    final names = _allEvents.map((event) => event.displayGroup).toSet().toList()..sort();
    return names;
  }

  double _toolbarHeight(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return AppSpace.touch + (24 * scale);
  }

  Widget _buildEmptyState() {
    return ScreenStatus.empty(
      icon: Icons.celebration_rounded,
      title: 'No events yet',
      body: 'Add birthdays and anniversaries so the next one is easy to find.',
      actionLabel: 'Add First Event',
      onAction: _addEvent,
    );
  }
}
