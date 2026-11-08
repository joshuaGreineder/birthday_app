import '../models/event.dart';
import '../utils/yearless_date.dart';

/// Pure mapping and diffing for Google Calendar sync. No network or plugins here,
/// so every rule is unit-tested.

/// One Happaroo event as it should appear in the Happaroo Google calendar.
class CalendarEntry {
  const CalendarEntry({
    required this.happarooId,
    required this.title,
    required this.description,
    required this.start,
    required this.recurrence,
  });

  final String happarooId;
  final String title;
  final String description;

  /// All-day start date, local calendar date (time part is midnight UTC).
  final DateTime start;
  final String recurrence;

  /// All-day events end on the following day (exclusive end).
  DateTime get endExclusive => DateTime.utc(start.year, start.month, start.day + 1);

  /// Stable fingerprint of everything that is written to Google.
  /// Stored on the remote event so unchanged events are skipped on the next sync.
  String get fingerprint => fnv1a32('$title\u0000$description\u0000${_ymd(start)}\u0000$recurrence');
}

/// A Happaroo-managed event that already exists in the Google calendar.
class RemoteEntry {
  const RemoteEntry({required this.remoteId, required this.happarooId, this.fingerprint});

  final String remoteId;
  final String happarooId;
  final String? fingerprint;
}

class SyncPlan {
  const SyncPlan({required this.create, required this.update, required this.delete});

  final List<CalendarEntry> create;

  /// Remote event id -> new content.
  final Map<String, CalendarEntry> update;

  /// Remote event ids to remove (deleted in Happaroo, or duplicates).
  final List<String> delete;

  bool get isEmpty => create.isEmpty && update.isEmpty && delete.isEmpty;
}

/// Year used for month-and-day-only events. A leap year, so February 29 exists.
const int kYearlessCalendarStartYear = 2024;

/// Builds the calendar entry for [event]. [customTypeName] is the label of the
/// event's custom type, if it has one.
CalendarEntry buildCalendarEntry(Event event, {String? customTypeName}) {
  final date = event.originalDate;
  final knownYear = !isYearlessDate(date);
  final year = knownYear ? date.year : kYearlessCalendarStartYear;
  final isLeapDay = date.month == 2 && date.day == 29;

  final label = customTypeName?.trim();
  final String title;
  if (label != null && label.isNotEmpty) {
    title = '${event.name} · $label';
  } else if (event.eventType == EventType.birthday) {
    title = "${event.name}'s birthday";
  } else {
    title = "${event.name}'s anniversary";
  }

  final lines = <String>[];
  if (knownYear) {
    lines.add(event.eventType == EventType.birthday ? 'Born $year' : 'Since $year');
  }
  final notes = event.notes?.trim();
  if (notes != null && notes.isNotEmpty) lines.add(notes);
  lines.add('Added by Happaroo. Edit this event in the app; changes here are replaced on the next sync.');

  return CalendarEntry(
    happarooId: event.id,
    title: title,
    description: lines.join('\n\n'),
    start: DateTime.utc(year, date.month, date.day),
    // February 29 falls back to the last day of February in other years,
    // matching how Happaroo observes it (February 28, never March 1).
    recurrence: isLeapDay ? 'RRULE:FREQ=YEARLY;BYMONTH=2;BYMONTHDAY=-1' : 'RRULE:FREQ=YEARLY',
  );
}

/// Works out the smallest set of changes that makes [remote] match [local].
SyncPlan planSync(List<CalendarEntry> local, List<RemoteEntry> remote) {
  final create = <CalendarEntry>[];
  final update = <String, CalendarEntry>{};
  final delete = <String>[];

  final remoteById = <String, RemoteEntry>{};
  for (final r in remote) {
    if (remoteById.containsKey(r.happarooId)) {
      delete.add(r.remoteId); // duplicate from an interrupted earlier sync
    } else {
      remoteById[r.happarooId] = r;
    }
  }

  final localIds = <String>{};
  for (final entry in local) {
    localIds.add(entry.happarooId);
    final existing = remoteById[entry.happarooId];
    if (existing == null) {
      create.add(entry);
    } else if (existing.fingerprint != entry.fingerprint) {
      update[existing.remoteId] = entry;
    }
  }

  for (final r in remoteById.values) {
    if (!localIds.contains(r.happarooId)) delete.add(r.remoteId);
  }
  return SyncPlan(create: create, update: update, delete: delete);
}

/// 32-bit FNV-1a, hex. Deterministic across runs and platforms, unlike String.hashCode.
String fnv1a32(String input) {
  var hash = 0x811c9dc5;
  for (final unit in input.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
