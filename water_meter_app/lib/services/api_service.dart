import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/dio_client.dart';
import '../data/local/pending_reading.dart';
import '../providers/auth_provider.dart';

class ApiService {
  final Dio _dio;

  ApiService(DioClient dioClient) : _dio = dioClient.dio;

  Future<bool> uploadReading(PendingReading reading) async {
    try {
      // API expects multipart/form-data with the image
      // Attached using MultipartFile mapper
      FormData formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          reading.imagePath,
          filename: 'reading_${reading.id}.jpg',
        ),
        // In reality, the backend route /api/readings/upload currently just auto-assigns
        // to the user's active meter. If the backend needs specifics, we pass them here.
      });

      final response = await _dio.post('/readings/upload', data: formData);

      // We expect HTTP 201 Created for successful upload
      if (response.statusCode == 201 && response.data['success'] == true) {
        return true;
      }
      return false;
    } catch (e) {
      print('HTTP Upload Error: ${e.toString()}');
      return false; // Safely fail so Workmanager can retry later
    }
  }
}

final apiServiceProvider = Provider<ApiService>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return ApiService(dioClient);
});
