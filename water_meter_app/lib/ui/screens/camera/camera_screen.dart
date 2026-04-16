import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  final GlobalKey<_CropOverlayWidgetState> _overlayKey =
      GlobalKey<_CropOverlayWidgetState>();

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
        !cameraState.controller!.value.isInitialized) {
      return;
    }

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
          content: Text(
            'Camera permission is required to capture water meter readings.',
          ),
        ),
      );
    }
  }

  /// Capture the full image and send it directly — no cropping.
  /// Claude Vision processes the complete photo.
  Future<void> _takePicture() async {
    final cameraState = ref.read(cameraProvider);
    final controller = cameraState.controller;

    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture) {
      return;
    }

    try {
      final XFile image = await controller.takePicture();
      if (!mounted) return;

      ref.read(cameraProvider.notifier).setCapturedImage(image.path);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ConfirmationScreen(imagePath: image.path),
        ),
      );
    } catch (e) {
      if (mounted) {
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
          CameraPreview(cameraState.controller!),
          CropOverlayWidget(key: _overlayKey),
          const Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Text(
              'Align the meter inside the frame. The full photo will be sent for reading.',
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
// Framing Overlay Widget (visual guide only — image is NOT cropped)
// ----------------------------------------------------------------------

class CropOverlayWidget extends StatefulWidget {
  const CropOverlayWidget({super.key});

  @override
  State<CropOverlayWidget> createState() => _CropOverlayWidgetState();
}

class _CropOverlayWidgetState extends State<CropOverlayWidget> {
  static const double _handleSize = 18.0;
  static const double _minBox = 40.0;

  Rect? _digitRect;
  Rect? _serialRect;

  Size _layoutSize = Size.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPrefs());
  }

  Size get layoutSize => _layoutSize;

  static Rect _defaultDigit(Size s) => Rect.fromCenter(
        center: Offset(s.width / 2, s.height * 0.4),
        width: s.width * 0.70,
        height: 65,
      );

  static Rect _defaultSerial(Size s) => Rect.fromCenter(
        center: Offset(s.width / 2, s.height * 0.6),
        width: s.width * 0.60,
        height: 60,
      );

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final dl = prefs.getDouble('crop_digit_left');
    final dt = prefs.getDouble('crop_digit_top');
    final dw = prefs.getDouble('crop_digit_width');
    final dh = prefs.getDouble('crop_digit_height');
    final sl = prefs.getDouble('crop_serial_left');
    final st = prefs.getDouble('crop_serial_top');
    final sw = prefs.getDouble('crop_serial_width');
    final sh = prefs.getDouble('crop_serial_height');

    if (!mounted) return;
    setState(() {
      if (dl != null && dt != null && dw != null && dh != null) {
        _digitRect = Rect.fromLTWH(dl, dt, dw, dh);
      }
      if (sl != null && st != null && sw != null && sh != null) {
        _serialRect = Rect.fromLTWH(sl, st, sw, sh);
      }
    });
  }

  Future<void> _saveCurrentState() async {
    final prefs = await SharedPreferences.getInstance();
    if (_digitRect != null) {
      await prefs.setDouble('crop_digit_left', _digitRect!.left);
      await prefs.setDouble('crop_digit_top', _digitRect!.top);
      await prefs.setDouble('crop_digit_width', _digitRect!.width);
      await prefs.setDouble('crop_digit_height', _digitRect!.height);
    }
    if (_serialRect != null) {
      await prefs.setDouble('crop_serial_left', _serialRect!.left);
      await prefs.setDouble('crop_serial_top', _serialRect!.top);
      await prefs.setDouble('crop_serial_width', _serialRect!.width);
      await prefs.setDouble('crop_serial_height', _serialRect!.height);
    }
  }

  Rect _clamp(Rect r, Size s) {
    final w = r.width.clamp(_minBox, s.width);
    final h = r.height.clamp(_minBox, s.height);
    final l = r.left.clamp(0.0, s.width - w);
    final t = r.top.clamp(0.0, s.height - h);
    return Rect.fromLTWH(l, t, w, h);
  }

  Widget _buildBox({
    required Rect rect,
    required String label,
    required Size size,
    required void Function(Rect) onChanged,
  }) {
    return Stack(
      children: [
        Positioned(
          left: rect.left,
          top: rect.top,
          width: rect.width,
          height: rect.height,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onPanUpdate: (d) => onChanged(
              _clamp(
                Rect.fromLTWH(
                  rect.left + d.delta.dx,
                  rect.top + d.delta.dy,
                  rect.width,
                  rect.height,
                ),
                size,
              ),
            ),
            onPanEnd: (_) => _saveCurrentState(),
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                ),
              ),
            ),
          ),
        ),
        for (final corner in _Corner.values)
          _buildHandle(rect, corner, size, onChanged),
      ],
    );
  }

  Widget _buildHandle(
    Rect rect,
    _Corner corner,
    Size size,
    void Function(Rect) onChanged,
  ) {
    final isLeft =
        corner == _Corner.topLeft || corner == _Corner.bottomLeft;
    final isTop =
        corner == _Corner.topLeft || corner == _Corner.topRight;
    final hx = isLeft
        ? rect.left - _handleSize / 2
        : rect.right - _handleSize / 2;
    final hy = isTop
        ? rect.top - _handleSize / 2
        : rect.bottom - _handleSize / 2;

    return Positioned(
      left: hx,
      top: hy,
      width: _handleSize,
      height: _handleSize,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (d) {
          double l = rect.left,
              t = rect.top,
              r = rect.right,
              b = rect.bottom;
          if (isLeft) {
            l = (l + d.delta.dx).clamp(0.0, r - _minBox);
          } else {
            r = (r + d.delta.dx).clamp(l + _minBox, size.width);
          }
          if (isTop) {
            t = (t + d.delta.dy).clamp(0.0, b - _minBox);
          } else {
            b = (b + d.delta.dy).clamp(t + _minBox, size.height);
          }
          onChanged(Rect.fromLTRB(l, t, r, b));
        },
        onPanEnd: (_) => _saveCurrentState(),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.greenAccent, width: 2),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final size = constraints.biggest;

      if (_layoutSize != size) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _layoutSize = size);
        });
      }

      final digitRect = _clamp(_digitRect ?? _defaultDigit(size), size);
      final serialRect = _clamp(_serialRect ?? _defaultSerial(size), size);

      return Stack(
        children: [
          CustomPaint(
            size: size,
            painter: _DimmedOverlayPainter(
              digitRect: digitRect,
              serialRect: serialRect,
            ),
          ),
          _buildBox(
            rect: digitRect,
            label: 'Meter Digits · Drag to reposition · Pull corners to resize',
            size: size,
            onChanged: (r) => setState(() => _digitRect = r),
          ),
          _buildBox(
            rect: serialRect,
            label:
                'Serial Number · Drag to reposition · Pull corners to resize',
            size: size,
            onChanged: (r) => setState(() => _serialRect = r),
          ),
        ],
      );
    });
  }
}

enum _Corner { topLeft, topRight, bottomLeft, bottomRight }

class _DimmedOverlayPainter extends CustomPainter {
  final Rect digitRect;
  final Rect serialRect;

  const _DimmedOverlayPainter(
      {required this.digitRect, required this.serialRect});

  @override
  void paint(Canvas canvas, Size size) {
    final dimPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final full = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final holes = Path()
      ..addRect(digitRect)
      ..addRect(serialRect);

    canvas.drawPath(
      Path.combine(PathOperation.difference, full, holes),
      dimPaint,
    );
    canvas.drawRect(digitRect, borderPaint);
    canvas.drawRect(serialRect, borderPaint);
  }

  @override
  bool shouldRepaint(_DimmedOverlayPainter old) =>
      old.digitRect != digitRect || old.serialRect != serialRect;
}
