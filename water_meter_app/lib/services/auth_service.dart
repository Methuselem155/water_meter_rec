import 'package:dio/dio.dart';
import '../core/dio_client.dart';
import '../models/auth_request.dart';
import '../models/auth_response.dart';
import '../models/user.dart';

class AuthService {
  final Dio _dio;

  AuthService(DioClient dioClient) : _dio = dioClient.dio;

  Future<User> getMe() async {
    try {
      final response = await _dio.get('/auth/me');

      if (response.statusCode == 200 && response.data['success'] == true) {
        final userData = response.data['data']['user'] as Map<String, dynamic>;
        return User.fromJson(userData);
      } else {
        throw _parseError(response.data);
      }
    } on DioException catch (e) {
      throw _parseDioError(e);
    } catch (e) {
      throw Exception('An unexpected error occurred: ${e.toString()}');
    }
  }

  Future<AuthResponse> login(LoginRequest request) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: request.toJson(),
      );

      // We expect 200 OK for successful login
      if (response.statusCode == 200 && response.data['success'] == true) {
        return AuthResponse.fromJson(response.data);
      } else {
        throw _parseError(response.data);
      }
    } on DioException catch (e) {
       throw _parseDioError(e);
    } catch (e) {
      throw Exception('An unexpected error occurred: ${e.toString()}');
    }
  }

  Future<AuthResponse> register(RegisterRequest request) async {
    try {
      final response = await _dio.post(
        '/auth/register',
        data: request.toJson(),
      );

      // Expected 201 Created from backend
      if (response.statusCode == 201 && response.data['success'] == true) {
        return AuthResponse.fromJson(response.data);
      } else {
        throw _parseError(response.data);
      }
    } on DioException catch (e) {
      throw _parseDioError(e);
    } catch (e) {
      throw Exception('An unexpected error occurred: ${e.toString()}');
    }
  }

  // Helper to extract cleanly formatted validation errors returned by express-validator
  String _parseError(dynamic data) {
    if (data is Map && data.containsKey('errors') && data['errors'] is List) {
       final errors = List<String>.from(data['errors']);
       if (errors.isNotEmpty) {
          return errors.join('\n'); // Stack error messages for SnackBar
       }
    }
    return data['message'] ?? 'Authentication failed';
  }

  String _parseDioError(DioException e) {
    if (e.response != null && e.response?.data != null) {
        // Backend actively rejected request (e.g., 400 Validation, 401 Unauthorized)
        return _parseError(e.response?.data);
    } else if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
        return 'Connection timed out. Please check your internet and backend server address.';
    } else if (e.type == DioExceptionType.connectionError) {
        return 'Server is unreachable. Make sure the Node.js backend is running.';
    }
    return 'Network Error: ${e.message}';
  }
}
