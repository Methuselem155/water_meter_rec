import 'package:dio/dio.dart';
import '../core/dio_client.dart';
import '../models/reading.dart';

class ReadingService {
  final Dio _dio;

  ReadingService(DioClient dioClient) : _dio = dioClient.dio;

  Future<PaginatedReadings> fetchReadings({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final response = await _dio.get(
        '/readings',
        queryParameters: {'page': page, 'limit': limit},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return PaginatedReadings.fromJson(response.data);
      }
      throw Exception(response.data['message'] ?? 'Failed to fetch readings');
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }

  Future<Reading> fetchReadingById(String id) async {
    try {
      final response = await _dio.get('/readings/$id');
      if (response.statusCode == 200 && response.data['success'] == true) {
        // Parse from nested data payload
        return Reading.fromJson(response.data['data']['reading']);
      }
      throw Exception(
        response.data['message'] ?? 'Failed to load reading details',
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw Exception('Error: ${e.toString()}');
    }
  }

  Exception _handleDioError(DioException e) {
    if (e.response != null && e.response?.data != null) {
      final message = e.response?.data['message'] ?? 'Server error';
      return Exception(message);
    }

    String errorMsg;
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        errorMsg = 'Connection timeout - server not responding';
        break;
      case DioExceptionType.receiveTimeout:
        errorMsg = 'Response timeout - server took too long';
        break;
      case DioExceptionType.badResponse:
        errorMsg = 'Server error: ${e.response?.statusCode}';
        break;
      case DioExceptionType.cancel:
        errorMsg = 'Request cancelled';
        break;
      case DioExceptionType.connectionError:
        errorMsg = 'No internet connection';
        break;
      case DioExceptionType.unknown:
        errorMsg = e.message ?? 'Network error';
        break;
      default:
        errorMsg = 'Network error';
    }
    return Exception(errorMsg);
  }
}
