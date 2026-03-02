// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'custom_event_type.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CustomEventTypeAdapter extends TypeAdapter<CustomEventType> {
  @override
  final int typeId = 2;

  @override
  CustomEventType read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CustomEventType(
      id: fields[0] as String,
      name: fields[1] as String,
      primaryColorValue: fields[2] as int,
      backgroundColorValue: fields[3] as int,
      iconCodePoint: fields[4] as int,
      turningTextTemplate: fields[5] as String,
      nowTextTemplate: fields[6] as String,
      currentTextTemplate: fields[7] as String,
    );
  }

  @override
  void write(BinaryWriter writer, CustomEventType obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.primaryColorValue)
      ..writeByte(3)
      ..write(obj.backgroundColorValue)
      ..writeByte(4)
      ..write(obj.iconCodePoint)
      ..writeByte(5)
      ..write(obj.turningTextTemplate)
      ..writeByte(6)
      ..write(obj.nowTextTemplate)
      ..writeByte(7)
      ..write(obj.currentTextTemplate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomEventTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
