import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/custom_event_type.dart';
import '../services/storage_service.dart';
import '../utils/icon_picker.dart';

class CustomEventTypeScreen extends StatefulWidget {
  final CustomEventType? customType;

  const CustomEventTypeScreen({super.key, this.customType});

  @override
  State<CustomEventTypeScreen> createState() => _CustomEventTypeScreenState();
}

class _CustomEventTypeScreenState extends State<CustomEventTypeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _turningController = TextEditingController();
  final _nowController = TextEditingController();
  final _currentController = TextEditingController();
  final _storage = StorageService();

  Color _primaryColor = const Color(0xFF3B82F6);
  Color _backgroundColor = const Color(0xFFDBEAFE);
  int _selectedIconIndex = 0;
  bool _isSaving = false;
  bool _hasChanges = false;
  
  // Store initial values to detect changes
  String? _initialName;
  Color? _initialColor;
  int? _initialIconIndex;
  String? _initialTurningText;
  String? _initialNowText;
  String? _initialCurrentText;

  @override
  void initState() {
    super.initState();
    if (widget.customType != null) {
      _nameController.text = widget.customType!.name;
      _turningController.text = widget.customType!.turningTextTemplate;
      _nowController.text = widget.customType!.nowTextTemplate;
      _currentController.text = widget.customType!.currentTextTemplate;
      _primaryColor = widget.customType!.primaryColor;
      _backgroundColor = widget.customType!.backgroundColor;
      // Find icon index
      final iconData = widget.customType!.icon;
      _selectedIconIndex = IconPicker.getIconIndex(iconData);
      if (_selectedIconIndex == -1) _selectedIconIndex = 0;
      
      // Store initial values
      _initialName = widget.customType!.name;
      _initialColor = widget.customType!.primaryColor;
      _initialIconIndex = _selectedIconIndex;
      _initialTurningText = widget.customType!.turningTextTemplate;
      _initialNowText = widget.customType!.nowTextTemplate;
      _initialCurrentText = widget.customType!.currentTextTemplate;
    } else {
      // Default templates
      _turningController.text = 'Turning {years}';
      _nowController.text = 'Now {years}!';
      _currentController.text = 'Currently {years}';
    }
    _updateBackgroundColor();
    
    // Listen for changes
    _nameController.addListener(_onFieldChanged);
    _turningController.addListener(_onFieldChanged);
    _nowController.addListener(_onFieldChanged);
    _currentController.addListener(_onFieldChanged);
  }
  
  void _onFieldChanged() {
    if (!_hasChanges) {
      setState(() {
        _hasChanges = _checkForChanges();
      });
    }
  }
  
  bool _checkForChanges() {
    if (widget.customType == null) {
      // New type - has changes if name is filled
      return _nameController.text.trim().isNotEmpty;
    }
    
    // Editing - check if anything changed
    return _nameController.text.trim() != _initialName ||
        _primaryColor.value != _initialColor?.value ||
        _selectedIconIndex != _initialIconIndex ||
        _turningController.text.trim() != _initialTurningText ||
        _nowController.text.trim() != _initialNowText ||
        _currentController.text.trim() != _initialCurrentText;
  }

  @override
  void dispose() {
    _nameController.removeListener(_onFieldChanged);
    _turningController.removeListener(_onFieldChanged);
    _nowController.removeListener(_onFieldChanged);
    _currentController.removeListener(_onFieldChanged);
    _nameController.dispose();
    _turningController.dispose();
    _nowController.dispose();
    _currentController.dispose();
    super.dispose();
  }
  
  Future<bool> _onWillPop() async {
    if (!_hasChanges || _isSaving) {
      return true;
    }
    
    // Check if form is valid and has content
    if (_nameController.text.trim().isEmpty ||
        _turningController.text.trim().isEmpty ||
        _nowController.text.trim().isEmpty ||
        _currentController.text.trim().isEmpty) {
      // No valid content, just close
      return true;
    }
    
    // Ask user if they want to save
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Changes?'),
        content: const Text('You have unsaved changes. Would you like to save them before leaving?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), // false = discard
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true), // true = save
            child: const Text('Save'),
          ),
        ],
      ),
    );
    
    // If user chose to save
    if (result == true) {
      final saved = await _saveCustomType(shouldPop: false);
      return saved; // Return true to close if save succeeded, false to stay if it failed
    }
    
    // If user chose to discard (result == false), allow navigation
    // If user cancelled (result == null), prevent navigation
    return result == false;
  }

  void _updateBackgroundColor() {
    setState(() {
      _backgroundColor = _primaryColor.withOpacity(0.15);
    });
  }

  Future<void> _selectIcon() async {
    final iconIndex = await showDialog<int>(
      context: context,
      builder: (context) => _IconPickerDialog(selectedIndex: _selectedIconIndex),
    );
    if (iconIndex != null) {
      setState(() {
        _selectedIconIndex = iconIndex;
        _hasChanges = _checkForChanges();
      });
    }
  }

  Future<void> _openColorPicker() async {
    final color = await showDialog<Color>(
      context: context,
      builder: (context) => _ColorSelectionDialog(initialColor: _primaryColor),
    );
    if (color != null) {
      setState(() {
        _primaryColor = color;
        _updateBackgroundColor();
        _hasChanges = _checkForChanges();
      });
    }
  }

  Future<void> _editTextTemplates() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _TextTemplatesDialog(
        turningText: _turningController.text,
        nowText: _nowController.text,
        currentText: _currentController.text,
      ),
    );
    if (result != null) {
      setState(() {
        _turningController.text = result['turning'] ?? '';
        _nowController.text = result['now'] ?? '';
        _currentController.text = result['current'] ?? '';
        _hasChanges = _checkForChanges();
      });
    }
  }

  Future<bool> _saveCustomType({bool shouldPop = true}) async {
    if (!_formKey.currentState!.validate() || _isSaving) return false;

    // Validate text templates
    if (_turningController.text.trim().isEmpty ||
        _nowController.text.trim().isEmpty ||
        _currentController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please configure all text templates'),
          ),
        );
      }
      return false;
    }

    // Check limit of 2 custom types
    final existingCount = _storage.getCustomEventTypeCount();
    if (widget.customType == null && existingCount >= 2) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You can only have up to 2 custom event types'),
          ),
        );
      }
      return false;
    }

    setState(() => _isSaving = true);

    try {
      final customType = CustomEventType(
        id: widget.customType?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        primaryColorValue: _primaryColor.value,
        backgroundColorValue: _backgroundColor.value,
        iconCodePoint: IconPicker.getIcon(_selectedIconIndex).codePoint,
        turningTextTemplate: _turningController.text.trim(),
        nowTextTemplate: _nowController.text.trim(),
        currentTextTemplate: _currentController.text.trim(),
      );

      await _storage.saveCustomEventType(customType);

      if (mounted) {
        setState(() {
          _hasChanges = false;
          _isSaving = false;
        });
        
        if (shouldPop) {
          Navigator.of(context).pop(true);
        }
        return true;
      }
      return false;
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
      return false;
    }
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSettingButton({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
          ],
        ),
      ),
    );
  }

  String _getColorName(Color color) {
    // Simple color name detection
    final hsl = HSLColor.fromColor(color);
    final hue = hsl.hue;
    
    if (hue < 15 || hue >= 345) return 'Red';
    if (hue >= 15 && hue < 45) return 'Orange';
    if (hue >= 45 && hue < 75) return 'Yellow';
    if (hue >= 75 && hue < 165) return 'Green';
    if (hue >= 165 && hue < 195) return 'Cyan';
    if (hue >= 195 && hue < 255) return 'Blue';
    if (hue >= 255 && hue < 285) return 'Purple';
    if (hue >= 285 && hue < 315) return 'Magenta';
    if (hue >= 315 && hue < 345) return 'Pink';
    return 'Custom Color';
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.customType != null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          final shouldPop = await _onWillPop();
          if (shouldPop && mounted) {
            Navigator.of(context).pop(true);
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () async {
              final shouldPop = await _onWillPop();
              if (shouldPop && mounted) {
                Navigator.pop(context, true);
              }
            },
          ),
        title: Text(isEditing ? 'Edit Custom Type' : 'New Custom Type'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: _isSaving ? null : () => _saveCustomType(shouldPop: true),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save'),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Name field
            _buildLabel('Name'),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: 'e.g., Pet Birthday, Work Anniversary',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a name';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Icon selection button
            _buildSettingButton(
              icon: IconPicker.getIcon(_selectedIconIndex),
              label: 'Icon',
              value: IconPicker.getIconName(IconPicker.getIcon(_selectedIconIndex)),
              onTap: _selectIcon,
              color: _primaryColor,
            ),
            const SizedBox(height: 12),

            // Color selection button
            _buildSettingButton(
              icon: Icons.palette_rounded,
              label: 'Color',
              value: _getColorName(_primaryColor),
              onTap: _openColorPicker,
              color: _primaryColor,
            ),
            const SizedBox(height: 12),

            // Text templates button
            _buildSettingButton(
              icon: Icons.text_fields_rounded,
              label: 'Text Templates',
              value: 'Customize text',
              onTap: _editTextTemplates,
              color: _primaryColor,
            ),
            const SizedBox(height: 24),

            // Preview
            _buildLabel('Preview'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _primaryColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _primaryColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      IconPicker.getIcon(_selectedIconIndex),
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _nameController.text.isEmpty
                              ? 'Event Name'
                              : _nameController.text,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _turningController.text.isEmpty
                              ? 'Turning {years}'
                              : _turningController.text.replaceAll('{years}', '5'),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[700],
                              ),
                        ),
                      ],
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
}

