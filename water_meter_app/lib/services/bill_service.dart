import 'package:dio/dio.dart';
import '../core/dio_client.dart';
import '../models/bill.dart';

class BillService {
  final Dio _dio;

  BillService(DioClient dioClient) : _dio = dioClient.dio;

  Future<PaginatedBills> fetchBills({
    int page = 1,
    int limit = 10,
    String? status, // null = all, 'unpaid' | 'paid' | 'overdue'
  }) async {
    try {
      final params = <String, dynamic>{'page': page, 'limit': limit};
      if (status != null) params['status'] = status;

      final response = await _dio.get('/bills', queryParameters: params);
      if (response.statusCode == 200 && response.data['success'] == true) {
        return PaginatedBills.fromJson(response.data);
      }
      throw Exception(response.data['message'] ?? 'Failed to fetch bills');
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Bill> fetchBillById(String id) async {
    try {
      final response = await _dio.get('/bills/$id');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return Bill.fromJson(response.data['data']);
      }
      throw Exception(response.data['message'] ?? 'Failed to load bill details');
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<BillSummary> fetchBillsSummary() async {
    try {
      final response = await _dio.get('/bills/summary');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return BillSummary.fromJson(response.data);
      }
      throw Exception(response.data['message'] ?? 'Failed to fetch bill summary');
    } catch (e) {
      throw _handleError(e);
    }
  }

  Exception _handleError(dynamic e) {
    if (e is DioException) {
      if (e.response?.data != null) {
        final message = e.response?.data['message'] ?? 'Server error';
        return Exception(message);
      }
      return Exception('Network error: ${e.message}');
    }
    return Exception(e.toString());
  }
}
