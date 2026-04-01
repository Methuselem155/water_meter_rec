import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'package:image_cropper/image_cropper.dart';
import '../../../providers/history_provider.dart';
import '../../../services/api_service.dart';

class ConfirmationScreen extends ConsumerStatefulWidget {
  final String imagePath;

  const ConfirmationScreen({super.key, required this.imagePath});

  @override
  ConsumerState<ConfirmationScreen> createState() => _ConfirmationScreenState();
}

class _ConfirmationScreenState extends ConsumerState<ConfirmationScreen> {
  String? _displayCropPath;
  String? _serialCropPath;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    // Auto-start cropping flow on screen open
    WidgetsBinding.instance.addPostFrameCallback((_) => _startCropFlow());
  }

  /// Step 1: crop the digit display region
  /// Step 2: crop the serial number region
  Future<void> _startCropFlow() async {
    if (kIsWeb) {
      setState(() {
        _displayCropPath = widget.imagePath;
        _serialCropPath = widget.imagePath;
      });
      return;
    }

    // Crop 1 — digit display
    final displayCrop = await _crop(
      widget.imagePath,
      title: 'Crop: Digit Display',
      hint: 'Select ONLY the meter digit display area',
    );
    if (!mounted) return;
    if (displayCrop == null) {
      Navigator.pop(context); // user cancelled
      return;
    }

    // Crop 2 — serial number
    final serialCrop = await _crop(
      widget.imagePath,
      title: 'Crop: Serial Number',
      hint: 'Select ONLY the serial number area',
    );
    if (!mounted) return;

    setState(() {
      _displayCropPath = displayCrop;
      _serialCropPath = serialCrop; // null is fine — serial is optional
    });
  }

  Future<String?> _crop(String sourcePath, {required String title, required String hint}) async {
    final cropped = await ImageCropper().cropImage(
      sourcePath: sourcePath,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 95,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: title,
          toolbarColor: Colors.black,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: Colors.greenAccent,
          lockAspectRatio: false,
          hideBottomControls: false,
          statusBarColor: Colors.black,
        ),
        IOSUiSettings(
          title: title,
          cancelButtonTitle: 'Cancel',
          doneButtonTitle: 'Done',
        ),
      ],
    );
    return cropped?.path;
  }

  Future<void> _upload() async {
    if (_displayCropPath == null) return;
    setState(() => _isUploading = true);

    try {
      final apiService = ref.read(apiServiceProvider);
      final result = await apiService.scanReading(
        displayCropPath: _displayCropPath!,
        serialCropPath: _serialCropPath,
      );

      if (!mounted) return;

      if (result.reading != null) {
        ref.read(historyProvider.notifier).prependReading(result.reading!);
      } else {
        ref.read(historyProvider.notifier).refreshAll();
      }

      ref.read(activeTabProvider.notifier).state = 2;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reading uploaded successfully.'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _displayCropPath != null;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Confirm Crops'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: !ready
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Colors.greenAccent),
                          SizedBox(height: 16),
                          Text('Crop the meter regions...', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _cropPreview('Digit Display', _displayCropPath!),
                          const SizedBox(height: 16),
                          if (_serialCropPath != null)
                            _cropPreview('Serial Number', _serialCropPath!),
                          if (_serialCropPath == null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange),
                              ),
                              child: const Text(
                                'Serial number crop skipped — validation may be limited.',
                                style: TextStyle(color: Colors.orange),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isUploading ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Retake'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: (!ready || _isUploading) ? null : _upload,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _isUploading
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.cloud_upload_outlined),
                      label: Text(_isUploading ? 'Uploading...' : 'Submit'),
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

  Widget _cropPreview(String label, String filePath) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(filePath),
            width: double.infinity,
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }
}
