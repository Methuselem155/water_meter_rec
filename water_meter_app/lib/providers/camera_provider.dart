import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CameraState {
  final List<CameraDescription> cameras;
  final CameraController? controller;
  final bool isInitialized;
  final bool isDisposed;
  final String? error;
  final String? capturedImagePath;

  const CameraState({
    this.cameras = const [],
    this.controller,
    this.isInitialized = false,
    this.isDisposed = false,
    this.error,
    this.capturedImagePath,
  });

  CameraState copyWith({
    List<CameraDescription>? cameras,
    CameraController? controller,
    bool? isInitialized,
    bool? isDisposed,
    String? error,
    String? capturedImagePath,
  }) {
    return CameraState(
      cameras: cameras ?? this.cameras,
      controller: controller ?? this.controller,
      isInitialized: isInitialized ?? this.isInitialized,
      isDisposed: isDisposed ?? this.isDisposed,
      error: error, // Can accept null to clear errors cleanly
      capturedImagePath: capturedImagePath ?? this.capturedImagePath,
    );
  }
}

class CameraNotifier extends Notifier<CameraState> {
  @override
  CameraState build() {
    // Ensure cleanup when provider is disposed
    ref.onDispose(() {
      _dispose();
    });
    return const CameraState();
  }

  /// Properly dispose of the camera controller (public method for UI to call)
  Future<void> dispose() async {
    await _dispose();
  }

  /// Internal dispose implementation
  Future<void> _dispose() async {
    if (state.controller != null) {
      try {
        await state.controller!.dispose();
        debugPrint('[Camera Provider] Controller disposed successfully');
      } catch (e) {
        debugPrint('[Camera Provider] Error disposing controller: $e');
      }
    }

    state = state.copyWith(
      controller: null,
      isInitialized: false,
      isDisposed: true,
    );
  }

  /// Reinitialize camera, disposing old controller first if needed
  Future<void> reinitialize() async {
    // Dispose old controller if it exists
    if (state.controller != null) {
      try {
        await state.controller!.dispose();
      } catch (e) {
        debugPrint(
          '[Camera Provider] Error disposing old controller during reinit: $e',
        );
      }
    }

    // Reset state and reinitialize
    state = state.copyWith(
      controller: null,
      isInitialized: false,
      isDisposed: false,
      error: null,
    );

    await initialize();
  }

  Future<void> initialize() async {
    try {
      // Prevent double initialization
      if (state.isInitialized && state.controller != null) {
        debugPrint('[Camera Provider] Camera already initialized, skipping');
        return;
      }

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
        ResolutionPreset.max,
        enableAudio: false, // Not recording video
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();
      try {
        await controller.setFlashMode(FlashMode.off);
      } catch (e) {
        // Ignore flash errors, as some cameras (especially on web) don't support it
        debugPrint('Camera flash not supported or failed to initialize: $e');
      }

      // Auto-focus logic can be fired via controller properties if device supports it
      state = state.copyWith(
        cameras: cameras,
        controller: controller,
        isInitialized: true,
        isDisposed: false,
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
