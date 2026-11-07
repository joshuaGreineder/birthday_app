import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../app_config.dart';
import '../models/event.dart';
import '../models/custom_event_type.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/widget_service.dart';
import '../widgets/permission_prompts.dart';
import '../utils/event_calculator.dart';
import '../widgets/event_card.dart';
import 'add_edit_event_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final StorageService _storage = StorageService();
  final TextEditingController _searchController = TextEditingController();
  List<Event> _allEvents = [];
  List<Event> _upcomingEvents = [];
  List<Event> _filteredEvents = [];
  bool _isLoading = true;
  bool _remindersBlocked = false;
  String? _error;
  String _filterType = 'all'; // all, birthday, anniversary, or custom event type ID
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
      _timeRange = _storage.getTimeRange();
      
      // Load custom event types
      _customEventTypes = _storage.getAllCustomEventTypes();
      
      await _loadEvents();
      _setupListener();
      await _refreshReminderAccess();
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _setupListener() {
    _storage.watchEvents().listen((event) {
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
    
    // Apply search filter
    final searchQuery = _searchController.text.toLowerCase().trim();
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((e) => 
        e.name.toLowerCase().contains(searchQuery) ||
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
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'Loading events...',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $_error'),
              const SizedBox(height: 16),
              FilledButton(onPressed: _initializeAndLoad, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // App bar with search toggle
          SliverAppBar(
            expandedHeight: _showSearch ? 130 : 100,
            floating: false,
            pinned: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: _showSearch ? null : Text(
                kAppDisplayName,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              background: _showSearch ? Padding(
                padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search events...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _showSearch = false);
                        _applyFilters();
                      },
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (value) => _applyFilters(),
                ),
              ) : null,
            ),
            actions: _showSearch ? null : [
              IconButton(
                icon: const Icon(Icons.search_rounded),
                onPressed: () => setState(() => _showSearch = true),
              ),
              const SizedBox(width: 8),
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
            SliverFillRemaining(child: _buildEmptyState())
          else ...[
            // Stats row
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: _buildStatsRow(),
              ),
            ),
            // Time range filter
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Time Range',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _timeRangeOptions.map((option) {
                          final isSelected = _timeRange == option['value'];
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(option['label']),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() => _timeRange = option['value']);
                                  _storage.setTimeRange(_timeRange);
                                  _applyFilters();
                                }
                              },
                              selectedColor: Theme.of(context).colorScheme.secondaryContainer,
                              labelStyle: TextStyle(
                                color: isSelected 
                                    ? Theme.of(context).colorScheme.onSecondaryContainer 
                                    : Theme.of(context).colorScheme.onSurface,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              ),
                              showCheckmark: false,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Type filter chips
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.filter_list_rounded,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Event Type',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildFilterChip('All', 'all', null),
                        _buildFilterChip('Birthdays', 'birthday', Icons.cake_rounded),
                        _buildFilterChip('Anniversaries', 'anniversary', Icons.favorite_rounded),
                        // Add custom event type filters
                        ..._customEventTypes.map((customType) => 
                          _buildFilterChip(
                            customType.name, 
                            customType.id, 
                            customType.icon
                          )
                        ),
                      ],
                    ),
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
                    if (_timeRange < 365 || _filterType != 'all') ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _buildActiveFiltersText(),
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
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
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off_rounded,
                        size: 48,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No events in this range',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _timeRange = 365;
                            _filterType = 'all';
                          });
                          _storage.setTimeRange(365);
                          _storage.setFilterType('all');
                          _applyFilters();
                        },
                        child: const Text('Clear filters'),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final event = _filteredEvents[index];
                      return Dismissible(
                        key: Key(event.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.red.shade400,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.delete_rounded, color: Colors.white, size: 28),
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
                                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                        },
                        onDismissed: (direction) async {
                          await _storage.deleteEvent(event.id);
                          await _loadEvents();
                        },
                        child: EventCard(
                          event: event,
                          onTap: () => _editEvent(event),
                        ),
                      );
                    },
                    childCount: _filteredEvents.length,
                  ),
                ),
              ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: "home_fab",
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
            primaryColorValue: Colors.blue.value, 
            backgroundColorValue: Colors.lightBlue.value,
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

  Widget _buildFilterChip(String label, String value, IconData? icon) {
    final isSelected = _filterType == value;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 4),
          ],
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _filterType = value);
        _storage.setFilterType(_filterType);
        _applyFilters();
      },
      selectedColor: Theme.of(context).colorScheme.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
      ),
      checkmarkColor: Colors.white,
      showCheckmark: false,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildStatsRow() {
    final birthdays = _allEvents.where((e) => e.eventType == EventType.birthday).length;
    final anniversaries = _allEvents.where((e) => e.eventType == EventType.anniversary).length;
    final thisWeek = _upcomingEvents.where((e) => EventCalculator.getDaysUntil(e) <= 7).length;

    return Row(
      children: [
        Expanded(child: _buildStatCard(Icons.cake_rounded, 'Birthdays', birthdays, const Color(0xFFF59E0B))),
        const SizedBox(width: 10),
        Expanded(child: _buildStatCard(Icons.favorite_rounded, 'Anniversaries', anniversaries, const Color(0xFFEC4899))),
        const SizedBox(width: 10),
        Expanded(child: _buildStatCard(Icons.notifications_active_rounded, 'This Week', thisWeek, const Color(0xFF10B981))),
      ],
    );
  }

  Widget _buildStatCard(IconData icon, String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            '$value',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8), fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.celebration_rounded,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No events yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Add birthdays and anniversaries\nto never forget a special day!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _addEvent,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add First Event'),
            ),
          ],
        ),
      ),
    );
  }
}
