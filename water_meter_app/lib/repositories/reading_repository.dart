import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/reading.dart';
import '../services/reading_service.dart';
import '../providers/auth_provider.dart';

class ReadingRepository {
  final ReadingService _readingService;

  ReadingRepository(this._readingService);

  Future<PaginatedReadings> getReadings({int page = 1, int limit = 10}) {
    return _readingService.fetchReadings(page: page, limit: limit);
  }

  Future<Reading> getReadingById(String id) {
    return _readingService.fetchReadingById(id);
  }
}

// ----------------------------------------------------
// Providers
// ----------------------------------------------------
final readingServiceProvider = Provider<ReadingService>((ref) {
  final dio = ref.watch(dioClientProvider);
  return ReadingService(dio);
});

final readingRepositoryProvider = Provider<ReadingRepository>((ref) {
  final service = ref.watch(readingServiceProvider);
  return ReadingRepository(service);
});
