import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../app_config.dart';

class AppIconOption {
  const AppIconOption(this.id, this.label, this.preview);

  final String id;
  final String label;
  final String preview;
}

/// Switches the launcher icon (Android only). Each option is an activity alias
/// in AndroidManifest.xml; exactly one is enabled at a time.
class AppIconService {
  static const MethodChannel _channel = MethodChannel(kPlatformChannel);

  static const List<AppIconOption> options = [
    AppIconOption('calendar', 'Calendar', 'assets/app_icons/calendar.png'),
    AppIconOption('classic', 'Classic', 'assets/app_icons/classic.png'),
    AppIconOption('light', 'Light', 'assets/app_icons/light.png'),
  ];

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<String> current() async {
    if (!supported) return options.first.id;
    try {
      return await _channel.invokeMethod<String>('getAppIcon') ?? options.first.id;
    } catch (e) {
      debugPrint('Could not read app icon: $e');
      return options.first.id;
    }
  }

  /// Returns true when the launcher was told to switch.
  static Future<bool> set(String id) async {
    if (!supported || !options.any((o) => o.id == id)) return false;
    try {
      await _channel.invokeMethod('setAppIcon', {'name': id});
      return true;
    } catch (e) {
      debugPrint('Could not change app icon: $e');
      return false;
    }
  }
}
