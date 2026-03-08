import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show
        kIsWeb; // To prevent file loads crashing the flutter web browser render
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:workmanager/workmanager.dart';
import '../../../providers/auth_provider.dart';
import '../../../data/local/pending_reading.dart';
import '../../../data/local/local_storage_service.dart';
import '../../../services/api_service.dart';
import '../../../workers/sync_worker.dart';
import 'package:uuid/uuid.dart'; // To generate sync id

class ConfirmationScreen extends ConsumerWidget {
  final String imagePath;

  const ConfirmationScreen({super.key, required this.imagePath});

  void _uploadReading(BuildContext context, WidgetRef ref) async {
    // Show spinner safely without stateful widgets
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final user = ref.read(authProvider).user;
      final storageService = await ref.read(localStorageProvider.future);
      final apiService = ref.read(apiServiceProvider);

      if (user == null) throw Exception("User session completely lost");

      // Verify immediate internet reachability
      final connectivity = Connectivity();
      final connectivityResult = await connectivity.checkConnectivity();
      final hasInternet = !connectivityResult.contains(ConnectivityResult.none);

      final reading = PendingReading(
        id: const Uuid().v4(),
        imagePath: imagePath,
        meterSerial:
            'N/A', // The backend fetches this inherently based on user ID logic setup right now anyway
        timestamp: DateTime.now(),
        userId: user.id,
      );

      if (hasInternet) {
        // Attempt Direct Execution Over The Web
        final success = await apiService.uploadReading(reading);

        if (success) {
          File(
            imagePath,
          ).deleteSync(); // Dump temp cache immediately if synced successfully

          if (!context.mounted) return;
          Navigator.pop(context); // Pop spinning loader
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reading successfully uploaded and processed!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context); // Pop back to hardware capture
          return;
        }
      }

      // Explicit Failure or Offline Fallback Route
      if (!context.mounted) return;

      // Persist permanently in Hive Queue bounds
      await storageService.savePendingReading(reading);

      // Signal Android OS (WorkManager) that there's a background hook waiting execution when cell reception restores
      Workmanager().registerOneOffTask(
        "bg_sync_${reading.id}",
        backgroundSyncTask,
        constraints: Constraints(networkType: NetworkType.connected),
      );

      if (!context.mounted) return;
      Navigator.pop(context); // Pop loading spinner
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Saved locally. Will sync reading automatically when network returns.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      if (!context.mounted) return;
      Navigator.pop(context); // Pop back to capture frame
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // kill spinner
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Critical Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Confirm Reading'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: kIsWeb
                      ? const Center(
                          child: Text(
                            'Camera capture preview explicitly unavailable for Web Emulators in io packages',
                            style: TextStyle(color: Colors.white),
                          ),
                        )
                      : Image.file(
                          File(imagePath),
                          fit: BoxFit
                              .contain, // Fit fully within the view ensuring no crop
                        ),
                ),
              ),
            ),

            // Action Dashboard
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  // Retake Button
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Retake'),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Specific Upload Hook
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _uploadReading(context, ref),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: const Icon(Icons.upload),
                      label: const Text('Upload'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
