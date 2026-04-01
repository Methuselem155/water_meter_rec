import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'constants.dart';

class DioClient {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  // Simple in-memory storage for web (not secure, only for development)
  static String? _webToken;

  DioClient()
    : _dio = Dio(
        BaseOptions(
          baseUrl: Constants.baseUrl,
          connectTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(minutes: 5),
          sendTimeout: const Duration(minutes: 2),
          headers: {'Content-Type': 'application/json'},
        ),
      ),
      _storage = const FlutterSecureStorage() {
    _initializeInterceptors();
  }

  void _initializeInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Attempt to attach JWT token to every request securely
          String? token;

          if (kIsWeb) {
            // Use in-memory storage on web
            token = _webToken;
          } else {
            // Use secure storage on mobile
            token = await _storage.read(key: Constants.tokenKey);
          }

          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          // Simple Logging
          print('===> [${options.method}] ${options.uri}');
          if (options.data != null) print('Body: ${options.data}');

          return handler.next(options);
        },
        onResponse: (response, handler) {
          print('<=== [${response.statusCode}] ${response.requestOptions.uri}');
          return handler.next(response);
        },
        onError: (DioException e, handler) {
          print(
            '<=== ERROR [${e.response?.statusCode}] ${e.requestOptions.uri}',
          );
          print('Message: ${e.message}');
          return handler.next(e);
        },
      ),
    );
  }

  // Helper methods for token management
  Future<void> saveToken(String token) async {
    if (kIsWeb) {
      _webToken = token;
    } else {
      await _storage.write(key: Constants.tokenKey, value: token);
    }
  }

  Future<String?> getToken() async {
    if (kIsWeb) {
      return _webToken;
    } else {
      return await _storage.read(key: Constants.tokenKey);
    }
  }

  Future<void> deleteToken() async {
    if (kIsWeb) {
      _webToken = null;
    } else {
      await _storage.delete(key: Constants.tokenKey);
    }
  }

  Dio get dio => _dio;
}
