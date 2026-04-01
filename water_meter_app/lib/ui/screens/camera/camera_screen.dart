import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../../providers/camera_provider.dart';
import 'confirmation_screen.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with WidgetsBindingObserver {
  bool _isPermissionGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (kIsWeb) {
      setState(() => _isPermissionGranted = true);
      ref.read(cameraProvider.notifier).initialize();
    } else {
      _requestPermissions();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Handle App Lifecycle pausing to tear down camera memory
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cameraNotifier = ref.read(cameraProvider.notifier);
    final cameraState = ref.read(cameraProvider);

    // Check if controller exists and is initialized
    if (cameraState.controller == null ||
        !cameraState.controller!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      // On inactive, dispose the controller properly
      if (!kIsWeb) {
        cameraNotifier.dispose(); // Use proper dispose method
      }
    } else if (state == AppLifecycleState.resumed) {
      // On resume, reinitialize if needed
      if (_isPermissionGranted && cameraState.isDisposed) {
        cameraNotifier.reinitialize();
      }
    }
  }

  Future<void> _requestPermissions() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      setState(() => _isPermissionGranted = true);
      // Boot hardware via riverpod explicitly
      ref.read(cameraProvider.notifier).initialize();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Camera permission is required to capture water meter readings.',
          ),
        ),
      );
    }
  }

  /// Opens the native crop UI and returns the cropped file path,
  /// or null if the user cancelled.
  Future<String?> _cropImage(String rawPath) async {
    final cropped = await ImageCropper().cropImage(
      sourcePath: rawPath,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 90,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Meter Region',
          toolbarColor: Colors.black,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: Colors.greenAccent,
          initAspectRatio: CropAspectRatioPreset.ratio3x2,
          lockAspectRatio: false,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: 'Crop Meter Region',
          cancelButtonTitle: 'Retake',
          doneButtonTitle: 'Done',
        ),
      ],
    );
    return cropped?.path;
  }

  Future<void> _takePicture() async {
    final cameraState = ref.read(cameraProvider);
    final controller = cameraState.controller;

    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture) {
      return;
    }

    try {
      // Capture raw photo from hardware
      final XFile image = await controller.takePicture();
      final String rawPath = image.path;

      if (!mounted) return;

      // Show crop UI — user selects the meter digit region
      final String? croppedPath = kIsWeb ? rawPath : await _cropImage(rawPath);

      // User cancelled cropping — stay on camera screen
      if (croppedPath == null) return;

      if (!mounted) return;

      // Record the final (cropped) path in state
      ref.read(cameraProvider.notifier).setCapturedImage(croppedPath);

      // Navigate toward confirmation layer
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ConfirmationScreen(imagePath: croppedPath),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error capturing image: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPermissionGranted) {
      return const Center(
        child: Text(
          'Please grant camera permissions manually from device settings.',
        ),
      );
    }

    final cameraState = ref.watch(cameraProvider);

    if (cameraState.error != null) {
      return Center(
        child: Text(
          cameraState.error!,
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    // Check if controller is not initialized, disposed, or null
    if (!cameraState.isInitialized ||
        cameraState.controller == null ||
        cameraState.isDisposed ||
        !cameraState.controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Live Hardware Preview bounded to screen
          CameraPreview(cameraState.controller!),

          // 2. Custom ViewFinder Overlay Painting
          CustomPaint(painter: MeterOverlayPainter()),

          // 3. UI Helper Text
          const Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Text(
              'Align the meter digits inside the top box, and the Serial Number in the bottom box.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    blurRadius: 10,
                    color: Colors.black54,
                    offset: Offset(2, 2),
                  ),
                ],
              ),
            ),
          ),

          // 4. Capture Hook
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: FloatingActionButton(
                onPressed: _takePicture,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: const Icon(
                  Icons.camera_alt,
                  size: 30,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------
// Custom Canvas Painting for UI alignment
// ----------------------------------------------------------------------

class MeterOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Paint used to draw the translucent borders
    final paintObj = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    // Background darkening for areas outside the capture boxes
    final backgroundPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    // Provide context rectangles covering entire screen vs transparent crops
    Path backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Calculate dynamic crop dimensions (Assumes phone is held vertically)
    // Box 1: Meter Consumption Digits
    final digitRect = Rect.fromCenter(
      center: Offset(
        size.width / 2,
        size.height * 0.4,
      ), // slightly above center
      width: size.width * 0.70,
      height: 65,
    );

    // Box 2: Serial Number Pattern
    final serialRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.6), // below center
      width: size.width * 0.6,
      height: 60,
    );

    // Punch holes in the dark background
    Path overlayPath = Path()
      ..addRect(digitRect)
      ..addRect(serialRect);

    // Render darkened screen subtracting the target zones using EvenOdd logic
    canvas.drawPath(
      Path.combine(PathOperation.difference, backgroundPath, overlayPath),
      backgroundPaint,
    );

    // Draw solid stroke reticles for user feedback
    canvas.drawRect(digitRect, paintObj);
    canvas.drawRect(serialRect, paintObj);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
