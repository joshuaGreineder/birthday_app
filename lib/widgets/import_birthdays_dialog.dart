import 'package:flutter/material.dart';
import '../models/event.dart' as event_model;
import '../services/contact_parser_service.dart';

class ImportBirthdaysDialog extends StatefulWidget {
  final List<PotentialBirthday> potentialBirthdays;

  const ImportBirthdaysDialog({
    super.key,
    required this.potentialBirthdays,
  });

  @override
  State<ImportBirthdaysDialog> createState() => _ImportBirthdaysDialogState();
}

typedef Event = event_model.Event;

class _ImportBirthdaysDialogState extends State<ImportBirthdaysDialog> {
  final Set<int> _selectedIndices = {};

  @override
  void initState() {
    super.initState();
    // Select all by default
    _selectedIndices.addAll(
      List.generate(widget.potentialBirthdays.length, (index) => index),
    );
  }

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedIndices.length == widget.potentialBirthdays.length) {
        _selectedIndices.clear();
      } else {
        _selectedIndices.addAll(
          List.generate(widget.potentialBirthdays.length, (index) => index),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.people_rounded,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Found ${widget.potentialBirthdays.length} Birthday${widget.potentialBirthdays.length != 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Select which ones to import',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // List of birthdays
            Flexible(
              child: widget.potentialBirthdays.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 64,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No birthdays found',
                            style: TextStyle(
                              fontSize: 16,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: widget.potentialBirthdays.length,
                      itemBuilder: (context, index) {
                        final birthday = widget.potentialBirthdays[index];
                        final isSelected = _selectedIndices.contains(index);
                        
                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (_) => _toggleSelection(index),
                          title: Text(
                            birthday.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            '${birthday.date.month}/${birthday.date.day}/${birthday.date.year} • ${birthday.source}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          secondary: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.cake_rounded,
                              color: Theme.of(context).colorScheme.primary,
                              size: 20,
                            ),
                          ),
                        );
                      },
                    ),
            ),
            
            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _selectAll,
                    child: Text(
                      _selectedIndices.length == widget.potentialBirthdays.length
                          ? 'Deselect All'
                          : 'Select All',
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context, <Event>[]),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _selectedIndices.isEmpty
                        ? null
                        : () {
                            final selectedEvents = _selectedIndices
                                .map((index) => widget.potentialBirthdays[index].toEvent(index))
                                .toList();
                            Navigator.pop(context, selectedEvents);
                          },
                    child: Text(
                      'Import ${_selectedIndices.length}',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

