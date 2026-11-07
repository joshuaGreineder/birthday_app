import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/custom_event_type.dart';
import '../models/event.dart';
import '../utils/event_calculator.dart';
import '../utils/yearless_date.dart';
import 'storage_service.dart';

class RowProblem {
  final int rowNumber;
  final String message;

  const RowProblem(this.rowNumber, this.message);

  @override
  String toString() => 'Row $rowNumber: $message';
}

class PreviewEvent {
  final int? rowNumber;
  final Event event;
  final String typeLabel;

  const PreviewEvent({
    required this.rowNumber,
    required this.event,
    required this.typeLabel,
  });
}

class ImportPreview {
  final String? fileError;
  final List<PreviewEvent> added;
  final List<PreviewEvent> duplicates;
  final List<RowProblem> problems;
  final List<CustomEventType> newCustomTypes;
  final Map<String, dynamic>? settings;

  const ImportPreview({
    this.fileError,
    this.added = const [],
    this.duplicates = const [],
    this.problems = const [],
    this.newCustomTypes = const [],
    this.settings,
  });

  bool get canApply =>
      fileError == null &&
      (added.isNotEmpty || newCustomTypes.isNotEmpty || (settings != null && settings!.isNotEmpty));
}

class BackupCodec {
  static const int schemaVersion = 1;

  const BackupCodec();