// Icon Picker Dialog
class _IconPickerDialog extends StatefulWidget {
  final int selectedIndex;

  const _IconPickerDialog({required this.selectedIndex});

  @override
  State<_IconPickerDialog> createState() => _IconPickerDialogState();
}

class _IconPickerDialogState extends State<_IconPickerDialog> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.selectedIndex;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Icon'),
      content: SizedBox(
        width: double.maxFinite,
        child: GridView.builder(
          shrinkWrap: true,
          physics: const BouncingScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: IconPicker.availableIcons.length,
          itemBuilder: (context, index) {
            final icon = IconPicker.getIcon(index);
            final isSelected = index == _selectedIndex;
            return InkWell(
              onTap: () => setState(() => _selectedIndex = index),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                      : Colors.grey.withOpacity(0.1),
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey[600],
                  size: 28,
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selectedIndex),
          child: const Text('Select'),
        ),
      ],
    );
  }
}

// Color Selection Dialog
class _ColorSelectionDialog extends StatefulWidget {
  final Color initialColor;

  const _ColorSelectionDialog({required this.initialColor});

  @override
  State<_ColorSelectionDialog> createState() => _ColorSelectionDialogState();
}

class _ColorSelectionDialogState extends State<_ColorSelectionDialog> {
  late Color _selectedColor;
  final List<Color> _colorOptions = [
    const Color(0xFF3B82F6), // Blue
    const Color(0xFF10B981), // Green
    const Color(0xFF8B5CF6), // Purple
    const Color(0xFFF59E0B), // Amber
    const Color(0xFFEC4899), // Pink
    const Color(0xFFEF4444), // Red
    const Color(0xFF06B6D4), // Cyan
    const Color(0xFF84CC16), // Lime
    const Color(0xFFF97316), // Orange
    const Color(0xFF6366F1), // Indigo
  ];

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
  }

  Future<void> _pickCustomColor() async {
    final color = await showDialog<Color>(
      context: context,
      builder: (context) => _ColorPickerDialog(initialColor: _selectedColor),
    );
    if (color != null) {
      setState(() {
        _selectedColor = color;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Color'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Preset colors
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ..._colorOptions.map((color) => _ColorChip(
                        color: color,
                        isSelected: color.value == _selectedColor.value,
                        onTap: () => setState(() => _selectedColor = color),
                      )),
                  _ColorChip(
                    color: _selectedColor,
                    isSelected: false,
                    isCustom: true,
                    onTap: _pickCustomColor,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Color preview
              Container(
                width: double.infinity,
                height: 60,
                decoration: BoxDecoration(
                  color: _selectedColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selectedColor),
          child: const Text('Select'),
        ),
      ],
    );
  }
}

// Text Templates Dialog
class _TextTemplatesDialog extends StatefulWidget {
  final String turningText;
  final String nowText;
  final String currentText;

  const _TextTemplatesDialog({
    required this.turningText,
    required this.nowText,
    required this.currentText,
  });

  @override
  State<_TextTemplatesDialog> createState() => _TextTemplatesDialogState();
}

class _TextTemplatesDialogState extends State<_TextTemplatesDialog> {
  late TextEditingController _turningController;
  late TextEditingController _nowController;
  late TextEditingController _currentController;

  @override
  void initState() {
    super.initState();
    _turningController = TextEditingController(text: widget.turningText);
    _nowController = TextEditingController(text: widget.nowText);
    _currentController = TextEditingController(text: widget.currentText);
  }

  @override
  void dispose() {
    _turningController.dispose();
    _nowController.dispose();
    _currentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Text Templates'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Use {years} as a placeholder for the age/years',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                '"Turning" Text',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _turningController,
                decoration: const InputDecoration(
                  hintText: 'e.g., Turning {years}',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '"Now" Text',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nowController,
                decoration: const InputDecoration(
                  hintText: 'e.g., Now {years}!',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '"Current" Text',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _currentController,
                decoration: const InputDecoration(
                  hintText: 'e.g., Currently {years}',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(
              context,
              {
                'turning': _turningController.text.trim(),
                'now': _nowController.text.trim(),
                'current': _currentController.text.trim(),
              },
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _ColorChip extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final bool isCustom;
  final VoidCallback onTap;

  const _ColorChip({
    required this.color,
    required this.isSelected,
    this.isCustom = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.black : Colors.transparent,
            width: 2,
          ),
        ),
        child: isCustom
            ? Icon(
                Icons.colorize,
                color: Colors.white,
                size: 24,
              )
            : isSelected
                ? const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 24,
                  )
                : null,
      ),
    );
  }
}

class _ColorPickerDialog extends StatefulWidget {
  final Color initialColor;

  const _ColorPickerDialog({required this.initialColor});

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late Color _selectedColor;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pick a Color'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ColorPicker(
                color: _selectedColor,
                onColorChanged: (color) => setState(() => _selectedColor = color),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selectedColor),
          child: const Text('Select'),
        ),
      ],
    );
  }
}

