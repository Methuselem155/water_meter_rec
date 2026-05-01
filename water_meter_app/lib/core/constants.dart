import 'package:flutter/foundation.dart' show kIsWeb;

class Constants {
  // Base URLs - Platform-aware configuration
  static String get baseUrl {
    if (kIsWeb) {
      // Web builds point to localhost
      return 'https://stream-sudoku-armchair.ngrok-free.dev/api';
    } else {
      // Mobile: run `npm run patch-url` to auto-update this to the current ngrok URL
      return 'https://stream-sudoku-armchair.ngrok-free.dev/api';
    }
  }

  // Storage Keys
  static const String tokenKey = 'jwt_token';
  static const String pendingReadingsBox = 'pending_readings';
}
