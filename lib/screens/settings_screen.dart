import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../app_config.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../services/contact_parser_service.dart';
import '../services/link_service.dart';
import '../services/backup_codec.dart';
import '../services/backup_transfer.dart';
import '../services/google_calendar_service.dart';
import '../utils/user_message.dart';
import '../widgets/backup_preview_dialog.dart';
import '../widgets/import_birthdays_dialog.dart';
import '../theme/app_space.dart';
import '../widgets/permission_prompts.dart';
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
  final BackupCodec _backup = const BackupCodec();
  final BackupTransfer _transfer = const BackupTransfer();
  bool _notificationsEnabled = true;
  NotificationAccess _notificationAccess = NotificationAccess.unavailable;
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
    if (!mounted) return;
    _loadSettings();
    final access = await _notificationService.notificationAccess();
    if (mounted) {
      setState(() => _notificationAccess = access);
    }
  }

  Widget _themeChip(String value, String label) {
    final selected = _themeMode == value;
    final scheme = Theme.of(context).colorScheme;
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: scheme.secondaryContainer,
      labelStyle: TextStyle(
        color: selected ? scheme.onSecondaryContainer : scheme.onSurface,
      ),
      onSelected: (_) {
        setState(() => _themeMode = value);
        _storage.saveSetting('themeMode', value);
        final mode = value == 'light'
            ? ThemeMode.light
            : value == 'dark'
                ? ThemeMode.dark
                : ThemeMode.system;
        widget.onThemeModeChanged?.call(mode);
      },
    );
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

    if (_notificationsEnabled) {
      final access = await _notificationService.notificationAccess();
      if (mounted) {
        setState(() => _notificationAccess = access);
      }
      if (access == NotificationAccess.granted) {
        await _notificationService.scheduleDailyNotifications();
      }
    } else {
      await _notificationService.cancelAllNotifications();
    }
  }

  Future<void> _onRemindersChanged(bool value) async {
    if (!value) {
      setState(() => _notificationsEnabled = false);
      await _saveSettings();
      return;
    }

    var access = await _notificationService.notificationAccess();
    if (!mounted) return;
    if (access != NotificationAccess.granted && access != NotificationAccess.unavailable) {
      final result = await requestNotificationsWithExplanation(context);
      if (!mounted) return;
      if (result == PermissionPromptResult.dismissed) {
        setState(() => _notificationsEnabled = false);
        await _saveSettings();
        return;
      }
      if (result != PermissionPromptResult.granted) {
        access = await _notificationService.notificationAccess();
        setState(() {
          _notificationsEnabled = true;
          _notificationAccess = access;
        });
        await _storage.saveSetting('notificationsEnabled', true);
        return;
      }
      access = NotificationAccess.granted;
    }

    setState(() {
      _notificationsEnabled = true;
      _notificationAccess = access;
    });
    await _saveSettings();
  }

  bool get _remindersBlocked =>
      _notificationsEnabled &&
      _notificationAccess != NotificationAccess.granted &&
      _notificationAccess != NotificationAccess.unavailable;

  String _reminderSubtitle() {
    if (!_notificationsEnabled) return 'Reminders are turned off';
    if (_remindersBlocked) {
      return 'Reminders will not fire until notifications are allowed';
    }
    return 'You\'ll receive reminders for upcoming events';
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
                  if (status['initError'] != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Start-up error: ${status['initError']}',
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  _buildStatusRow('Permission Granted', status['permissionGranted'] ?? false),
                  if (!(status['permissionGranted'] ?? false)) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Reminders will not fire until notifications are allowed.',
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        try {
                          await openAppSettings();
                        } catch (e) {
                          debugPrint('Could not open system settings: $e');
                        }
                      },
                      icon: const Icon(Icons.settings, size: 18),
                      label: const Text('Open settings'),
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
          const SnackBar(content: Text('Could not check reminder status.')),
        );
      }
    }
  }

  Widget _buildStatusRow(String label, bool value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 8),
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
      GoogleCalendarService().syncInBackground();
      
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

  Future<void> _exportJson() async {
    try {
      final contents = _backup.exportJson(
        events: _storage.getAllEvents(),
        customTypes: _storage.getAllCustomEventTypes(),
        settings: _storage.exportSettings(),
      );
      await _transfer.share(
        filename: 'happaroo-backup.json',
        contents: contents,
        mimeType: 'application/json',
      );
    } catch (e) {
      debugPrint('JSON export failed: $e');
      _showBackupMessage(couldNot('share the JSON backup'));
    }
  }

  Future<void> _exportCsv() async {
    try {
      final contents = _backup.exportCsv(
        events: _storage.getAllEvents(),
        customTypes: _storage.getAllCustomEventTypes(),
      );
      await _transfer.share(
        filename: 'happaroo-events.csv',
        contents: contents,
        mimeType: 'text/csv',
      );
    } catch (e) {
      debugPrint('CSV export failed: $e');
      _showBackupMessage(couldNot('share the CSV backup'));
    }
  }

  Future<void> _importBackup() async {
    try {
      final picked = await _transfer.pick();
      if (picked == null || !mounted) return;
      final preview = _backup.preview(
        fileName: picked.name,
        contents: picked.contents,
        existingEvents: _storage.getAllEvents(),
        existingTypes: _storage.getAllCustomEventTypes(),
      );
      if (!mounted) return;
      final approved = await showBackupPreview(context, preview);
      if (!approved || !mounted) return;
      await _backup.apply(_storage, preview);
      GoogleCalendarService().syncInBackground();
      if (!mounted) return;
      setState(() {});
      final added = preview.added.length;
      _showBackupMessage(
        added == 0 ? 'Import finished. No new events were added.' : 'Imported $added event${added == 1 ? '' : 's'}.',
      );
    } catch (e) {
      debugPrint('Import failed: $e');
      _showBackupMessage(couldNot('import that file'));
    }
  }

  void _showBackupMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
              pinned: true,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              toolbarHeight: AppSpace.touch + MediaQuery.textScalerOf(context).scale(24),
              title: Text('Settings', style: Theme.of(context).textTheme.headlineSmall),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Appearance section
                  _buildSectionHeader('Appearance', Icons.palette_rounded),
                  const SizedBox(height: 12),
                  _buildCard(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpace.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Theme', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: AppSpace.xxs),
                          Text(
                            'Light, dark, or follow the device.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: AppSpace.sm),
                          Wrap(
                            spacing: AppSpace.xs,
                            runSpacing: AppSpace.xs,
                            children: [
                              _themeChip('system', 'System'),
                              _themeChip('light', 'Light'),
                              _themeChip('dark', 'Dark'),
                            ],
                          ),
                        ],
                      ),
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
                            _reminderSubtitle(),
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
                            await _onRemindersChanged(value);
                          },
                        ),
                        if (_remindersBlocked)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FilledButton.tonal(
                                onPressed: () => _onRemindersChanged(true),
                                child: const Text('Allow notifications'),
                              ),
                            ),
                          ),
                        if (_notificationsEnabled) ...[
                          const Divider(height: 1, indent: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: ListTile(
                              dense: true,
                              title: Text(
                                'Remind Me',
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                                  leading: Icon(
                                    isSelected ? Icons.check_rounded : option['icon'] as IconData,
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                  title: Text(
                                    option['label'],
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                  onTap: () => _toggleDay(option['value']),
                                ),
                                if (!isLast) const Divider(height: 1, indent: 56),
                              ],
                            );
                          }),
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
                                if (context.mounted) {
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
                          const Divider(height: 1, indent: 16),
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.notifications_active_rounded,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
                              ),
                            ),
                            title: const Text('Send test reminder'),
                            subtitle: const Text('Shows a notification now so you can check it arrives'),
                            onTap: () async {
                              final problem = await _notificationService.sendTestNotification();
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(problem ?? 'Test reminder sent.'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
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
                                      'Reminders stay on this device and can appear when the app is closed. Timing is inexact, so a reminder may arrive a little after the time you pick. If nothing appears, allow notifications for Happaroo in system settings.',
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

                  // Google Calendar section
                  _buildSectionHeader('Google Calendar', Icons.event_available_rounded),
                  const SizedBox(height: 12),
                  _buildCard(child: _buildGoogleCalendarTiles()),
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

                  _buildSectionHeader('Backup', Icons.ios_share_rounded),
                  const SizedBox(height: 12),
                  _buildCard(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.data_object_rounded),
                          title: const Text('Export JSON'),
                          subtitle: const Text('Events, custom types, and settings'),
                          onTap: _exportJson,
                        ),
                        const Divider(height: 1, indent: 56),
                        ListTile(
                          leading: const Icon(Icons.table_chart_outlined),
                          title: const Text('Export CSV'),
                          subtitle: const Text('Events only'),
                          onTap: _exportCsv,
                        ),
                        const Divider(height: 1, indent: 56),
                        const ListTile(
                          leading: Icon(Icons.info_outline_rounded),
                          title: Text('Import adds events'),
                          subtitle: Text(
                            'Nothing is removed if it is missing from the file. You review the file before anything is saved.',
                          ),
                        ),
                        const Divider(height: 1, indent: 56),
                        ListTile(
                          leading: const Icon(Icons.file_open_outlined),
                          title: const Text('Import JSON or CSV'),
                          subtitle: const Text('Choose a file, then approve the preview'),
                          onTap: _importBackup,
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
                    child: Column(
                      children: [
                        ListTile(
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
                            kAppDisplayName,
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: const Text('Version $kAppVersionLabel'),
                        ),
                        const Divider(height: 1, indent: 16),
                        ListTile(
                          leading: const Icon(Icons.privacy_tip_outlined),
                          title: const Text('Privacy policy'),
                          subtitle: const Text(kPrivacyPolicyUrl),
                          trailing: const Icon(Icons.open_in_new_rounded),
                          onTap: _openPrivacyPolicy,
                        ),
                      ],
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

  bool _calendarBusy = false;

  Widget _calendarLeading(IconData icon) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: scheme.primary, size: 20),
    );
  }

  Widget _buildGoogleCalendarTiles() {
    final calendar = GoogleCalendarService();
    if (!calendar.isConfigured) {
      return ListTile(
        leading: _calendarLeading(Icons.event_busy_rounded),
        title: const Text('Google Calendar sync unavailable'),
        subtitle: const Text('This build was made without a Google sign-in setup.'),
      );
    }
    if (!calendar.isConnected) {
      return ListTile(
        leading: _calendarLeading(Icons.add_link_rounded),
        title: const Text('Connect Google Calendar'),
        subtitle: const Text(
          'Adds a "Happaroo Birthdays" calendar to your Google account and keeps it up to date. '
          'Happaroo can only see that calendar.',
        ),
        trailing: _calendarBusy
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.chevron_right_rounded, size: 20),
        onTap: _calendarBusy ? null : () => _runCalendarAction(calendar.connect),
      );
    }
    final last = calendar.lastSync;
    final lastText = last == null
        ? 'Not synced yet'
        : 'Last synced ${MaterialLocalizations.of(context).formatShortDate(last)} '
            '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(last))}';
    return Column(
      children: [
        ListTile(
          leading: _calendarLeading(Icons.sync_rounded),
          title: const Text('Sync now'),
          subtitle: Text('${calendar.accountEmail ?? 'Google account'} · $lastText'),
          trailing: _calendarBusy
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : null,
          onTap: _calendarBusy ? null : () => _runCalendarAction(calendar.syncNow),
        ),
        const Divider(height: 1, indent: 16),
        ListTile(
          leading: _calendarLeading(Icons.link_off_rounded),
          title: const Text('Disconnect'),
          subtitle: const Text('Stop syncing. You can keep or remove the calendar.'),
          onTap: _calendarBusy ? null : _confirmCalendarDisconnect,
        ),
      ],
    );
  }

  Future<void> _runCalendarAction(Future<CalendarSyncResult> Function() action) async {
    setState(() => _calendarBusy = true);
    final result = await action();
    if (!mounted) return;
    setState(() => _calendarBusy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _confirmCalendarDisconnect() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Google Calendar?'),
        content: const Text(
          'Happaroo will stop updating the "Happaroo Birthdays" calendar. '
          'You can keep the calendar as it is, or remove it from your Google account.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, 'keep'), child: const Text('Keep calendar')),
          TextButton(onPressed: () => Navigator.pop(context, 'remove'), child: const Text('Remove calendar')),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    setState(() => _calendarBusy = true);
    final problem = await GoogleCalendarService().disconnect(removeCalendar: choice == 'remove');
    if (!mounted) return;
    setState(() => _calendarBusy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(problem ?? 'Google Calendar disconnected.'),
        behavior: SnackBarBehavior.floating,
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
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Future<void> _openPrivacyPolicy() async {
    final opened = await LinkService.open(kPrivacyPolicyUrl);
    if (opened || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Privacy policy'),
        content: const SelectableText(kPrivacyPolicyUrl),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _importFromContacts() async {
    if (!mounted) return;

    final permission = await requestContactsWithExplanation(context);
    if (!mounted || permission != PermissionPromptResult.granted) return;

    var loadingDialogOpen = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final importResult = await _contactParserService.parseContacts();

      if (!mounted) return;
      loadingDialogOpen = false;
      Navigator.pop(context); // Close loading dialog

      if (importResult.status == ContactImportStatus.permissionDenied) {
        await showContactsDeniedDialog(context);
        return;
      }
      if (importResult.status != ContactImportStatus.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not read contacts. Nothing was imported.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final potentialBirthdays = importResult.birthdays;

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
                'All $duplicateCount birthday${duplicateCount != 1 ? 's' : ''} are already imported',
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
        GoogleCalendarService().syncInBackground();

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
      debugPrint('Error importing contacts: $e');
      if (mounted) {
        if (loadingDialogOpen) {
          loadingDialogOpen = false;
          Navigator.pop(context);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not import contacts. Nothing was imported.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
