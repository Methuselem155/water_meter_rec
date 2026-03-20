import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../providers/auth_provider.dart';
import '../../../data/local/pending_reading.dart';
import '../../../data/local/local_storage_service.dart';
import '../../../services/api_service.dart';
import '../../../workers/sync_worker.dart';
import '../../../core/background_service_provider.dart';
import '../../../core/file_service_provider.dart';
import '../../widgets/platform_image.dart';
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
      bool hasInternet;
      if (kIsWeb) {
        // On web, assume connectivity is managed by the browser; treat as online
        // and let the HTTP call itself determine reachability.
        hasInternet = true;
      } else {
        final connectivity = Connectivity();
        final connectivityResult = await connectivity.checkConnectivity();
        hasInternet = connectivityResult != ConnectivityResult.none;
      }

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
        final responseData = await apiService.uploadReading(reading, awaitOcr: true);

        if (responseData != null) {
          fileService.deleteFile(
            imagePath,
          ); // Safely handle file deletion per platform

          if (!context.mounted) return;
          
          Navigator.pop(context); // Pop spinning loader
          
          final data = responseData['data'] as Map<String, dynamic>?;
          final currentReading = data?['reading'] as Map<String, dynamic>?;
          final readingValue = currentReading?['readingValue'];
          final extractedText = readingValue != null ? readingValue.toString() : 'Could not extract digits';

          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
              content: Text(
                'Reading uploaded! Extracted value: $extractedText',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 8),
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

      // Signal background sync (conditional under the hood)
      backgroundService.registerOneOffTask(
        "bg_sync_${reading.id}",
        backgroundSyncTask,
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
                  child: PlatformImage(path: imagePath, fit: BoxFit.contain),
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
