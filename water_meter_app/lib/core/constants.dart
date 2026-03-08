import 'package:flutter/foundation.dart' show kIsWeb;

class Constants {
  // Base URLs - Platform-aware configuration
  static String get baseUrl {
    if (kIsWeb) {
      // Web builds point to localhost
      return 'http://localhost:3000/api';
    } else {
      // Mobile emulator: 10.0.2.2 is the localhost alias for Android Emulator
      // For iOS Simulator, you might need to use 127.0.0.1:3000
      return 'http://10.0.2.2:3000/api';
    }
  }

  // Storage Keys
  static const String tokenKey = 'jwt_token';
  static const String pendingReadingsBox = 'pending_readings';
}