  String exportJson({
    required List<Event> events,
    required List<CustomEventType> customTypes,
    required Map<String, dynamic> settings,
  }) {
    final payload = {
      'schemaVersion': schemaVersion,
      'events': events.map((event) => _eventToJson(event, customTypes)).toList(),
      'customEventTypes': customTypes.map(_typeToJson).toList(),
      'settings': settings,
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  String exportCsv({
    required List<Event> events,
    required List<CustomEventType> customTypes,
  }) {
    final lines = <String>['Name,Date,Type,Group,Notes'];
    for (final event in events) {
      lines.add([
        _csvField(event.name),
        _csvField(formatExportDate(event.originalDate)),
        _csvField(typeLabel(event, customTypes)),
        _csvField(event.group),
        _csvField(event.notes ?? ''),
      ].join(','));
    }
    return '${lines.join('\r\n')}\r\n';
  }

  ImportPreview preview({
    required String fileName,
    required String contents,
    required List<Event> existingEvents,
    required List<CustomEventType> existingTypes,
  }) {
    try {
      if (_looksLikeJson(fileName, contents)) {
        return _previewJson(contents, existingEvents, existingTypes);
      }
      return _previewCsv(contents, existingEvents, existingTypes);
    } on FormatException catch (error) {
      return ImportPreview(fileError: error.message);
    } catch (error) {
      return const ImportPreview(
        fileError: 'This file could not be read. Use a Happaroo JSON backup or a CSV with a header row.',
      );
    }
  }

  Future<void> apply(StorageService storage, ImportPreview preview) async {
    if (preview.fileError != null || !preview.canApply) return;
    for (final type in preview.newCustomTypes) {
      await storage.saveCustomEventType(type);
    }
    for (final row in preview.added) {
      await storage.addEvent(row.event);
    }
    final settings = preview.settings;
    if (settings != null && settings.isNotEmpty) {
      await storage.importSettings(settings);
    }
  }

  static String formatExportDate(DateTime date) => formatStoredDate(date);

  static String typeLabel(Event event, List<CustomEventType> types) {
    final customId = event.customEventTypeId;
    if (customId != null) {
      for (final type in types) {
        if (type.id == customId) return type.name;
      }
    }
    return event.eventType == EventType.birthday ? 'Birthday' : 'Anniversary';
  }

  ImportPreview _previewCsv(
    String contents,
    List<Event> existingEvents,
    List<CustomEventType> existingTypes,
  ) {
    final rows = parseCsv(contents);
    if (rows.isEmpty) {
      return const ImportPreview(fileError: 'The CSV file is empty.');
    }
    final header = rows.first.map((cell) => cell.trim().toLowerCase()).toList();
    final columns = <String, int>{};
    for (var i = 0; i < header.length; i++) {
      columns.putIfAbsent(header[i], () => i);
    }
    for (final required in ['name', 'date', 'type']) {
      if (!columns.containsKey(required)) {
        return ImportPreview(
          fileError: 'The CSV header is missing a $required column. Expected Name, Date, Type, Group, and Notes.',
        );
      }
    }

    final types = List<CustomEventType>.from(existingTypes);
    final newTypes = <CustomEventType>[];
    final added = <PreviewEvent>[];
    final duplicates = <PreviewEvent>[];
    final problems = <RowProblem>[];
    final seen = _keysOf(existingEvents, types);

    for (var index = 1; index < rows.length; index++) {
      final rowNumber = index + 1;
      final row = rows[index];
      String cell(String name) {
        final column = columns[name];
        if (column == null || column >= row.length) return '';
        return row[column].trim();
      }

      final name = cell('name');
      final dateText = cell('date');
      final typeText = cell('type');
      final group = cell('group');
      final notes = cell('notes');

      if (name.isEmpty) {
        problems.add(RowProblem(rowNumber, 'Name is blank.'));
        continue;
      }
      if (typeText.isEmpty) {
        problems.add(RowProblem(rowNumber, 'Type is blank.'));
        continue;
      }
      final parsed = parseEventDate(dateText);
      if (parsed.error != null || parsed.date == null) {
        problems.add(RowProblem(rowNumber, parsed.error ?? 'Date could not be read.'));
        continue;
      }

      final resolved = _resolveType(
        typeText: typeText,
        types: types,
        newTypes: newTypes,
      );
      final event = Event(
        id: 'import_csv_$rowNumber',
        name: name,
        eventType: resolved.eventType,
        originalDate: parsed.date!,
        notes: notes.isEmpty ? null : notes,
        customEventTypeId: resolved.customType?.id,
        group: group,
      );
      final key = _eventKey(name, parsed.date!, resolved.label);
      if (seen.contains(key)) {
        duplicates.add(PreviewEvent(rowNumber: rowNumber, event: event, typeLabel: resolved.label));
        continue;
      }
      seen.add(key);
      added.add(PreviewEvent(rowNumber: rowNumber, event: event, typeLabel: resolved.label));
    }

    return ImportPreview(
      added: added,
      duplicates: duplicates,
      problems: problems,
      newCustomTypes: newTypes,
    );
  }

  ImportPreview _previewJson(
    String contents,
    List<Event> existingEvents,
    List<CustomEventType> existingTypes,
  ) {
    final decoded = jsonDecode(contents);
    if (decoded is! Map) {
      return const ImportPreview(fileError: 'The JSON backup must be an object.');
    }
    final version = decoded['schemaVersion'];
    if (version != schemaVersion) {
      return ImportPreview(
        fileError: 'This backup uses schema version $version, which this version of Happaroo cannot read.',
      );
    }

    final types = List<CustomEventType>.from(existingTypes);
    final newTypes = <CustomEventType>[];
    final rawTypes = decoded['customEventTypes'];
    if (rawTypes != null) {
      if (rawTypes is! List) {
        return const ImportPreview(fileError: 'customEventTypes must be a list.');
      }
      for (var i = 0; i < rawTypes.length; i++) {
        final parsed = _parseCustomType(rawTypes[i], i + 1);
        if (parsed.error != null || parsed.type == null) {
          return ImportPreview(fileError: parsed.error);
        }
        final type = parsed.type!;
        if (_findType(types, id: type.id, name: type.name) != null) continue;
        types.add(type);
        newTypes.add(type);
      }
    }

    final rawEvents = decoded['events'];
    if (rawEvents is! List) {
      return const ImportPreview(fileError: 'The backup is missing an events list.');
    }

    final added = <PreviewEvent>[];
    final duplicates = <PreviewEvent>[];
    final problems = <RowProblem>[];
    final seen = _keysOf(existingEvents, types);
    final usedIds = existingEvents.map((event) => event.id).toSet();

    for (var i = 0; i < rawEvents.length; i++) {
      final rowNumber = i + 1;
      final item = rawEvents[i];
      if (item is! Map) {
        problems.add(RowProblem(rowNumber, 'Event is not an object.'));
        continue;
      }
      final name = (item['name'] ?? '').toString().trim();
      final typeText = (item['type'] ?? '').toString().trim();
      final dateText = (item['date'] ?? '').toString().trim();
      final group = (item['group'] ?? '').toString();
      final notes = (item['notes'] ?? '').toString();
      final requestedId = (item['id'] ?? '').toString();
      final requestedCustomId = item['customEventTypeId']?.toString();

      if (name.isEmpty) {
        problems.add(RowProblem(rowNumber, 'Name is blank.'));
        continue;
      }
      if (typeText.isEmpty) {
        problems.add(RowProblem(rowNumber, 'Type is blank.'));
        continue;
      }
      final parsed = parseEventDate(dateText);
      if (parsed.error != null || parsed.date == null) {
        problems.add(RowProblem(rowNumber, parsed.error ?? 'Date could not be read.'));
        continue;
      }

      final resolved = _resolveType(
        typeText: typeText,
        types: types,
        newTypes: newTypes,
        preferredId: requestedCustomId,
      );
      var id = requestedId.isEmpty ? 'import_json_$rowNumber' : requestedId;
      if (usedIds.contains(id)) {
        id = '${id}_$rowNumber';
      }
      usedIds.add(id);
      final event = Event(
        id: id,
        name: name,
        eventType: resolved.eventType,
        originalDate: parsed.date!,
        notes: notes.isEmpty ? null : notes,
        customEventTypeId: resolved.customType?.id,
        group: group,
      );
      final key = _eventKey(name, parsed.date!, resolved.label);
      if (seen.contains(key)) {
        duplicates.add(PreviewEvent(rowNumber: rowNumber, event: event, typeLabel: resolved.label));
        continue;
      }
      seen.add(key);
      added.add(PreviewEvent(rowNumber: rowNumber, event: event, typeLabel: resolved.label));
    }

    Map<String, dynamic>? settings;
    final rawSettings = decoded['settings'];
    if (rawSettings is Map) {
      settings = rawSettings.map((key, value) => MapEntry(key.toString(), value));
    }

    return ImportPreview(
      added: added,
      duplicates: duplicates,
      problems: problems,
      newCustomTypes: newTypes,
      settings: settings,
    );
  }

  _ResolvedType _resolveType({
    required String typeText,
    required List<CustomEventType> types,
    required List<CustomEventType> newTypes,
    String? preferredId,
  }) {
    final normalized = typeText.trim().toLowerCase();
    if (normalized == 'birthday') {
      return const _ResolvedType(EventType.birthday, 'Birthday', null);
    }
    if (normalized == 'anniversary') {
      return const _ResolvedType(EventType.anniversary, 'Anniversary', null);
    }

    final existing = _findType(types, id: preferredId, name: typeText);
    if (existing != null) {
      return _ResolvedType(EventType.birthday, existing.name, existing);
    }

    final created = _newCustomType(typeText, preferredId, types.length + newTypes.length);
    types.add(created);
    newTypes.add(created);
    return _ResolvedType(EventType.birthday, created.name, created);
  }

  CustomEventType _newCustomType(String name, String? preferredId, int salt) {
    final id = (preferredId != null && preferredId.isNotEmpty)
        ? preferredId
        : 'import_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}_$salt';
    return CustomEventType(
      id: id,
      name: name.trim(),
      primaryColorValue: 0xFF8B5CF6,
      backgroundColorValue: 0xFFEDE9FE,
      iconCodePoint: Icons.star_rounded.codePoint,
      turningTextTemplate: 'Turning {years}',
      nowTextTemplate: 'Now {years}!',
      currentTextTemplate: 'Currently {years}',
    );
  }

  CustomEventType? _findType(List<CustomEventType> types, {String? id, String? name}) {
    if (id != null && id.isNotEmpty) {
      for (final type in types) {
        if (type.id == id) return type;
      }
    }
    if (name != null) {
      final normalized = name.trim().toLowerCase();
      for (final type in types) {
        if (type.name.trim().toLowerCase() == normalized) return type;
      }
    }
    return null;
  }

  ({CustomEventType? type, String? error}) _parseCustomType(Object? raw, int index) {
    if (raw is! Map) {
      return (type: null, error: 'Custom type $index is not an object.');
    }
    final name = (raw['name'] ?? '').toString().trim();
    final id = (raw['id'] ?? '').toString().trim();
    if (name.isEmpty || id.isEmpty) {
      return (type: null, error: 'Custom type $index needs a name and an id.');
    }
    int asInt(Object? value, int fallback) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return fallback;
    }

    return (
      type: CustomEventType(
        id: id,
        name: name,
        primaryColorValue: asInt(raw['primaryColorValue'], 0xFF8B5CF6),
        backgroundColorValue: asInt(raw['backgroundColorValue'], 0xFFEDE9FE),
        iconCodePoint: asInt(raw['iconCodePoint'], Icons.star_rounded.codePoint),
        turningTextTemplate: (raw['turningTextTemplate'] ?? 'Turning {years}').toString(),
        nowTextTemplate: (raw['nowTextTemplate'] ?? 'Now {years}!').toString(),
        currentTextTemplate: (raw['currentTextTemplate'] ?? 'Currently {years}').toString(),
      ),
      error: null,
    );
  }

  Set<String> _keysOf(List<Event> events, List<CustomEventType> types) {
    return events.map((event) {
      final date = DateTime(event.originalDate.year, event.originalDate.month, event.originalDate.day);
      return _eventKey(event.name, date, typeLabel(event, types));
    }).toSet();
  }

  String _eventKey(String name, DateTime date, String label) {
    return '${name.trim().toLowerCase()}|${date.year}|${date.month}|${date.day}|${label.trim().toLowerCase()}';
  }

  bool _looksLikeJson(String fileName, String contents) {
    final trimmed = contents.trimLeft();
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) return true;
    return fileName.toLowerCase().endsWith('.json');
  }

