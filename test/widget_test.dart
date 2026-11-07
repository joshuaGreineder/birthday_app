import 'package:birthday_app/main.dart';
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
}

String _monthName(int month) {
  const names = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return names[month - 1];
}
