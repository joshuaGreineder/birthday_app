import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../utils/icon_picker.dart';

part 'custom_event_type.g.dart';

@HiveType(typeId: 2)
class CustomEventType extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final int primaryColorValue; // Store as int for Hive

  @HiveField(3)
  final int backgroundColorValue;

  @HiveField(4)
  final int iconCodePoint; // Material Icon code point

  @HiveField(5)
  final String turningTextTemplate; // e.g., "Turning {years} years old"
  
  @HiveField(6)
  final String nowTextTemplate; // e.g., "Now {years} years old!"
  
  @HiveField(7)
  final String currentTextTemplate; // e.g., "Currently {years} years old"

  CustomEventType({
    required this.id,
    required this.name,
    required this.primaryColorValue,
    required this.backgroundColorValue,
    required this.iconCodePoint,
    required this.turningTextTemplate,
    required this.nowTextTemplate,
    required this.currentTextTemplate,
  });

  /// A const [IconData] from the picker, so release builds can tree-shake icons.
  IconData get icon => IconPicker.iconForCodePoint(iconCodePoint);

  // Helper to get Color from stored int
  Color get primaryColor => Color(primaryColorValue);
  Color get backgroundColor => Color(backgroundColorValue);

  CustomEventType copyWith({
    String? id,
    String? name,
    int? primaryColorValue,
    int? backgroundColorValue,
    int? iconCodePoint,
    String? turningTextTemplate,
    String? nowTextTemplate,
    String? currentTextTemplate,
  }) {
    return CustomEventType(
      id: id ?? this.id,
      name: name ?? this.name,
      primaryColorValue: primaryColorValue ?? this.primaryColorValue,
      backgroundColorValue: backgroundColorValue ?? this.backgroundColorValue,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      turningTextTemplate: turningTextTemplate ?? this.turningTextTemplate,
      nowTextTemplate: nowTextTemplate ?? this.nowTextTemplate,
      currentTextTemplate: currentTextTemplate ?? this.currentTextTemplate,
    );
  }
}

