import 'package:flutter/foundation.dart' show kIsWeb;

class Constants {
  // Base URLs - Platform-aware configuration
  static String get baseUrl {
    if (kIsWeb) {
      // Web builds point to localhost
      return 'http://localhost:3000/api';
    } else {
      // Use provided IP for external devices
      return 'http://192.168.43.233:3000/api';
    }
  }

  // Storage Keys
  static const String tokenKey = 'jwt_token';
  static const String pendingReadingsBox = 'pending_readings';
}
