import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../core/constants.dart';
import '../models/auth_request.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

class AuthRepository {
  final AuthService _authService;
  final FlutterSecureStorage _storage;

  // Simple in-memory storage for web (not secure, only for development)
  static String? _webToken;

  AuthRepository(this._authService) : _storage = const FlutterSecureStorage();

  Future<User> login(LoginRequest request) async {
    final response = await _authService.login(request);

    // Secure save the token
    await _saveToken(response.token);

    return response.user;
  }

  Future<User> register(RegisterRequest request) async {
    final response = await _authService.register(request);

    // Automatically log user in upon successful registration
    await _saveToken(response.token);

    return response.user;
  }

  Future<User> getMe() async {
    return await _authService.getMe();
  }

  Future<void> logout() async {
    await _deleteToken();
  }

  Future<bool> hasToken() async {
    final token = await _getToken();
    return token != null && token.isNotEmpty;
  }

  Future<String?> getToken() async {
    return await _getToken();
  }

  // Platform-aware token storage
  Future<void> _saveToken(String token) async {
    if (kIsWeb) {
      _webToken = token;
    } else {
      await _storage.write(key: Constants.tokenKey, value: token);
    }
  }

  Future<String?> _getToken() async {
    if (kIsWeb) {
      return _webToken;
    } else {
      return await _storage.read(key: Constants.tokenKey);
    }
  }

  Future<void> _deleteToken() async {
    if (kIsWeb) {
      _webToken = null;
    } else {
      await _storage.delete(key: Constants.tokenKey);
    }
  }
}
