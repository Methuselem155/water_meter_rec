import 'package:workmanager/workmanager.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../core/dio_client.dart';
import '../data/local/pending_reading.dart';
import '../data/local/local_storage_service.dart';
import '../services/api_service.dart';
import 'dart:io';

const backgroundSyncTask = 'syncPendingReadings';

// Global function strictly required by Flutter Workmanager.
// Cannot be a class method or closure, MUST be a top-level function.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    
    // Explicitly initialize fundamental dependencies since this executes in an isolated background thread
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(0)) {
       Hive.registerAdapter(PendingReadingAdapter());
    }
    
    final storageService = LocalStorageService();
    await storageService.init();

    final dioClient = DioClient();
    final apiService = ApiService(dioClient);

    switch (task) {
      case backgroundSyncTask:
      case Workmanager.iOSBackgroundTask: // Maps native iOS background fetch
        
        // Target specifically pending items
        final queue = storageService.getPendingReadings();
        
        if (queue.isEmpty) return Future.value(true);

        print('Workmanager: Attempting to sync ${queue.length} items from Hive Cache...');

        bool allSyncsSuccessful = true;

        for (final item in queue) {
          
          item.status = 'uploading';
          await storageService.updatePendingReading(item);

          final success = await apiService.uploadReading(item);

          if (success) {
            // Delete raw image file to save device memory
            final file = File(item.imagePath);
            if (await file.exists()) {
               await file.delete();
            }
            // Remove from Hive tracking completely
            await storageService.deletePendingReading(item.id);
            print('Workmanager: Uploaded & Purged item -> ${item.id}');
          } else {
            // Revert state to pending and inject back-off penalties
            item.retryCount += 1;
            
            if (item.retryCount > 3) {
               item.status = 'failed';
               print('Workmanager: Abandoned item after 3 fails -> ${item.id}');
            } else {
               item.status = 'pending';
            }
            
            await storageService.updatePendingReading(item);
            allSyncsSuccessful = false;
          }
        }
        
        // Returning true tells the OS that the task finished so it can release constraints
        return Future.value(allSyncsSuccessful);
    }
    return Future.value(true);
  });
}
