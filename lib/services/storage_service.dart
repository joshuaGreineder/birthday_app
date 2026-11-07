import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/event.dart';
import '../models/custom_event_type.dart';

class StorageService {
  static const String _eventsBoxName = 'events';
  static const String _settingsBoxName = 'settings';
  static const String _customEventTypesBoxName = 'custom_event_types';
  static StorageService? _instance;
  static Box<Event>? _eventsBox;
  static Box<dynamic>? _settingsBox;
  static Box<CustomEventType>? _customEventTypesBox;
  static bool _initialized = false;
  static Future<void>? _initFuture;

  factory StorageService() {
    _instance ??= StorageService._internal();
    return _instance!;
  }

  StorageService._internal();

  /// [directory] is a disk path for tests. The app leaves it null and uses Hive's
  /// Flutter path. [memory] opens empty in-memory boxes so a widget test is not
  /// blocked on disk I/O.
  Future<void> init({String? directory, bool memory = false}) async {
    if (_initialized) return;
    _initFuture ??= _open(directory, memory);
    try {
      await _initFuture;
    } catch (e) {
      _initFuture = null;
      debugPrint('Storage initialization error: $e');
      rethrow;
    }
  }

  Future<void> _open(String? directory, bool memory) async {
    if (!memory) {
      if (directory != null) {
        Hive.init(directory);
      } else {
        await Hive.initFlutter();
      }
    }

    Uint8List? emptyBytes() => memory ? Uint8List(0) : null;

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(EventAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(EventTypeAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(CustomEventTypeAdapter());
    }

    _eventsBox = await Hive.openBox<Event>(_eventsBoxName, bytes: emptyBytes());
    _settingsBox = await Hive.openBox<dynamic>(_settingsBoxName, bytes: emptyBytes());
    _customEventTypesBox =
        await Hive.openBox<CustomEventType>(_customEventTypesBoxName, bytes: emptyBytes());
    _initialized = true;
    debugPrint('Storage initialized successfully');
  }

  /// Closes boxes so a test can open a fresh directory. Not used by the app.
  static Future<void> resetForTest() async {
    await _eventsBox?.close();
    await _settingsBox?.close();
    await _customEventTypesBox?.close();
    _eventsBox = null;
    _settingsBox = null;
    _customEventTypesBox = null;
    _initialized = false;
    _initFuture = null;
    _instance = null;
    await Hive.close();
  }

  // Event operations
  Future<void> addEvent(Event event) async {
    await _eventsBox?.put(event.id, event);
  }

  Future<void> updateEvent(Event event) async {
    await _eventsBox?.put(event.id, event);
  }

  Future<void> deleteEvent(String id) async {
    await _eventsBox?.delete(id);
  }

  List<Event> getAllEvents() {
    return _eventsBox?.values.toList() ?? [];
  }

  Event? getEvent(String id) {
    return _eventsBox?.get(id);
  }

  Future<void> clearAllEvents() async {
    await _eventsBox?.clear();
  }

  Stream<BoxEvent> watchEvents() {
    return _eventsBox?.watch() ?? const Stream.empty();
  }

  // Custom Event Type operations
  Future<void> saveCustomEventType(CustomEventType customType) async {
    await _customEventTypesBox?.put(customType.id, customType);
  }

  Future<void> deleteCustomEventType(String id) async {
    await _customEventTypesBox?.delete(id);
  }

  List<CustomEventType> getAllCustomEventTypes() {
    return _customEventTypesBox?.values.toList() ?? [];
  }

  CustomEventType? getCustomEventType(String id) {
    return _customEventTypesBox?.get(id);
  }

  int getCustomEventTypeCount() {
    return _customEventTypesBox?.length ?? 0;
  }

  // Settings operations
  Future<void> saveSetting(String key, dynamic value) async {
    if (_settingsBox == null) {
      debugPrint('Settings box not initialized, cannot save setting: $key');
      return;
    }
    await _settingsBox!.put(key, value);
  }

  dynamic getSetting(String key, {dynamic defaultValue}) {
    return _settingsBox?.get(key, defaultValue: defaultValue) ?? defaultValue;
  }

  bool getNotificationsEnabled() {
    return getSetting('notificationsEnabled', defaultValue: true) as bool;
  }

  List<int> getNotificationDays() {
    final days = getSetting('notificationDays', defaultValue: [0, 1, 7]);
    if (days is List) {
      return days.cast<int>();
    }
    return [0, 1, 7];
  }

  int getNotificationHour() {
    return getSetting('notificationHour', defaultValue: 8) as int;
  }

  int getNotificationMinute() {
    return getSetting('notificationMinute', defaultValue: 0) as int;
  }

  Future<void> setNotificationTime(int hour, int minute) async {
    await saveSetting('notificationHour', hour);
    await saveSetting('notificationMinute', minute);
  }

  // Filter settings
  String getFilterType() {
    return getSetting('filterType', defaultValue: 'all') as String;
  }

  Future<void> setFilterType(String filterType) async {
    await saveSetting('filterType', filterType);
  }

  int getTimeRange() {
    return getSetting('timeRange', defaultValue: 365) as int;
  }

  Future<void> setTimeRange(int timeRange) async {
    await saveSetting('timeRange', timeRange);
  }

  bool isOnboardingComplete() {
    return getSetting('onboardingComplete', defaultValue: false) == true;
  }

  Future<void> setOnboardingComplete() async {
    await saveSetting('onboardingComplete', true);
  }

  /// `all`, or the trimmed group name. Empty string means Ungrouped.
  String getGroupFilter() {
    return getSetting('groupFilter', defaultValue: 'all') as String;
  }

  Future<void> setGroupFilter(String groupFilter) async {
    await saveSetting('groupFilter', groupFilter);
  }

  Map<String, dynamic> exportSettings() {
    final box = _settingsBox;
    if (box == null) return {};
    final exported = <String, dynamic>{};
    for (final key in box.keys) {
      final value = box.get(key);
      if (_isJsonValue(value)) {
        exported[key.toString()] = value;
      }
    }
    return exported;
  }

  Future<void> importSettings(Map<String, dynamic> settings) async {
    for (final entry in settings.entries) {
      if (_isJsonValue(entry.value)) {
        await saveSetting(entry.key, entry.value);
      }
    }
  }

  bool _isJsonValue(Object? value) {
    if (value == null || value is bool || value is int || value is double || value is String) {
      return true;
    }
    if (value is List) {
      return value.every(_isJsonValue);
    }
    if (value is Map) {
      return value.values.every(_isJsonValue);
    }
    return false;
  }
}
