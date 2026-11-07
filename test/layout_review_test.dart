import 'dart:math' as math;

import 'package:birthday_app/models/event.dart';
import 'package:birthday_app/screens/add_edit_event_screen.dart';
import 'package:birthday_app/screens/calendar_screen.dart';
import 'package:birthday_app/screens/custom_event_type_screen.dart';
import 'package:birthday_app/screens/home_screen.dart';
import 'package:birthday_app/screens/onboarding_screen.dart';
import 'package:birthday_app/screens/settings_screen.dart';
import 'package:birthday_app/screens/timeline_screen.dart';
import 'package:birthday_app/services/backup_codec.dart';
import 'package:birthday_app/services/storage_service.dart';
import 'package:birthday_app/theme/app_theme.dart';
import 'package:birthday_app/utils/user_message.dart';
import 'package:birthday_app/widgets/backup_preview_dialog.dart';
import 'package:birthday_app/widgets/screen_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _openStorage() async {
  SharedPreferences.setMockInitialValues({});
  const permissions = MethodChannel('flutter.baseflow.com/permissions/methods');
  const widgets = MethodChannel('com.greinederlabs.happaroo/widget');
  const notifications = MethodChannel('dexterous.com/flutter/local_notifications');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(permissions, (call) async => 0);
  messenger.setMockMethodCallHandler(widgets, (call) async => true);
  messenger.setMockMethodCallHandler(notifications, (call) async => <dynamic>[]);
  await StorageService.resetForTest();
  await StorageService().init(memory: true);
  await StorageService().saveSetting('notificationsEnabled', false);
  await StorageService().saveSetting('onboardingComplete', true);
  await StorageService().addEvent(Event(
    id: 'ada',
    name: 'Ada Lovelace',
    eventType: EventType.birthday,
    originalDate: DateTime(1815, 12, 10),
    group: 'Family',
  ));
  await StorageService().addEvent(Event(
    id: 'sam',
    name: 'Sam',
    eventType: EventType.anniversary,
    originalDate: DateTime(4, 2, 29),
  ));
}

double _channel(double value) {
  return value <= 0.04045 ? value / 12.92 : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
}

double _luminance(Color color) {
  return 0.2126 * _channel(color.r) + 0.7152 * _channel(color.g) + 0.0722 * _channel(color.b);
}

double contrast(Color a, Color b) {
  final lighter = math.max(_luminance(a), _luminance(b));
  final darker = math.min(_luminance(a), _luminance(b));
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  setUp(() async {
    await _openStorage();
  });

  tearDown(() async {
    await StorageService.resetForTest();
  });

  test('painted text colors meet WCAG AA', () {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      final scheme = theme.colorScheme;
      expect(contrast(scheme.onSurface, scheme.surface), greaterThanOrEqualTo(4.5), reason: '${theme.brightness} onSurface');
      expect(contrast(scheme.onSurface, scheme.surfaceContainerLow), greaterThanOrEqualTo(4.5));
      expect(contrast(scheme.onSurface, scheme.surfaceContainer), greaterThanOrEqualTo(4.5));
      expect(contrast(scheme.onPrimary, scheme.primary), greaterThanOrEqualTo(4.5));
      expect(contrast(scheme.onPrimaryContainer, scheme.primaryContainer), greaterThanOrEqualTo(4.5));
      expect(contrast(scheme.onSecondaryContainer, scheme.secondaryContainer), greaterThanOrEqualTo(4.5));
      expect(contrast(scheme.onError, scheme.error), greaterThanOrEqualTo(4.5));
      final birthday = theme.brightness == Brightness.dark ? const Color(0xFFFFCC80) : const Color(0xFF7C2D12);
      final anniversary = theme.brightness == Brightness.dark ? const Color(0xFFFFB2C8) : const Color(0xFF9D174D);
      expect(contrast(birthday, scheme.surface), greaterThanOrEqualTo(4.5), reason: '${theme.brightness} birthday');
      expect(contrast(anniversary, scheme.surface), greaterThanOrEqualTo(4.5), reason: '${theme.brightness} anniversary');
      expect(contrast(birthday, scheme.surfaceContainerLow), greaterThanOrEqualTo(4.5));
      expect(contrast(anniversary, scheme.surfaceContainerLow), greaterThanOrEqualTo(4.5));
    }
  });

  testWidgets('screens fit phone and tablet, light and dark, at 200% text', (tester) async {
    const sizes = [Size(390, 844), Size(840, 1100)];
    const scales = [1.0, 2.0];
    const modes = [ThemeMode.light, ThemeMode.dark];

    final failures = <String>[];

    Future<void> pump(Size size, double scale, ThemeMode mode, String name, Widget home) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final previous = FlutterError.onError;
      FlutterErrorDetails? overflow;
      FlutterError.onError = (details) {
        overflow ??= details;
        previous?.call(details);
      };
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: mode,
        home: home,
      ));
      await tester.pump();
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 40));
      }
      FlutterError.onError = previous;
      final exception = tester.takeException();
      if (exception != null) {
        failures.add('${size.width.toInt()} scale $scale $mode $name: $exception\n${overflow?.toString()}');
      }
    }

    for (final size in sizes) {
      for (final scale in scales) {
        for (final mode in modes) {
          await pump(size, scale, mode, 'home', const HomeScreen());
          await pump(size, scale, mode, 'timeline', const TimelineScreen());
          await pump(size, scale, mode, 'calendar', const CalendarScreen());
          await pump(size, scale, mode, 'settings', const SettingsScreen());
          await pump(size, scale, mode, 'add', const AddEditEventScreen());
          await pump(size, scale, mode, 'custom type', const CustomEventTypeScreen());
          await pump(size, scale, mode, 'onboarding', OnboardingScreen(onDone: () {}));
          await pump(
            size,
            scale,
            mode,
            'error',
            ScreenStatus.error(title: couldNot('load events'), onRetry: () {}),
          );
          await pump(
            size,
            scale,
            mode,
            'empty',
            ScreenStatus.empty(
              icon: Icons.celebration_rounded,
              title: 'No events yet',
              body: 'Add birthdays and anniversaries so the next one is easy to find.',
              actionLabel: 'Add First Event',
              onAction: () {},
            ),
          );
        }
      }
    }
    await StorageService().clearAllEvents();
    for (final size in sizes) {
      for (final scale in scales) {
        for (final mode in modes) {
          await pump(size, scale, mode, 'home empty', const HomeScreen());
        }
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  testWidgets('import preview shows a yearless date without year 4', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final preview = const BackupCodec().preview(
      fileName: 'events.csv',
      contents: 'Name,Date,Type,Group,Notes\nSam,02/29,Anniversary,,\n',
      existingEvents: const [],
      existingTypes: const [],
    );
    expect(preview.added.single.event.originalDate.year, 4);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Builder(
        builder: (context) => Scaffold(
          body: FilledButton(
            onPressed: () => showBackupPreview(context, preview),
            child: const Text('Open preview'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Open preview'));
    await tester.pumpAndSettle();
    expect(find.textContaining('February 29'), findsOneWidget);
    expect(find.textContaining('year 4'), findsNothing);
    expect(find.textContaining('0004'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
