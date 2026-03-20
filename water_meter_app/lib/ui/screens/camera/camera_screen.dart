import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';
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
    final cameraController = ref.read(cameraProvider).controller;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      // On web, we might not want to dispose immediately or it might behave differently
      if (!kIsWeb) {
        cameraController.dispose();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_isPermissionGranted) {
        ref.read(cameraProvider.notifier).initialize();
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

  Future<void> _takePicture() async {
    final cameraState = ref.read(cameraProvider);
    final controller = cameraState.controller;

    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture) {
      return;
    }

    try {
      // Instruct hardware to capture
      final XFile image = await controller.takePicture();

      // Bypassing path_provider getTemporaryDirectory() to avoid MissingPluginException
      // during rapid local development/testing cycles where native linking might be stale.
      // We use the image.path provided by the camera plugin directly.
      final String imagePath = image.path;

      if (!mounted) return;

      // Record locally in state
      ref.read(cameraProvider.notifier).setCapturedImage(imagePath);

      // Navigate toward confirmation layer
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ConfirmationScreen(imagePath: imagePath),
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

    if (!cameraState.isInitialized || cameraState.controller == null) {
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
      width: size.width * 0.8,
      height: 100,
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
