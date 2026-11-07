import 'package:flutter/material.dart';

import '../services/backup_codec.dart';

/// Returns true only when the user approves writing the preview.
Future<bool> showBackupPreview(BuildContext context, ImportPreview preview) {
  return showDialog<bool>(
    context: context,
    builder: (context) => _BackupPreviewDialog(preview: preview),
  ).then((approved) => approved ?? false);
}

class _BackupPreviewDialog extends StatelessWidget {
  final ImportPreview preview;

  const _BackupPreviewDialog({required this.preview});

  @override
  Widget build(BuildContext context) {
    final blocked = preview.fileError != null;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(blocked ? 'Cannot import' : 'Review import'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: blocked ? Text(preview.fileError!) : _details(context),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(blocked ? 'Close' : 'Cancel'),
        ),
        if (!blocked && preview.canApply)
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Approve'),
          ),
      ],
    );
  }

  Widget _details(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Import adds events. It does not remove events that are missing from the file.',
        ),
        const SizedBox(height: 12),
        Text('${preview.added.length} new'),
        ...preview.added.map((row) => Text('• ${row.event.name} (${row.typeLabel})')),
        const SizedBox(height: 8),
        Text(
          preview.duplicates.length == 1
              ? '1 duplicate skipped'
              : '${preview.duplicates.length} duplicates skipped',
        ),
        ...preview.duplicates.map((row) => Text('• Row ${row.rowNumber}: ${row.event.name}')),
        const SizedBox(height: 8),
        Text('${preview.problems.length} error${preview.problems.length == 1 ? '' : 's'}'),
        ...preview.problems.map((problem) => Text('• $problem')),
        if (preview.newCustomTypes.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('New custom types, created only if you approve:'),
          ...preview.newCustomTypes.map((type) => Text('• ${type.name}')),
        ],
        if (preview.settings != null) ...[
          const SizedBox(height: 8),
          const Text('Settings in this backup will be restored.'),
        ],
        if (!preview.canApply) ...[
          const SizedBox(height: 8),
          const Text('Nothing new to save.'),
        ],
      ],
    );
  }
}
