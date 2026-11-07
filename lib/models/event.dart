import 'package:hive/hive.dart';

part 'event.g.dart';

@HiveType(typeId: 1)
enum EventType {
  @HiveField(0)
  birthday,
  @HiveField(1)
  anniversary,
}

@HiveType(typeId: 0)
class Event extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final EventType eventType;

  @HiveField(3)
  final DateTime originalDate;

  @HiveField(4)
  final String? notes;

  @HiveField(5)
  final String? customEventTypeId; // ID of custom event type if using one

  /// Optional label such as "Family". Field index 6 is new; older saves omit it.
  @HiveField(6)
  final String group;

  Event({
    required this.id,
    required this.name,
    required this.eventType,
    required this.originalDate,
    this.notes,
    this.customEventTypeId,
    this.group = '',
  });

  Event copyWith({
    String? id,
    String? name,
    EventType? eventType,
    DateTime? originalDate,
    String? notes,
    String? customEventTypeId,
    String? group,
  }) {
    return Event(
      id: id ?? this.id,
      name: name ?? this.name,
      eventType: eventType ?? this.eventType,
      originalDate: originalDate ?? this.originalDate,
      notes: notes ?? this.notes,
      customEventTypeId: customEventTypeId ?? this.customEventTypeId,
      group: group ?? this.group,
    );
  }
}

