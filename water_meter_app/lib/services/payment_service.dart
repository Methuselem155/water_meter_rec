import 'package:dio/dio.dart';
import '../core/dio_client.dart';

class PaymentService {
  final Dio _dio;

  PaymentService(DioClient dioClient) : _dio = dioClient.dio;

  Future<String> initiateCashin(String billId, String phoneNumber) async {
    try {
      final response = await _dio.post('/payments/cashin', data: {
        'billId': billId,
        'phoneNumber': phoneNumber,
      });
      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data']['ref'] as String;
      }
      throw Exception(response.data['message'] ?? 'Payment initiation failed');
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getTransactionStatus(String ref) async {
    try {
      final response = await _dio.get('/payments/status/$ref');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return Map<String, dynamic>.from(response.data['data'] as Map);
      }
      throw Exception(response.data['message'] ?? 'Failed to get transaction status');
    } catch (e) {
      throw _handleError(e);
    }
  }

  Exception _handleError(dynamic e) {
    if (e is DioException) {
      final message = e.response?.data?['message'] ?? 'Network error: ${e.message}';
      return Exception(message);
    }
    return Exception(e.toString());
  }
}
