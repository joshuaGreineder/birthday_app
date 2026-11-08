import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Home-screen widgets are drawn by the launcher through RemoteViews, which only
/// inflates a fixed set of view classes. Anything else (even a plain View used as
/// a divider) makes the launcher show "Couldn't add widget".
const _allowed = {
  'FrameLayout', 'LinearLayout', 'RelativeLayout', 'GridLayout', 'AnalogClock', 'Button',
  'Chronometer', 'ImageButton', 'ImageView', 'ProgressBar', 'TextView', 'ViewFlipper',
  'ListView', 'GridView', 'StackView', 'AdapterViewFlipper',
};

void main() {
  test('widget layouts use only RemoteViews-safe views', () {
    final files = Directory('android/app/src/main/res')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.contains('/layout') && f.uri.pathSegments.last.startsWith('widget_'))
        .toList();
    expect(files, isNotEmpty);
    final tag = RegExp(r'<([A-Za-z][\w.]*)[\s>/]');
    for (final file in files) {
      final used = tag.allMatches(file.readAsStringSync()).map((m) => m.group(1)!).toSet();
      expect(used.difference(_allowed), isEmpty, reason: '${file.path} uses views a widget cannot show');
    }
  });

  test('every launcher icon alias has its icon resources', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final icons = RegExp(r'<activity-alias[\s\S]*?android:icon="@mipmap/(\w+)"')
        .allMatches(manifest)
        .map((m) => m.group(1)!)
        .toList();
    expect(icons, ['ic_launcher', 'ic_launcher_classic', 'ic_launcher_light']);
    for (final icon in icons) {
      expect(File('android/app/src/main/res/mipmap-anydpi-v26/$icon.xml').existsSync(), isTrue);
      expect(File('android/app/src/main/res/mipmap-xxxhdpi/$icon.png').existsSync(), isTrue);
    }
  });
}
