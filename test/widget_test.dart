import 'package:birthday_app/main.dart';
import 'package:birthday_app/models/event.dart';
import 'package:birthday_app/screens/add_edit_event_screen.dart';
import 'package:birthday_app/screens/calendar_screen.dart';
import 'package:birthday_app/screens/home_screen.dart';
import 'package:birthday_app/screens/settings_screen.dart';
import 'package:birthday_app/screens/timeline_screen.dart';
import 'package:birthday_app/services/storage_service.dart';
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
}

Future<void> _pumpPastLoading(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    final stillLoading = find.text('Loading events...').evaluate().isNotEmpty ||
        find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
    if (!stillLoading) return;
  }
}

/// In-memory Hive completes on a microtask. Tick the pop animation in short
/// steps so it reaches dismissed; one long jump leaves it stuck at reverse.
Future<void> _flushHive(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUp(() async {
    await _openStorage();
  });

  tearDown(() async {
    await StorageService.resetForTest();
  });

  testWidgets('Happaroo shows its loading state, then the home screen', (tester) async {
    await tester.pumpWidget(const HapparooApp());
    expect(find.text('Loading events...'), findsOneWidget);
    await _pumpPastLoading(tester);
    expect(find.text('Loading events...'), findsNothing);
    expect(find.text('Happaroo'), findsOneWidget);
    expect(find.text('No events yet'), findsOneWidget);
    expect(find.text('Event Tracker'), findsNothing);
    expect(find.text('Birthday App'), findsNothing);
  });

  testWidgets('saved light theme is used from the first frame after a restart', (tester) async {
    await StorageService().saveSetting('themeMode', 'light');
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(const HapparooApp());
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.light);
    await _pumpPastLoading(tester);
  });

  testWidgets('saved dark theme survives a restart', (tester) async {
    await StorageService().saveSetting('themeMode', 'dark');
    await tester.pumpWidget(const HapparooApp());
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode, ThemeMode.dark);
    await _pumpPastLoading(tester);
  });

  testWidgets('main screens are reachable after loading', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const HapparooApp());
    await _pumpPastLoading(tester);

    await tester.tap(find.text('Timeline'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text(_monthName(DateTime.now().month)), findsOneWidget);

    await tester.tap(find.text('Calendar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('No events on this date'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.scrollUntilVisible(find.text('Export JSON'), 400);
    expect(find.text('Export JSON'), findsOneWidget);
    expect(find.text('Export CSV'), findsOneWidget);
    expect(find.text('Import JSON or CSV'), findsOneWidget);
    expect(find.textContaining('missing from the file'), findsOneWidget);
  });

  testWidgets('add, edit, and delete an event from home', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await _pumpPastLoading(tester);

    await tester.tap(find.text('Add Event'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('New Event'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Please enter a name'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'Ada Lovelace');
    await tester.enterText(find.byType(TextFormField).at(1), 'Family');
    await tester.tap(find.text('Save'));
    await _flushHive(tester);
    expect(find.text('New Event'), findsNothing);
    expect(find.text('Ada Lovelace'), findsWidgets);
    await tester.ensureVisible(find.text('Ada Lovelace').first);
    await tester.tap(find.text('Ada Lovelace').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Edit Event'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Grace Hopper');
    await tester.tap(find.text('Save'));
    await _flushHive(tester);
    expect(find.text('Grace Hopper'), findsOneWidget);
    expect(find.text('Ada Lovelace'), findsNothing);

    await tester.tap(find.text('Grace Hopper'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Delete Event'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await _flushHive(tester);
    expect(find.text('Grace Hopper'), findsNothing);
    expect(find.text('No events yet'), findsOneWidget);
  });

  testWidgets('timeline, calendar, and settings load on their own', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MaterialApp(home: TimelineScreen()));
    await _pumpPastLoading(tester);
    expect(find.text(_monthName(DateTime.now().month)), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: CalendarScreen()));
    await _pumpPastLoading(tester);
    expect(find.text('No events on this date'), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await _pumpPastLoading(tester);
    expect(find.text('Settings'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Privacy policy'), 400);
    expect(find.text('Privacy policy'), findsOneWidget);
  });

  testWidgets('onboarding is skippable and shows once', (tester) async {
    await StorageService().saveSetting('onboardingComplete', false);
    await tester.pumpWidget(const HapparooApp());
    await _pumpPastLoading(tester);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Never miss a day'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await _pumpPastLoading(tester);
    expect(find.text('No events yet'), findsOneWidget);
    expect(StorageService().isOnboardingComplete(), isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(const HapparooApp());
    await _pumpPastLoading(tester);
    expect(find.text('Skip'), findsNothing);
    expect(find.text('No events yet'), findsOneWidget);
  });

  testWidgets('home filters by group and treats a blank group as Ungrouped', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await StorageService().addEvent(Event(
      id: 'ada',
      name: 'Ada Lovelace',
      eventType: EventType.birthday,
      originalDate: DateTime(1990, 12, 10),
      group: 'Family',
    ));
    await StorageService().addEvent(Event(
      id: 'neighbor',
      name: 'Neighbor',
      eventType: EventType.anniversary,
      originalDate: DateTime(4, 1, 2),
      group: '  ',
    ));

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await _pumpPastLoading(tester);
    expect(find.text('Family'), findsWidgets);
    expect(find.text('Ungrouped'), findsWidgets);
    expect(find.text('Neighbor'), findsOneWidget);
    expect(find.text('Anniversary'), findsWidgets);
    expect(find.textContaining('Born 4'), findsNothing);
    expect(find.textContaining('Since 4'), findsNothing);

    await tester.tap(find.widgetWithText(FilterChip, 'Ungrouped'));
    await tester.pump();
    expect(find.text('Neighbor'), findsOneWidget);
    expect(find.text('Ada Lovelace'), findsNothing);
  });

  testWidgets('add screen can save a month and day without a year', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MaterialApp(home: AddEditEventScreen()));
    await tester.pump();
    await tester.tap(find.text('I know the year'));
    await tester.pump();
    expect(find.textContaining('${DateTime.now().year}'), findsNothing);
    expect(find.textContaining(', 4'), findsNothing);
  });
}

String _monthName(int month) {
  const names = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return names[month - 1];
}
