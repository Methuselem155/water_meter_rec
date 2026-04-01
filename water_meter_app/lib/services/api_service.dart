import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import '../core/dio_client.dart';
import '../data/local/pending_reading.dart';
import '../models/reading.dart';
import '../providers/auth_provider.dart';

class ApiService {
  final Dio _dio;

  ApiService(DioClient dioClient) : _dio = dioClient.dio;

  /// New scan flow: send two pre-cropped images (display + serial).
  /// Backend runs focused OCR on each crop and returns the full reading.
  Future<({Map<String, dynamic> raw, Reading? reading})> scanReading({
    required String displayCropPath,
    String? serialCropPath,
  }) async {
    final fields = <String, dynamic>{
      'display': await MultipartFile.fromFile(
        displayCropPath,
        filename: 'display.jpg',
      ),
    };
    if (serialCropPath != null) {
      fields['serial'] = await MultipartFile.fromFile(
        serialCropPath,
        filename: 'serial.jpg',
      );
    }

    final response = await _dio.post(
      '/readings/scan',
      data: FormData.fromMap(fields),
      options: Options(
        headers: {'X-Platform': kIsWeb ? 'web' : 'mobile'},
        receiveTimeout: const Duration(minutes: 3),
        sendTimeout: const Duration(minutes: 2),
      ),
    );

    if (response.statusCode == 201 && response.data['success'] == true) {
      final raw = response.data as Map<String, dynamic>;
      Reading? parsed;
      try {
        final readingData = raw['data']?['reading'];
        if (readingData != null) {
          parsed = Reading.fromJson(readingData as Map<String, dynamic>);
        }
      } catch (_) {}
      return (raw: raw, reading: parsed);
    }
    throw Exception(response.data['message'] ?? 'Scan failed');
  }

  /// Legacy full-image upload (kept for offline sync fallback).
  Future<({Map<String, dynamic> raw, Reading? reading})> uploadReading(
    PendingReading reading, {
    bool awaitOcr = true,
  }) async {
    final formData = FormData.fromMap({
      if (reading.readingValue != null) 'readingValue': reading.readingValue,
      'image': kIsWeb
          ? MultipartFile.fromBytes(
              await XFile(reading.imagePath).readAsBytes(),
              filename: 'reading_${reading.id}.jpg',
            )
          : await MultipartFile.fromFile(
              reading.imagePath,
              filename: 'reading_${reading.id}.jpg',
            ),
    });

    final url = awaitOcr
        ? '/readings/upload?awaitOcr=true'
        : '/readings/upload?awaitOcr=false';

    final response = await _dio.post(
      url,
      data: formData,
      options: Options(
        headers: {'X-Platform': kIsWeb ? 'web' : 'mobile'},
        receiveTimeout: const Duration(minutes: 5),
        sendTimeout: const Duration(minutes: 2),
      ),
    );

    if (response.statusCode == 201 && response.data['success'] == true) {
      final raw = response.data as Map<String, dynamic>;
      Reading? parsed;
      try {
        final readingData = raw['data']?['reading'];
        if (readingData != null) {
          parsed = Reading.fromJson(readingData as Map<String, dynamic>);
        }
      } catch (_) {}
      return (raw: raw, reading: parsed);
    }
    throw Exception(response.data['message'] ?? 'Upload failed');
  }
}

final apiServiceProvider = Provider<ApiService>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return ApiService(dioClient);
});