  Map<String, dynamic> _eventToJson(Event event, List<CustomEventType> types) {
    return {
      'id': event.id,
      'name': event.name,
      'date': formatExportDate(event.originalDate),
      'type': typeLabel(event, types),
      'group': event.group,
      'notes': event.notes ?? '',
      'customEventTypeId': event.customEventTypeId,
    };
  }

  Map<String, dynamic> _typeToJson(CustomEventType type) {
    return {
      'id': type.id,
      'name': type.name,
      'primaryColorValue': type.primaryColorValue,
      'backgroundColorValue': type.backgroundColorValue,
      'iconCodePoint': type.iconCodePoint,
      'turningTextTemplate': type.turningTextTemplate,
      'nowTextTemplate': type.nowTextTemplate,
      'currentTextTemplate': type.currentTextTemplate,
    };
  }

  static String _csvField(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n') || value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}

class ParsedEventDate {
  final DateTime? date;
  final String? error;

  const ParsedEventDate({this.date, this.error});
}

/// Accepts YYYY-MM-DD, MM/DD/YYYY, M/D/YYYY, and month/day with no year (`M/D` or `M-D`).
/// A date with no year is stored as year 4, the leap-year sentinel. Slash or dash
/// dates with a leading month use US order when the first number can be a month.
ParsedEventDate parseEventDate(String raw) {
  final value = raw.trim();
  if (value.isEmpty) {
    return const ParsedEventDate(error: 'Date is blank.');
  }
  final monthDay = RegExp(r'^(\d{1,2})[/-](\d{1,2})$').firstMatch(value);
  if (monthDay != null) {
    return _buildDate(
      kYearlessSentinelYear,
      int.parse(monthDay.group(1)!),
      int.parse(monthDay.group(2)!),
      value,
    );
  }

  final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(value);
  if (iso != null) {
    return _buildDate(
      int.parse(iso.group(1)!),
      int.parse(iso.group(2)!),
      int.parse(iso.group(3)!),
      value,
    );
  }

  final us = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})$').firstMatch(value);
  if (us != null) {
    return _buildDate(
      int.parse(us.group(3)!),
      int.parse(us.group(1)!),
      int.parse(us.group(2)!),
      value,
    );
  }

