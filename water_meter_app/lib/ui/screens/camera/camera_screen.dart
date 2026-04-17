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

// Frame ratios — must match _GuideFramePainter exactly.
const double _frameMarginRatio = 0.08;
const double _frameTopRatio    = 0.25;
const double _frameBottomRatio = 0.75;
const double _cornerLength     = 28.0; // px length of each corner bracket arm

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with WidgetsBindingObserver {
  bool _isPermissionGranted = false;
  bool _isCropping = false;
  FlashMode _flashMode = FlashMode.off;

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
          content: Text('Camera permission is required to capture meter readings.'),
        ),
      );
    }
  }

  void _toggleFlash() {
    final controller = ref.read(cameraProvider).controller;
    if (controller == null) return;
    final next = _flashMode == FlashMode.off ? FlashMode.torch : FlashMode.off;
    controller.setFlashMode(next);
    setState(() => _flashMode = next);
  }

  Future<String> _cropToFrame(String imagePath, CameraController controller) async {
    final bytes = await File(imagePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return imagePath;

    final iw = decoded.width;
    final ih = decoded.height;

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
      return _PermissionDeniedView(onRetry: _requestPermissions);
    }

    final cameraState = ref.watch(cameraProvider);

    if (cameraState.error != null) {
      return _ErrorView(message: cameraState.error!);
    }

    if (!cameraState.isInitialized ||
        cameraState.controller == null ||
        cameraState.isDisposed ||
        !cameraState.controller!.value.isInitialized) {
      return const _LoadingView();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        key: _previewKey,
        fit: StackFit.expand,
        children: [
          // Live preview
          CameraPreview(cameraState.controller!),

          // Dimmed overlay + corner brackets
          CustomPaint(painter: _GuideFramePainter()),

          // Top controls bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _TopBar(
              flashMode: _flashMode,
              onFlashToggle: _toggleFlash,
            ),
          ),

          // Instruction + capture button — anchored together from the bottom
          if (!_isCropping)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 24,
              left: 24,
              right: 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _InstructionLabel(),
                  const SizedBox(height: 20),
                  Center(child: _CaptureButton(onTap: _takePicture)),
                ],
              ),
            ),

          // Processing overlay
          if (_isCropping)
            const _ProcessingOverlay(),
        ],
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final FlashMode flashMode;
  final VoidCallback onFlashToggle;

  const _TopBar({required this.flashMode, required this.onFlashToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 8,
        right: 8,
        bottom: 16,
      ),
      child: Row(
        children: [
          // Back button
          _IconCircleButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.maybePop(context),
          ),
          const Spacer(),
          // Screen title
          const Text(
            'Scan Meter',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const Spacer(),
          // Flash toggle
          _IconCircleButton(
            icon: flashMode == FlashMode.torch
                ? Icons.flash_on_rounded
                : Icons.flash_off_rounded,
            onTap: onFlashToggle,
            active: flashMode == FlashMode.torch,
          ),
        ],
      ),
    );
  }
}

class _IconCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  const _IconCircleButton({
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: active
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.85)
              : Colors.black38,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _InstructionLabel extends StatelessWidget {
  const _InstructionLabel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.center_focus_strong_rounded,
            color: Theme.of(context).colorScheme.primary,
            size: 18,
          ),
          const SizedBox(width: 8),
          const Flexible(
            child: Text(
              'Align the meter display inside the frame',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CaptureButton extends StatefulWidget {
  final VoidCallback? onTap;

  const _CaptureButton({required this.onTap});

  @override
  State<_CaptureButton> createState() => _CaptureButtonState();
}

class _CaptureButtonState extends State<_CaptureButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.9,
      upperBound: 1.0,
      value: 1.0,
    );
    _scale = _controller;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(_) => _controller.reverse();
  void _onTapUp(_) {
    _controller.forward();
    widget.onTap?.call();
  }
  void _onTapCancel() => _controller.forward();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Container(
              decoration: BoxDecoration(
                color: primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProcessingOverlay extends StatelessWidget {
  const _ProcessingOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
              strokeWidth: 3,
            ),
            const SizedBox(height: 16),
            const Text(
              'Processing image…',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            const Text(
              'Starting camera…',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;

  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  color: Theme.of(context).colorScheme.error, size: 48),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionDeniedView extends StatelessWidget {
  final VoidCallback onRetry;

  const _PermissionDeniedView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.camera_alt_outlined,
                  color: Theme.of(context).colorScheme.primary, size: 56),
              const SizedBox(height: 20),
              const Text(
                'Camera Access Required',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Please grant camera permission to scan water meter readings.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 14),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: onRetry,
                child: const Text('Grant Permission'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Guide Frame Painter ───────────────────────────────────────────────────────

class _GuideFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final frame = Rect.fromLTRB(
      size.width  * _frameMarginRatio,
      size.height * _frameTopRatio,
      size.width  * (1 - _frameMarginRatio),
      size.height * _frameBottomRatio,
    );

    // Dim the outside of the frame
    final dimPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;

    final full = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final hole = Path()..addRect(frame);
    canvas.drawPath(Path.combine(PathOperation.difference, full, hole), dimPaint);

    // Corner bracket paint
    final bracketPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    _drawCornerBrackets(canvas, frame, bracketPaint);
  }

  void _drawCornerBrackets(Canvas canvas, Rect frame, Paint paint) {
    final l = frame.left;
    final t = frame.top;
    final r = frame.right;
    final b = frame.bottom;
    const c = _cornerLength;

    // Top-left
    canvas.drawLine(Offset(l, t + c), Offset(l, t), paint);
    canvas.drawLine(Offset(l, t), Offset(l + c, t), paint);

    // Top-right
    canvas.drawLine(Offset(r - c, t), Offset(r, t), paint);
    canvas.drawLine(Offset(r, t), Offset(r, t + c), paint);

    // Bottom-left
    canvas.drawLine(Offset(l, b - c), Offset(l, b), paint);
    canvas.drawLine(Offset(l, b), Offset(l + c, b), paint);

    // Bottom-right
    canvas.drawLine(Offset(r - c, b), Offset(r, b), paint);
    canvas.drawLine(Offset(r, b), Offset(r, b - c), paint);
  }

  @override
  bool shouldRepaint(_GuideFramePainter old) => false;
}
