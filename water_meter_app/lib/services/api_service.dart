import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import '../core/dio_client.dart';
import '../data/local/pending_reading.dart';
import '../providers/auth_provider.dart';

class ApiService {
  final Dio _dio;

  ApiService(DioClient dioClient) : _dio = dioClient.dio;

  Future<Map<String, dynamic>?> uploadReading(PendingReading reading, {bool awaitOcr = false}) async {
    try {
      // API expects multipart/form-data with the image
      // Attached using MultipartFile mapper
      FormData formData = FormData.fromMap({
        'image': kIsWeb
            ? MultipartFile.fromBytes(
                await XFile(reading.imagePath).readAsBytes(),
                filename: 'reading_${reading.id}.jpg',
              )
            : await MultipartFile.fromFile(
                reading.imagePath,
                filename: 'reading_${reading.id}.jpg',
              ),
        // In reality, the backend route /api/readings/upload currently just auto-assigns
        // to the user's active meter. If the backend needs specifics, we pass them here.
      });

      final url = awaitOcr ? '/readings/upload?awaitOcr=true' : '/readings/upload';
      final response = await _dio.post(url, data: formData);

      // We expect HTTP 201 Created for successful upload
      if (response.statusCode == 201 && response.data['success'] == true) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('HTTP Upload Error: ${e.toString()}');
      return null; // Safely fail so Workmanager can retry later
    }
  }
}

final apiServiceProvider = Provider<ApiService>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return ApiService(dioClient);
});
