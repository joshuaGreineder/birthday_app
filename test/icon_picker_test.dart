import 'package:birthday_app/utils/icon_picker.dart';
import 'package:birthday_app/utils/user_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('icon picker covers every icon and the unknown fallback', () {
    expect(IconPicker.availableIcons, isNotEmpty);
    for (var i = 0; i < IconPicker.availableIcons.length; i++) {
      final icon = IconPicker.availableIcons[i];
      expect(IconPicker.getIcon(i), icon);
      expect(IconPicker.getIconIndex(icon), i);
      expect(IconPicker.getIconName(icon), isNotEmpty);
    }
    expect(IconPicker.getIcon(-1), Icons.star_rounded);
    expect(IconPicker.getIcon(IconPicker.availableIcons.length), Icons.star_rounded);
    expect(IconPicker.getIconIndex(Icons.abc), -1);
    expect(IconPicker.getIconName(Icons.abc), 'Star');
    expect(couldNot('save this event'), "Couldn't save this event. Please try again.");
  });
}
