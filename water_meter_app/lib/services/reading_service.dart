import 'package:dio/dio.dart';
import '../core/dio_client.dart';
import '../models/reading.dart';

class ReadingService {
  final Dio _dio;

  ReadingService(DioClient dioClient) : _dio = dioClient.dio;

  Future<PaginatedReadings> fetchReadings({int page = 1, int limit = 10}) async {
    try {
      final response = await _dio.get(
        '/readings',
        queryParameters: {'page': page, 'limit': limit},
      );
      
      if (response.statusCode == 200 && response.data['success'] == true) {
        return PaginatedReadings.fromJson(response.data);
      }
      throw Exception(response.data['message'] ?? 'Failed to fetch readings');
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Reading> fetchReadingById(String id) async {
    try {
      final response = await _dio.get('/readings/$id');
      if (response.statusCode == 200 && response.data['success'] == true) {
        // Parse from nested data payload
        return Reading.fromJson(response.data['data']['reading']);
      }
      throw Exception(response.data['message'] ?? 'Failed to load reading details');
    } catch (e) {
       throw _handleError(e);
    }
  }

  Exception _handleError(dynamic e) {
    if (e is DioException) {
      if (e.response != null && e.response?.data != null) {
        final message = e.response?.data['message'] ?? 'Server error';
        return Exception(message);
      }
      return Exception('Network error: ${e.message}');
    }
    return Exception(e.toString());
  }
}
