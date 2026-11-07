import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/notification_service.dart';

enum PermissionPromptResult { granted, denied, dismissed }

Future<PermissionPromptResult> requestNotificationsWithExplanation(
  BuildContext context,
) async {
  final proceed = await _showExplanation(
    context,
    title: 'Allow reminders?',
    body:
        'Happaroo will ask the system for notification access so it can remind you about birthdays and other events. Reminders are scheduled on this device. They are not sent to a server. You can choose Not now and turn reminders on later in Settings.',
  );
  if (proceed != true) {
    return PermissionPromptResult.dismissed;
  }

  final access = await NotificationService().requestNotificationAccess();
  if (access == NotificationAccess.granted) {
    return PermissionPromptResult.granted;
  }
  if (context.mounted) {
    await _showDenied(
      context,
      title: 'Notifications are off',
      body:
          'Reminders will not fire until notifications are allowed for Happaroo. You can turn them on in system settings.',
    );
  }
  return PermissionPromptResult.denied;
}

Future<PermissionPromptResult> requestContactsWithExplanation(
  BuildContext context,
) async {
  final proceed = await _showExplanation(
    context,
    title: 'Import birthdays from contacts?',
    body:
        'Happaroo will read contact names and birthdays on this device so you can choose which ones to save. Those details stay on this device. They are not uploaded. You can choose Not now and add events yourself.',
  );
  if (proceed != true) {
    return PermissionPromptResult.dismissed;
  }

  try {
    final status = await Permission.contacts.request();
    if (status.isGranted) {
      return PermissionPromptResult.granted;
    }
  } catch (e) {
    debugPrint('Contacts permission request failed: $e');
  }

  if (context.mounted) {
    await _showDenied(
      context,
      title: 'Contacts access is off',
      body:
          'Happaroo cannot import birthdays until contacts access is allowed. You can turn it on in system settings.',
    );
  }
  return PermissionPromptResult.denied;
}

Future<void> showContactsDeniedDialog(BuildContext context) {
  return _showDenied(
    context,
    title: 'Contacts access is off',
    body:
        'Happaroo cannot import birthdays until contacts access is allowed. You can turn it on in system settings.',
  );
}

Future<bool?> _showExplanation(
  BuildContext context, {
  required String title,
  required String body,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
}

Future<void> _showDenied(
  BuildContext context, {
  required String title,
  required String body,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () async {
            Navigator.pop(context);
            try {
              await openAppSettings();
            } catch (e) {
              debugPrint('Could not open system settings: $e');
            }
          },
          child: const Text('Open settings'),
        ),
      ],
    ),
  );
}
