// ignore_for_file: implementation_imports

import 'dart:typed_data';

import 'package:birthday_app/models/event.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/src/adapters/date_time_adapter.dart';
import 'package:hive/src/binary/binary_reader_impl.dart';
import 'package:hive/src/binary/binary_writer_impl.dart';
import 'package:hive/src/registry/type_registry_impl.dart';

TypeRegistryImpl _registry() {
  final registry = TypeRegistryImpl();
  registry.registerAdapter<DateTime>(DateTimeAdapter<DateTime>(), internal: true);
  registry.registerAdapter<EventType>(EventTypeAdapter());
  return registry;
}

Event _read(Uint8List bytes, TypeRegistryImpl registry) {
  return EventAdapter().read(BinaryReaderImpl(bytes, registry));
}

void main() {
  test('events saved before Group existed load with an empty group', () {
    final registry = _registry();
    final writer = BinaryWriterImpl(registry);
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write('old-id')
      ..writeByte(1)
      ..write('Ada')
      ..writeByte(2)
      ..write(EventType.birthday)
      ..writeByte(3)
      ..write(DateTime(2000, 2, 29))
      ..writeByte(4)
      ..write('a note')
      ..writeByte(5)
      ..write(null);

    final event = _read(writer.toBytes(), registry);
    expect(event.id, 'old-id');
    expect(event.name, 'Ada');
    expect(event.eventType, EventType.birthday);
    expect(event.originalDate.month, 2);
    expect(event.originalDate.day, 29);
    expect(event.notes, 'a note');
    expect(event.customEventTypeId, isNull);
    expect(event.group, '');
  });

  test('a current event keeps its group through the adapter', () {
    final registry = _registry();
    final original = Event(
      id: 'new-id',
      name: 'Grace',
      eventType: EventType.anniversary,
      originalDate: DateTime(2010, 5, 2),
      notes: null,
      customEventTypeId: 'custom-1',
      group: 'Family',
    );
    final writer = BinaryWriterImpl(registry);
    EventAdapter().write(writer, original);
    final restored = _read(writer.toBytes(), registry);
    expect(restored.group, 'Family');
    expect(restored.customEventTypeId, 'custom-1');
    expect(restored.eventType, EventType.anniversary);
    expect(restored.notes, isNull);
    expect(original.copyWith(group: 'Friends').group, 'Friends');
  });
}
