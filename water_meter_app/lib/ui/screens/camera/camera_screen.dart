import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../providers/camera_provider.dart';
import 'confirmation_screen.dart';

// The green frame covers the middle 50% height and 84% width of the preview.
// These ratios must match _GuideFramePainter exactly.
const double _frameMarginRatio = 0.08; // left/right margin = 8% of width
const double _frameTopRatio    = 0.25; // top of frame   = 25% of height
const double _frameBottomRatio = 0.75; // bottom of frame = 75% of height

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with WidgetsBindingObserver {
  bool _isPermissionGranted = false;
  bool _isCropping = false;

  // Key on the Stack so we can read the preview render size
  final GlobalKey _previewKey = GlobalKey();

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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cameraNotifier = ref.read(cameraProvider.notifier);
    final cameraState = ref.read(cameraProvider);
    if (cameraState.controller == null ||
        !cameraState.controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      if (!kIsWeb) cameraNotifier.dispose();
    } else if (state == AppLifecycleState.resumed) {
      if (_isPermissionGranted && cameraState.isDisposed) {
        cameraNotifier.reinitialize();
      }
    }
  }

  Future<void> _requestPermissions() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      setState(() => _isPermissionGranted = true);
      ref.read(cameraProvider.notifier).initialize();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera permission is required to capture water meter readings.'),
        ),
      );
    }
  }

  /// Crop the saved image to the green frame area.
  /// The frame ratios are applied to the actual image dimensions.
  Future<String> _cropToFrame(String imagePath, CameraController controller) async {
    final bytes = await File(imagePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return imagePath;

    // Camera images may be rotated — img.decodeImage handles EXIF automatically
    final iw = decoded.width;
    final ih = decoded.height;

    // The camera preview on Android is usually portrait with sensor rotated.
    // We work in the image's own coordinate space after decode (EXIF applied).
    // Map the frame ratios directly onto image pixels.
    final x = (iw * _frameMarginRatio).round();
    final y = (ih * _frameTopRatio).round();
    final w = (iw * (1 - 2 * _frameMarginRatio)).round();
    final h = (ih * (_frameBottomRatio - _frameTopRatio)).round();

    final cropped = img.copyCrop(decoded, x: x, y: y, width: w, height: h);

    final dir = await getTemporaryDirectory();
    final outPath = '${dir.path}/meter_crop_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(outPath).writeAsBytes(img.encodeJpg(cropped, quality: 90));
    return outPath;
  }

  Future<void> _takePicture() async {
    final cameraState = ref.read(cameraProvider);
    final controller = cameraState.controller;

    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture ||
        _isCropping) return;

    try {
      final XFile image = await controller.takePicture();
      if (!mounted) return;

      setState(() => _isCropping = true);

      final croppedPath = await _cropToFrame(image.path, controller);

      if (!mounted) return;
      setState(() => _isCropping = false);

      ref.read(cameraProvider.notifier).setCapturedImage(croppedPath);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ConfirmationScreen(imagePath: croppedPath),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isCropping = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error capturing image: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPermissionGranted) {
      return const Center(
        child: Text('Please grant camera permissions manually from device settings.'),
      );
    }

    final cameraState = ref.watch(cameraProvider);

    if (cameraState.error != null) {
      return Center(
        child: Text(cameraState.error!, style: const TextStyle(color: Colors.red)),
      );
    }

    if (!cameraState.isInitialized ||
        cameraState.controller == null ||
        cameraState.isDisposed ||
        !cameraState.controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: Stack(
        key: _previewKey,
        fit: StackFit.expand,
        children: [
          CameraPreview(cameraState.controller!),
          CustomPaint(painter: _GuideFramePainter()),
          const Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Text(
              'Fit the meter inside the frame — the frame area will be sent for reading.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(blurRadius: 10, color: Colors.black54, offset: Offset(2, 2)),
                ],
              ),
            ),
          ),
          if (_isCropping)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.greenAccent),
                    SizedBox(height: 12),
                    Text('Processing...', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
          if (!_isCropping)
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Center(
                child: FloatingActionButton(
                  onPressed: _takePicture,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: const Icon(Icons.camera_alt, size: 30, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Guide frame — ratios must match _frameMarginRatio / _frameTopRatio / _frameBottomRatio
class _GuideFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Dim everything outside the frame
    final dimPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;

    final frame = Rect.fromLTRB(
      size.width  * _frameMarginRatio,
      size.height * _frameTopRatio,
      size.width  * (1 - _frameMarginRatio),
      size.height * _frameBottomRatio,
    );

    final full = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final hole = Path()..addRect(frame);
    canvas.drawPath(Path.combine(PathOperation.difference, full, hole), dimPaint);

    // Green border
    canvas.drawRect(
      frame,
      Paint()
        ..color = Colors.greenAccent.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(_GuideFramePainter old) => false;
}
