import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../services/contact_parser_service.dart';
import '../widgets/import_birthdays_dialog.dart';
import '../models/event.dart' as event_model;
import 'custom_event_type_screen.dart';

class SettingsScreen extends StatefulWidget {
  final Function(ThemeMode)? onThemeModeChanged;
  
  const SettingsScreen({super.key, this.onThemeModeChanged});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final StorageService _storage = StorageService();
  final NotificationService _notificationService = NotificationService();
  final ContactParserService _contactParserService = ContactParserService();
  bool _notificationsEnabled = true;
  List<int> _selectedDays = [0, 1, 7];
  int _notificationHour = 8;
  int _notificationMinute = 0;
  String _themeMode = 'system';

  final List<Map<String, dynamic>> _dayOptions = [
    {'value': 0, 'label': 'Same day', 'icon': Icons.today_rounded},
    {'value': 1, 'label': '1 day before', 'icon': Icons.looks_one_rounded},
    {'value': 2, 'label': '2 days before', 'icon': Icons.looks_two_rounded},
    {'value': 3, 'label': '3 days before', 'icon': Icons.looks_3_rounded},
    {'value': 7, 'label': '1 week before', 'icon': Icons.date_range_rounded},
    {'value': 14, 'label': '2 weeks before', 'icon': Icons.calendar_view_week_rounded},
    {'value': 30, 'label': '1 month before', 'icon': Icons.calendar_month_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _initAndLoadSettings();
  }

  Future<void> _initAndLoadSettings() async {
    // Ensure storage is initialized before loading settings
    await _storage.init();
    if (mounted) {
      _loadSettings();
    }
  }

  void _loadSettings() {
    setState(() {
      _notificationsEnabled = _storage.getNotificationsEnabled();
      _selectedDays = _storage.getNotificationDays();
      _notificationHour = _storage.getNotificationHour();
      _notificationMinute = _storage.getNotificationMinute();
      _themeMode = _storage.getSetting('themeMode', defaultValue: 'system') as String;
    });
    debugPrint('Settings loaded: hour=$_notificationHour, minute=$_notificationMinute, enabled=$_notificationsEnabled');
  }

  Future<void> _saveSettings() async {
    debugPrint('Saving settings: hour=$_notificationHour, minute=$_notificationMinute, enabled=$_notificationsEnabled');
    await _storage.saveSetting('notificationsEnabled', _notificationsEnabled);
    await _storage.saveSetting('notificationDays', _selectedDays);
    await _storage.setNotificationTime(_notificationHour, _notificationMinute);
    debugPrint('Settings saved successfully');
    
    // Handle notification permissions and scheduling
    if (_notificationsEnabled) {
      final hasPermission = await _notificationService.requestPermissions();
      if (hasPermission) {
        await _notificationService.scheduleDailyNotifications();
      } else {
        // If permission denied, show a message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Notification permission is required for reminders'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              action: SnackBarAction(
                label: 'Open Settings',
                onPressed: () async {
                  await _notificationService.requestPermissions();
                },
              ),
            ),
          );
        }
      }
    } else {
      // Cancel all notifications when disabled
      await _notificationService.cancelAllNotifications();
    }
  }

  void _toggleDay(int day) {
    setState(() {
      if (_selectedDays.contains(day)) {
        if (_selectedDays.length > 1) {
          _selectedDays.remove(day);
        }
      } else {
        _selectedDays.add(day);
        _selectedDays.sort();
      }
    });
    _saveSettings();
  }

  Future<void> _checkNotificationStatus() async {
    try {
      final status = await _notificationService.getNotificationStatus();
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Notification Status'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildStatusRow('Initialized', status['initialized'] ?? false),
                  _buildStatusRow('Permission Granted', status['permissionGranted'] ?? false),
                  _buildStatusRow('Exact Alarm Permission', status['exactAlarmPermission'] ?? false),
                  if (!(status['exactAlarmPermission'] ?? false)) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _notificationService.openExactAlarmSettings();
                      },
                      icon: const Icon(Icons.settings, size: 18),
                      label: const Text('Open Exact Alarm Settings'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.orange,
                      ),
                    ),
                  ],
                  _buildStatusRow('Battery Optimization Disabled', status['batteryOptimizationDisabled'] ?? false),
                  if (!(status['batteryOptimizationDisabled'] ?? false)) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _notificationService.requestDisableBatteryOptimization();
                      },
                      icon: const Icon(Icons.battery_charging_full, size: 18),
                      label: const Text('Disable Battery Optimization'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.orange,
                      ),
                    ),
                  ],
                  _buildStatusRow('Notifications Enabled', status['notificationsEnabled'] ?? false),
                  const Divider(height: 24),
                  Text('Settings:', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Text('Hour: ${status['notificationHour'] ?? 'N/A'}'),
                  Text('Minute: ${status['notificationMinute'] ?? 'N/A'}'),
                  Text('Days: ${(status['notificationDays'] as List?)?.join(', ') ?? 'N/A'}'),
                  const Divider(height: 24),
                  Text('Scheduled Notifications: ${status['scheduledCount'] ?? 0}', 
                    style: Theme.of(context).textTheme.titleSmall),
                  if ((status['pendingNotifications'] as List?)?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 8),
                    ...(status['pendingNotifications'] as List).map((n) => 
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• ${n['title']}: ${n['body']}', 
                          style: Theme.of(context).textTheme.bodySmall),
                      )
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking status: $e')),
        );
      }
    }
  }

  Widget _buildStatusRow(String label, bool value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Icon(
            value ? Icons.check_circle : Icons.cancel,
            color: value ? Colors.green : Colors.red,
            size: 20,
          ),
        ],
      ),
    );
  }

  String _formatHour(int hour, [int minute = 0]) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final displayMinute = minute.toString().padLeft(2, '0');
    return '$displayHour:$displayMinute $period';
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.red.shade400),
            const SizedBox(width: 12),
            const Text('Clear All Data'),
          ],
        ),
        content: const Text(
          'This will permanently delete all your events and settings. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // Clear all events
      final events = _storage.getAllEvents();
      for (final event in events) {
        await _storage.deleteEvent(event.id);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('All data has been cleared'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventCount = _storage.getAllEvents().length;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 80,
              floating: false,
              pinned: true,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                title: Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Appearance section
                  _buildSectionHeader('Appearance', Icons.palette_rounded),
                  const SizedBox(height: 12),
                  _buildCard(
                    child: Column(
                      children: [
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _themeMode == 'dark' 
                                  ? Icons.dark_mode_rounded
                                  : _themeMode == 'light'
                                      ? Icons.light_mode_rounded
                                      : Icons.brightness_auto_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          title: const Text('Theme'),
                          subtitle: Text(
                            _themeMode == 'dark' 
                                ? 'Dark mode'
                                : _themeMode == 'light'
                                    ? 'Light mode'
                                    : 'Follow system',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          trailing: DropdownButton<String>(
                            value: _themeMode,
                            underline: const SizedBox(),
                            items: const [
                              DropdownMenuItem(
                                value: 'system',
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.brightness_auto_rounded, size: 18),
                                    SizedBox(width: 8),
                                    Text('System'),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'light',
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.light_mode_rounded, size: 18),
                                    SizedBox(width: 8),
                                    Text('Light'),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'dark',
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.dark_mode_rounded, size: 18),
                                    SizedBox(width: 8),
                                    Text('Dark'),
                                  ],
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _themeMode = value;
                                });
                                _storage.saveSetting('themeMode', value);
                                if (widget.onThemeModeChanged != null) {
                                  final mode = value == 'light'
                                      ? ThemeMode.light
                                      : value == 'dark'
                                          ? ThemeMode.dark
                                          : ThemeMode.system;
                                  widget.onThemeModeChanged!(mode);
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Notifications section - grouped together
                  _buildSectionHeader('Notifications', Icons.notifications_rounded),
                  const SizedBox(height: 12),
                  _buildCard(
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text('Enable Reminders'),
                          subtitle: Text(
                            _notificationsEnabled
                                ? 'You\'ll receive reminders for upcoming events'
                                : 'Reminders are turned off',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          secondary: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _notificationsEnabled ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          value: _notificationsEnabled,
                          onChanged: (value) async {
                            setState(() => _notificationsEnabled = value);
                            await _saveSettings();
                          },
                        ),
                        if (_notificationsEnabled) ...[
                          const Divider(height: 1, indent: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: ListTile(
                              dense: true,
                              title: Text(
                                'Remind Me',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                          ),
                          ..._dayOptions.asMap().entries.map((entry) {
                            final index = entry.key;
                            final option = entry.value;
                            final isSelected = _selectedDays.contains(option['value']);
                            final isLast = index == _dayOptions.length - 1;
                            
                            return Column(
                              children: [
                                ListTile(
                                  dense: true,
                                  leading: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Theme.of(context).colorScheme.primary
                                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(
                                      isSelected ? Icons.check_rounded : option['icon'],
                                      size: 16,
                                      color: isSelected 
                                          ? Colors.white 
                                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  title: Text(
                                    option['label'],
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                      color: isSelected 
                                          ? Theme.of(context).colorScheme.primary 
                                          : null,
                                    ),
                                  ),
                                  onTap: () => _toggleDay(option['value']),
                                ),
                                if (!isLast) const Divider(height: 1, indent: 56),
                              ],
                            );
                          }).toList(),
                          const Divider(height: 1, indent: 16),
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.access_time_rounded, color: Color(0xFF10B981), size: 20),
                            ),
                            title: const Text('Notification Time'),
                            subtitle: Text(_formatHour(_notificationHour, _notificationMinute)),
                            trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                            onTap: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay(hour: _notificationHour, minute: _notificationMinute),
                              );
                              if (time != null) {
                                setState(() {
                                  _notificationHour = time.hour;
                                  _notificationMinute = time.minute;
                                });
                                await _saveSettings();
                                
                                // Schedule a test notification for 1 minute from now to verify it works
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Notification time saved.'),
                                      behavior: SnackBarBehavior.floating,
                                      duration: Duration(seconds: 3),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                          const Divider(height: 1, indent: 16),
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.info_outline_rounded,
                                color: Theme.of(context).colorScheme.tertiary,
                                size: 20,
                              ),
                            ),
                            title: const Text('Notification Status'),
                            subtitle: const Text('Check notification permissions and scheduled notifications'),
                            trailing: IconButton(
                              icon: const Icon(Icons.refresh_rounded, size: 20),
                              onPressed: () async {
                                await _checkNotificationStatus();
                              },
                            ),
                          ),
                          // Helpful note about notifications working when app is closed
                          if (_notificationsEnabled) ...[
                            const Divider(height: 1, indent: 16),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    size: 18,
                                    color: Theme.of(context).colorScheme.tertiary,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Notifications work even when the app is closed. If notifications don\'t appear, check your device\'s battery optimization settings and ensure this app is not optimized.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Custom Event Types section
                  _buildSectionHeader('Custom Event Types', Icons.category_rounded),
                  const SizedBox(height: 12),
                  _buildCard(
                    child: Column(
                      children: [
                        ...(_storage.getAllCustomEventTypes().asMap().entries.map((entry) {
                          final index = entry.key;
                          final customType = entry.value;
                          return ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: customType.primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                customType.icon,
                                color: customType.primaryColor,
                              ),
                            ),
                            title: Text(customType.name),
                            subtitle: Text(
                              'Custom event type ${index + 1}',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.edit_rounded),
                              onPressed: () async {
                                final result = await Navigator.of(context).push<bool>(
                                  MaterialPageRoute(
                                    builder: (context) => CustomEventTypeScreen(customType: customType),
                                  ),
                                );
                                if (result == true) {
                                  setState(() {}); // Refresh to show updates
                                }
                              },
                            ),
                            onTap: () async {
                              final result = await Navigator.of(context).push<bool>(
                                MaterialPageRoute(
                                  builder: (context) => CustomEventTypeScreen(customType: customType),
                                ),
                              );
                              if (result == true) {
                                setState(() {}); // Refresh to show updates
                              }
                            },
                          );
                        }).toList()),
                        if (_storage.getCustomEventTypeCount() < 2) ...[
                          if (_storage.getAllCustomEventTypes().isNotEmpty) const Divider(height: 1, indent: 16),
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.add_rounded,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            title: const Text('Add Custom Event Type'),
                            subtitle: Text(
                              '${_storage.getCustomEventTypeCount()}/2 custom types',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                            onTap: () async {
                              final result = await Navigator.of(context).push<bool>(
                                MaterialPageRoute(
                                  builder: (context) => const CustomEventTypeScreen(),
                                ),
                              );
                              if (result == true) {
                                setState(() {}); // Refresh to show updates
                              }
                            },
                          ),
                        ],
                        if (_storage.getCustomEventTypeCount() >= 2)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Maximum of 2 custom event types reached',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Import section
                  _buildSectionHeader('Import', Icons.import_export_rounded),
                  const SizedBox(height: 12),
                  _buildCard(
                    child: Column(
                      children: [
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.people_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          title: const Text('Import from Contacts'),
                          subtitle: const Text('Find birthdays from your contacts'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: kIsWeb ? null : () => _importFromContacts(),
                          enabled: !kIsWeb,
                        ),
                        if (kIsWeb)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Text(
                              'Contact import not available on web',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Data section
                  _buildSectionHeader('Data', Icons.storage_rounded),
                  const SizedBox(height: 12),
                  _buildCard(
                    child: Column(
                      children: [
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.event_rounded,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                          ),
                          title: const Text('Total Events'),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$eventCount',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                        const Divider(height: 1, indent: 56),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                          ),
                          title: const Text('Clear All Data'),
                          subtitle: const Text('Delete all events permanently'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: eventCount > 0 ? _clearAllData : null,
                          enabled: eventCount > 0,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // About section
                  _buildSectionHeader('About', Icons.info_outline_rounded),
                  const SizedBox(height: 12),
                  _buildCard(
                    child: ListTile(
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).colorScheme.primary,
                              Theme.of(context).colorScheme.secondary,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.celebration_rounded, color: Colors.white),
                      ),
                      title: const Text(
                        'Event Tracker',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text('Version 1.0.0'),
                    ),
                  ),
                  const SizedBox(height: 100),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: child,
    );
  }

  Future<void> _importFromContacts() async {
    // Show loading dialog
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final potentialBirthdays = await _contactParserService.parseContacts();
      
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (potentialBirthdays.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'No birthdays found in contacts.\n\n'
                'Make sure your contacts have birthdays set. '
                'You can check this in your Contacts app.',
              ),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      // Filter out duplicates before showing dialog
      final existingEvents = _storage.getAllEvents();
      final filteredBirthdays = potentialBirthdays.where((potential) {
        // Check if a duplicate exists (same name and same date)
        return !existingEvents.any((existing) =>
          existing.name.toLowerCase() == potential.name.toLowerCase() &&
          existing.originalDate.year == potential.date.year &&
          existing.originalDate.month == potential.date.month &&
          existing.originalDate.day == potential.date.day &&
          existing.eventType == event_model.EventType.birthday
        );
      }).toList();
      
      final duplicateCount = potentialBirthdays.length - filteredBirthdays.length;
      
      // If all birthdays are duplicates, show a message
      if (filteredBirthdays.isEmpty && duplicateCount > 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'All ${duplicateCount} birthday${duplicateCount != 1 ? 's' : ''} are already imported',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      
      // Show message if some duplicates were filtered
      if (duplicateCount > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$duplicateCount duplicate${duplicateCount != 1 ? 's' : ''} filtered out',
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
      // Show import dialog
      final selectedEvents = await showDialog<List<event_model.Event>>(
        context: context,
        builder: (context) => ImportBirthdaysDialog(
          potentialBirthdays: filteredBirthdays,
        ),
      );

      if (selectedEvents != null && selectedEvents.isNotEmpty) {
        // Check for duplicates and filter them out
        final existingEvents = _storage.getAllEvents();
        final eventsToImport = <event_model.Event>[];
        final skippedDuplicates = <String>[];
        
        for (final event in selectedEvents) {
          // Check if a duplicate exists (same name and same date)
          final isDuplicate = existingEvents.any((existing) =>
            existing.name.toLowerCase() == event.name.toLowerCase() &&
            existing.originalDate.year == event.originalDate.year &&
            existing.originalDate.month == event.originalDate.month &&
            existing.originalDate.day == event.originalDate.day &&
            existing.eventType == event.eventType
          );
          
          if (!isDuplicate) {
            eventsToImport.add(event);
          } else {
            skippedDuplicates.add(event.name);
          }
        }
        
        // Add non-duplicate events
        for (var i = 0; i < eventsToImport.length; i++) {
          // Regenerate event with unique ID based on index
          final event = eventsToImport[i];
          final uniqueEvent = event_model.Event(
            id: '${DateTime.now().millisecondsSinceEpoch}_$i',
            name: event.name,
            eventType: event.eventType,
            originalDate: event.originalDate,
            notes: event.notes,
            customEventTypeId: event.customEventTypeId,
          );
          await _storage.addEvent(uniqueEvent);
        }

        if (mounted) {
          final message = StringBuffer();
          if (eventsToImport.isNotEmpty) {
            message.write('Imported ${eventsToImport.length} birthday${eventsToImport.length != 1 ? 's' : ''}');
          }
          if (skippedDuplicates.isNotEmpty) {
            if (message.isNotEmpty) message.write('. ');
            message.write('Skipped ${skippedDuplicates.length} duplicate${skippedDuplicates.length != 1 ? 's' : ''}');
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message.toString()),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: skippedDuplicates.isNotEmpty ? 4 : 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error importing contacts: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
