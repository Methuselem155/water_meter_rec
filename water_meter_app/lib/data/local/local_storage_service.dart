import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import 'pending_reading.dart';

class LocalStorageService {
  late final Box<PendingReading> _pendingBox;

  // Expected to be initialized during app startup before UI renders
  Future<void> init() async {
    // Adapter registration happens in main, just ensure box is opened using generated type
    _pendingBox = await Hive.openBox<PendingReading>(Constants.pendingReadingsBox);
  }

  Future<void> savePendingReading(PendingReading reading) async {
    await _pendingBox.put(reading.id, reading);
  }

  Future<void> updatePendingReading(PendingReading reading) async {
    await reading.save();
  }

  Future<void> deletePendingReading(String id) async {
    await _pendingBox.delete(id);
  }

  List<PendingReading> getPendingReadings() {
    return _pendingBox.values.where((reading) => reading.status == 'pending').toList();
  }
  
  List<PendingReading> getFailedReadings() {
    return _pendingBox.values.where((reading) => reading.status == 'failed').toList();
  }

  int get pendingCount => getPendingReadings().length;

  // Stream to allow UI Badges to reactively update without constant manual checks
  Stream<BoxEvent> watchPendingReadings() {
    return _pendingBox.watch();
  }
}

// Global Provider for Local Storage logic - async to ensure initialization
final localStorageProvider = FutureProvider<LocalStorageService>((ref) async {
  final service = LocalStorageService(); 
  await service.init();
  return service;
});