  return ParsedEventDate(
    error: '"$value" is not a valid date. Use YYYY-MM-DD or M/D/YYYY.',
  );
}

ParsedEventDate _buildDate(int year, int month, int day, String original) {
  if (month < 1 || month > 12 || day < 1) {
    return ParsedEventDate(error: '"$original" is not a valid date.');
  }
  if (month == 2 && day == 29 && !EventCalculator.isLeapYear(year)) {
    return ParsedEventDate(error: 'February 29 is not a valid date in $year.');
  }
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) {
    return ParsedEventDate(error: '"$original" is not a valid date.');
  }
  return ParsedEventDate(date: DateTime(year, month, day));
}

/// RFC-style CSV records. Quoted fields may contain commas, quotes, and line breaks.
List<List<String>> parseCsv(String input) {
  var text = input;
  if (text.startsWith('\uFEFF')) text = text.substring(1);
  final rows = <List<String>>[];
  final row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;

  void finishField() {
    row.add(field.toString());
    field.clear();
  }

  void finishRow() {
    finishField();
    if (row.any((cell) => cell.trim().isNotEmpty)) {
      rows.add(List<String>.from(row));
    }
    row.clear();
  }

  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    if (inQuotes) {
      if (char == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field.write(char);
      }
      continue;
    }
    if (char == '"') {
      inQuotes = true;
    } else if (char == ',') {
      finishField();
    } else if (char == '\n') {
      finishRow();
    } else if (char == '\r') {
      if (i + 1 < text.length && text[i + 1] == '\n') i++;
      finishRow();
    } else {
      field.write(char);
    }
  }
  if (inQuotes) {
    throw const FormatException('A quoted field in the CSV was not closed.');
  }
  if (field.isNotEmpty || row.isNotEmpty) {
    finishRow();
  }
  return rows;
}

class _ResolvedType {
  final EventType eventType;
  final String label;
  final CustomEventType? customType;

  const _ResolvedType(this.eventType, this.label, this.customType);
}
