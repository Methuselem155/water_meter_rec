import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CameraState {
  final List<CameraDescription> cameras;
  final CameraController? controller;
  final bool isInitialized;
  final String? error;
  final String? capturedImagePath;

  const CameraState({
    this.cameras = const [],
    this.controller,
    this.isInitialized = false,
    this.error,
    this.capturedImagePath,
  });

  CameraState copyWith({
    List<CameraDescription>? cameras,
    CameraController? controller,
    bool? isInitialized,
    String? error,
    String? capturedImagePath,
  }) {
    return CameraState(
      cameras: cameras ?? this.cameras,
      controller: controller ?? this.controller,
      isInitialized: isInitialized ?? this.isInitialized,
      error: error, // Can accept null to clear errors cleanly
      capturedImagePath: capturedImagePath ?? this.capturedImagePath,
    );
  }
}

class CameraNotifier extends Notifier<CameraState> {
  @override
  CameraState build() {
    return const CameraState();
  }

  Future<void> initialize() async {
    try {
      // Look up available physical cameras
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        state = state.copyWith(error: 'No cameras available on this device.');
        return;
      }

      // Try selecting the back camera first
      CameraDescription? selectedCamera;
      for (final cam in cameras) {
        if (cam.lensDirection == CameraLensDirection.back) {
          selectedCamera = cam;
          break;
        }
      }
      // Fallback to whatever is index 0
      selectedCamera ??= cameras.first;

      // Initialize the controller focusing strictly on high res photography
      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: false, // Not recording video
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();

      // Auto-focus logic can be fired via controller properties if device supports it
      state = state.copyWith(
        cameras: cameras,
        controller: controller,
        isInitialized: true,
      );
    } on CameraException catch (e) {
      state = state.copyWith(error: 'Camera Exception: ${e.description}');
    } catch (e) {
      state = state.copyWith(
        error: 'Error initializing camera: ${e.toString()}',
      );
    }
  }

  void setCapturedImage(String path) {
    state = state.copyWith(capturedImagePath: path);
  }

  void clearCapturedImage() {
    state = state.copyWith(capturedImagePath: null);
  }
}

final cameraProvider = NotifierProvider<CameraNotifier, CameraState>(() {
  return CameraNotifier();
});
