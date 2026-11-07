import 'package:flutter/services.dart';

import '../app_config.dart';

class LinkService {
  static const MethodChannel _channel = MethodChannel(kPlatformChannel);

  /// Opens [url] in the Android browser. Returns false when the platform cannot open it.
  static Future<bool> open(String url) async {
    try {
      final opened = await _channel.invokeMethod<bool>('openUrl', {'url': url});
      return opened == true;
    } catch (_) {
      return false;
    }
  }
}
