import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/event.dart';
import '../models/custom_event_type.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../services/widget_service.dart';
import '../theme/app_space.dart';
import '../theme/app_theme.dart';
import '../utils/user_message.dart';
import '../utils/yearless_date.dart';
import 'custom_event_type_screen.dart';

class AddEditEventScreen extends StatefulWidget {
  final Event? event;

  const AddEditEventScreen({super.key, this.event});

  @override
  State<AddEditEventScreen> createState() => _AddEditEventScreenState();
}

class _AddEditEventScreenState extends State<AddEditEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  final _groupController = TextEditingController();
  final _storage = StorageService();
  
  EventType _eventType = EventType.birthday;
  String? _selectedCustomTypeId;
  DateTime _selectedDate = DateTime.now();
  bool _includeYear = true;
  bool _isSaving = false;
  List<CustomEventType> _customTypes = [];

  @override
  void initState() {
    super.initState();
    _loadCustomTypes();
    if (widget.event != null) {
      _nameController.text = widget.event!.name;
      _notesController.text = widget.event!.notes ?? '';
      _groupController.text = widget.event!.group;
      _eventType = widget.event!.eventType;
      _selectedCustomTypeId = widget.event!.customEventTypeId;
      final stored = widget.event!.originalDate;
      if (isYearlessDate(stored)) {
        _includeYear = false;
        _selectedDate = DateTime(2000, stored.month, stored.day);
      } else {
        _includeYear = true;
        _selectedDate = stored;
      }
    }
  }

  void _loadCustomTypes() {
    setState(() {
      _customTypes = _storage.getAllCustomEventTypes();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    _groupController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final initial = _selectedDate.year < 1900
        ? DateTime(2000, _selectedDate.month, _selectedDate.day)
        : _selectedDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;

    setState(() => _isSaving = true);

    try {
      final event = Event(
        id: widget.event?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        eventType: _eventType,
        originalDate: _includeYear
            ? DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day)
            : yearlessDate(_selectedDate.month, _selectedDate.day),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        customEventTypeId: _selectedCustomTypeId,
        group: _groupController.text.trim(),
      );

      if (widget.event == null) {
        await _storage.addEvent(event);
      } else {
        await _storage.updateEvent(event);
      }

      // Close the screen immediately
      if (mounted) Navigator.of(context).pop(true);
      
      // Update notifications and widgets in the background (non-blocking)
      if (_storage.getNotificationsEnabled()) {
        final notificationService = NotificationService();
        notificationService.scheduleDailyNotifications().catchError((Object e) {
          debugPrint('Error scheduling notifications: $e');
          return false;
        });
      }
      
      // Update widget data in background
      WidgetService.updateWidgetData().catchError((e) {
        debugPrint('Error updating widget data: $e');
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        debugPrint('Could not save event: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(couldNot('save this event'))),
        );
      }
    }
  }

  Future<void> _deleteEvent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Event'),
        content: Text('Delete "${widget.event!.name}"?'),
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

    if (confirmed == true && mounted) {
      try {
        await _storage.deleteEvent(widget.event!.id);
        try {
          if (_storage.getNotificationsEnabled()) {
            await NotificationService().scheduleDailyNotifications();
          }
          await WidgetService.updateWidgetData();
        } catch (e) {
          debugPrint('Saved the delete, but reminders could not be refreshed: $e');
        }
        if (mounted) Navigator.of(context).pop(true);
      } catch (e) {
        debugPrint('Could not delete event: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(couldNot('delete this event'))),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.event != null;
    final isBirthday = _eventType == EventType.birthday;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: AppSpace.touch + MediaQuery.textScalerOf(context).scale(20),
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEditing ? 'Edit Event' : 'New Event',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.md),
          child: FilledButton(
            onPressed: _isSaving ? null : _saveEvent,
            child: _isSaving
                ? SizedBox(
                    width: AppSpace.lg,
                    height: AppSpace.lg,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  )
                : const Text('Save'),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Event type selector
            _buildLabel('Event Type'),
            const SizedBox(height: AppSpace.sm),
            _typeChoices(isBirthday),
            if (_customTypes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _customTypes.map((customType) {
                  final isSelected = _selectedCustomTypeId == customType.id;
                  return SizedBox(
                    width: (MediaQuery.of(context).size.width - 64) / 2 - 6,
                    child: _TypeCard(
                      icon: customType.icon,
                      label: customType.name,
                      isSelected: isSelected,
                      color: customType.primaryColor,
                      onTap: () => setState(() {
                        _selectedCustomTypeId = customType.id;
                        _eventType = EventType.birthday; // Default, but custom type takes precedence
                      }),
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (context) => const CustomEventTypeScreen(),
                  ),
                );
                if (result == true) {
                  _loadCustomTypes();
                }
              },
              icon: const Icon(Icons.add_rounded),
              label: Text(_customTypes.length >= 2 
                ? 'Manage Custom Types' 
                : 'Add Custom Type (${_customTypes.length}/2)'),
            ),
            const SizedBox(height: 24),

            // Name field
            _buildLabel(isBirthday ? 'Person\'s Name' : 'Names'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: isBirthday ? 'e.g., Sarah Johnson' : 'e.g., Mom & Dad',
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
                prefixIcon: const Icon(Icons.person_rounded),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Please enter a name' : null,
            ),
            const SizedBox(height: 24),

            // Date picker
            _buildLabel(isBirthday ? 'Birthday' : 'Anniversary Date'),
            const SizedBox(height: 12),
            InkWell(
              onTap: _selectDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month_rounded, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _includeYear ? formatFullDate(_selectedDate) : formatMonthDay(_selectedDate),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (_includeYear)
                            Text(
                              DateFormat('EEEE').format(_selectedDate),
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                        ],
                      ),
                    ),
                    Icon(Icons.edit_calendar_rounded, color: Theme.of(context).colorScheme.primary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('I know the year'),
              subtitle: const Text('Turn this off to save only the month and day. Age stays hidden.'),
              value: _includeYear,
              onChanged: (value) => setState(() => _includeYear = value),
            ),
            const SizedBox(height: AppSpace.lg),

            _buildLabel('Group (optional)'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _groupController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'e.g., Family',
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
                prefixIcon: const Icon(Icons.group_rounded),
              ),
            ),
            const SizedBox(height: 24),

            // Notes field
            _buildLabel('Notes (optional)'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Gift ideas, celebration plans...',
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
              ),
            ),

            if (isEditing) ...[
              const SizedBox(height: 40),
              OutlinedButton.icon(
                onPressed: _deleteEvent,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Delete Event'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _typeChoices(bool isBirthday) {
    final birthday = _TypeCard(
      icon: Icons.cake_rounded,
      label: 'Birthday',
      isSelected: isBirthday && _selectedCustomTypeId == null,
      color: EventPalette.accent(context, birthday: true),
      onTap: () => setState(() {
        _eventType = EventType.birthday;
        _selectedCustomTypeId = null;
      }),
    );
    final anniversary = _TypeCard(
      icon: Icons.favorite_rounded,
      label: 'Anniversary',
      isSelected: !isBirthday && _selectedCustomTypeId == null,
      color: EventPalette.accent(context, birthday: false),
      onTap: () => setState(() {
        _eventType = EventType.anniversary;
        _selectedCustomTypeId = null;
      }),
    );
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    if (stacked) {
      return Column(
        children: [
          birthday,
          const SizedBox(height: AppSpace.sm),
          anniversary,
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: birthday),
        const SizedBox(width: AppSpace.sm),
        Expanded(child: anniversary),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _TypeCard({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.15)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: isSelected ? color : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
      ),
    );
  }
}
