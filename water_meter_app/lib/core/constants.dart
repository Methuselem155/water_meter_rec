import 'package:flutter/foundation.dart' show kIsWeb;

class Constants {
  // Local WiFi IP — phone and PC must be on the same network/hotspot
  // Your current IP: 192.168.43.233
  // To update: run `ipconfig` on Windows, copy the Wi-Fi IPv4 address
  static const String _ngrokUrl = 'https://stream-sudoku-armchair.ngrok-free.dev';

  static String get baseUrl {
    if (kIsWeb) {
      return '$_ngrokUrl/api';
    } else {
      return '$_ngrokUrl/api';
    }
  }

  // Storage Keys
  static const String tokenKey = 'jwt_token';
  static const String pendingReadingsBox = 'pending_readings';
}