// Professional color picker widget with color wheel and magnification
class ColorPicker extends StatefulWidget {
  final Color color;
  final ValueChanged<Color> onColorChanged;

  const ColorPicker({
    super.key,
    required this.color,
    required this.onColorChanged,
  });

  @override
  State<ColorPicker> createState() => _ColorPickerState();
}

class _ColorPickerState extends State<ColorPicker> {
  late double _hue;
  late double _saturation;
  late double _value;
  Offset? _magnifierPosition;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _updateFromColor(widget.color);
  }

  void _updateFromColor(Color color) {
    final hsl = HSLColor.fromColor(color);
    _hue = hsl.hue;
    _saturation = hsl.saturation;
    _value = hsl.lightness;
  }

  Color _getColor() {
    return HSLColor.fromAHSL(1.0, _hue, _saturation, _value).toColor();
  }

  void _updateColorFromPosition(Offset localPosition, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final offset = localPosition - center;
    final distance = offset.distance;
    final radius = (size.width < size.height ? size.width : size.height) / 2 - 25;
    final innerRadius = radius * 0.25;
    
    // Calculate hue from angle (convert from -π to π range to 0-360)
    final angle = (offset.direction * 180 / math.pi + 360) % 360;
    
    // Calculate saturation from distance
    double newSaturation;
    if (distance < innerRadius) {
      newSaturation = 0;
    } else if (distance > radius) {
      newSaturation = 1.0;
    } else {
      newSaturation = ((distance - innerRadius) / (radius - innerRadius)).clamp(0.0, 1.0);
    }
    
    setState(() {
      _hue = angle;
      _saturation = newSaturation;
      widget.onColorChanged(_getColor());
    });
  }

  void _onColorWheelPanStart(DragStartDetails details, Size size) {
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    setState(() {
      _isDragging = true;
      _magnifierPosition = localPosition;
    });
    _updateColorFromPosition(localPosition, size);
  }

  void _onColorWheelPanUpdate(DragUpdateDetails details, Size size) {
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    setState(() {
      _magnifierPosition = localPosition;
    });
    _updateColorFromPosition(localPosition, size);
  }

  void _onColorWheelPanEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
      _magnifierPosition = null;
    });
  }

  void _onColorWheelTapDown(TapDownDetails details, Size size) {
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    _updateColorFromPosition(localPosition, size);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Color wheel with magnification
        SizedBox(
          width: double.infinity,
          height: 300,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              return Stack(
                children: [
                  GestureDetector(
                    onTapDown: (details) => _onColorWheelTapDown(details, size),
                    onPanStart: (details) => _onColorWheelPanStart(details, size),
                    onPanUpdate: (details) => _onColorWheelPanUpdate(details, size),
                    onPanEnd: _onColorWheelPanEnd,
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _ColorWheelPainter(
                          hue: _hue,
                          saturation: _saturation,
                          value: _value,
                        ),
                        child: Container(),
                      ),
                    ),
                  ),
                  // Magnification loupe
                  if (_isDragging && _magnifierPosition != null)
                    Positioned(
                      left: _magnifierPosition!.dx + 30,
                      top: _magnifierPosition!.dy - 40,
                      child: _MagnificationLoupe(
                        position: _magnifierPosition!,
                        size: size,
                        hue: _hue,
                        saturation: _saturation,
                        value: _value,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        // Hue slider
        _buildSlider(
          label: 'Hue',
          value: _hue,
          min: 0,
          max: 360,
          divisions: 360,
          formatValue: (v) => '${v.round()}°',
          onChanged: (value) {
            setState(() {
              _hue = value;
              widget.onColorChanged(_getColor());
            });
          },
        ),
        const SizedBox(height: 12),
        // Saturation slider
        _buildSlider(
          label: 'Saturation',
          value: _saturation,
          min: 0,
          max: 1,
          divisions: 100,
          formatValue: (v) => '${(v * 100).round()}%',
          onChanged: (value) {
            setState(() {
              _saturation = value;
              widget.onColorChanged(_getColor());
            });
          },
        ),
        const SizedBox(height: 12),
        // Brightness/Value slider
        _buildSlider(
          label: 'Brightness',
          value: _value,
          min: 0,
          max: 1,
          divisions: 100,
          formatValue: (v) => '${(v * 100).round()}%',
          onChanged: (value) {
            setState(() {
              _value = value;
              widget.onColorChanged(_getColor());
            });
          },
        ),
        const SizedBox(height: 16),
        // Color preview with hex code
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _getColor(),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.withOpacity(0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: _getColor().withOpacity(0.3),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '#${_getColor().value.toRadixString(16).substring(2).toUpperCase()}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String Function(double) formatValue,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: formatValue(value),
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 60,
          child: Text(
            formatValue(value),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

// Custom painter for the color wheel
class _ColorWheelPainter extends CustomPainter {
  final double hue;
  final double saturation;
  final double value;

  _ColorWheelPainter({
    required this.hue,
    required this.saturation,
    required this.value,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width < size.height ? size.width : size.height) / 2 - 25;
    final innerRadius = radius * 0.25;
    
    // Highly optimized: Draw fewer, larger segments for much better performance
    // Use wider angle steps (3 degrees) and larger radius steps (3 pixels)
    for (double r = innerRadius; r <= radius; r += 3.0) {
      final normalizedR = (r - innerRadius) / (radius - innerRadius);
      
      // Draw circle segments with larger angle steps for speed
      for (double angle = 0; angle < 360; angle += 3) {
        final nextAngle = angle + 3;
        final startRadians = angle * math.pi / 180;
        final endRadians = nextAngle * math.pi / 180;
        
        final saturationColor = HSLColor.fromAHSL(1.0, angle, normalizedR, value).toColor();
        final paint = Paint()
          ..color = saturationColor
          ..style = PaintingStyle.fill
          ..isAntiAlias = false; // Disable anti-aliasing for speed
        
        // Draw arc segment - simplified path
        final path = Path()
          ..moveTo(center.dx, center.dy)
          ..lineTo(
            center.dx + r * math.cos(startRadians),
            center.dy + r * math.sin(startRadians),
          )
          ..arcToPoint(
            Offset(
              center.dx + r * math.cos(endRadians),
              center.dy + r * math.sin(endRadians),
            ),
            radius: Radius.circular(r),
            largeArc: false,
          )
          ..close();
        
        canvas.drawPath(path, paint);
      }
    }
    
    // Draw center circle (for saturation = 0) - always white/gray based on brightness
    // This represents zero saturation (pure grayscale)
    final centerPaint = Paint()
      ..color = HSLColor.fromAHSL(1.0, 0, 0, value).toColor() // Use hue 0 (red) but saturation 0 = grayscale
      ..style = PaintingStyle.fill
      ..isAntiAlias = true; // Keep anti-aliasing for circles
    canvas.drawCircle(center, innerRadius, centerPaint);
    
    // Add a subtle border to make it clearer
    final centerBorderPaint = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..isAntiAlias = true;
    canvas.drawCircle(center, innerRadius, centerBorderPaint);
    
    // Draw border around wheel
    final borderPaint = Paint()
      ..color = Colors.grey.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..isAntiAlias = true;
    canvas.drawCircle(center, radius, borderPaint);
    canvas.drawCircle(center, innerRadius, borderPaint);
    
    // Draw selection indicator
    final selectionAngle = hue * math.pi / 180;
    final selectionDistance = innerRadius + saturation * (radius - innerRadius);
    final selectionX = center.dx + selectionDistance * math.cos(selectionAngle);
    final selectionY = center.dy + selectionDistance * math.sin(selectionAngle);
    
    // Outer white ring with shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(Offset(selectionX + 1, selectionY + 1), 14, shadowPaint);
    
    final outerIndicatorPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    canvas.drawCircle(Offset(selectionX, selectionY), 14, outerIndicatorPaint);
    
    // Inner black ring
    final innerIndicatorPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset(selectionX, selectionY), 14, innerIndicatorPaint);
    
    // Center dot
    final dotPaint = Paint()
      ..color = HSLColor.fromAHSL(1.0, hue, saturation, value).toColor()
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(selectionX, selectionY), 5, dotPaint);
  }

  @override
  bool shouldRepaint(_ColorWheelPainter oldDelegate) {
    return oldDelegate.hue != hue ||
        oldDelegate.saturation != saturation ||
        oldDelegate.value != value;
  }
}

// Magnification loupe widget
class _MagnificationLoupe extends StatelessWidget {
  final Offset position;
  final Size size;
  final double hue;
  final double saturation;
  final double value;

  const _MagnificationLoupe({
    required this.position,
    required this.size,
    required this.hue,
    required this.saturation,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final center = Offset(size.width / 2, size.height / 2);
    final offset = position - center;
    final distance = offset.distance;
    final radius = (size.width < size.height ? size.width : size.height) / 2 - 25;
    final innerRadius = radius * 0.25;
    
    // Calculate color at position
    final angle = (offset.direction * 180 / math.pi + 360) % 360;
    double calcSaturation;
    if (distance < innerRadius) {
      calcSaturation = 0;
    } else if (distance > radius) {
      calcSaturation = 1.0;
    } else {
      calcSaturation = ((distance - innerRadius) / (radius - innerRadius)).clamp(0.0, 1.0);
    }
    
    final magnifiedColor = HSLColor.fromAHSL(1.0, angle, calcSaturation, value).toColor();
    
    return Transform.translate(
      offset: const Offset(0, -60),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: magnifiedColor,
          border: Border.all(
            color: Colors.white,
            width: 4,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Crosshair
            CustomPaint(
              painter: _CrosshairPainter(),
              size: const Size(80, 80),
            ),
          ],
        ),
      ),
    );
  }
}

// Crosshair painter for magnification loupe
class _CrosshairPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..strokeWidth = 1.5;
    
    // Horizontal line
    canvas.drawLine(
      Offset(center.dx - 15, center.dy),
      Offset(center.dx + 15, center.dy),
      paint,
    );
    
    // Vertical line
    canvas.drawLine(
      Offset(center.dx, center.dy - 15),
      Offset(center.dx, center.dy + 15),
      paint,
    );
    
    // Center dot
    final dotPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 2, dotPaint);
  }

  @override
  bool shouldRepaint(_CrosshairPainter oldDelegate) => false;
}

