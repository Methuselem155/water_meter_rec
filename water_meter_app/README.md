# Water Meter App

A comprehensive Flutter application for tracking water meter readings, featuring local-first offline synchronization, automated backend OCR integration, and historical bill tracking.

## Architecture & State Management
This project leverages **Riverpod** (`flutter_riverpod`) for robust state management. 
- **Authentication**: Managed via `auth_provider.dart`, controlling JWT storage and user sessions.
- **Offline Storage**: Built using `Hive`. Background sync tasks are dispatched natively to Android/iOS using `Workmanager` (`sync_worker.dart`).
- **History & Pagination**: Maintained inside `history_provider.dart`, seamlessly handling infinite scroll lists and pull-to-refresh for both Readings and Bills.

## Prerequisites

- Flutter SDK (>=3.0.0)
- Dart SDK
- Android SDK / Xcode for iOS compilation.

## Getting Started

1. **Install Dependencies**
   Navigate to the project root and run:
   ```bash
   flutter pub get
   ```

2. **Configure Backend URL**
   Open `lib/core/constants.dart` and update the `baseUrl` to point to your live Node.js Express Backend. 
   *(Note: For Android Emulators pointing to localhost, use `http://10.0.2.2:5000/api`)*

3. **Generate Hive Adapters (If modified)**
   This project uses `hive_generator` for offline DB schemas. If you ever update `pending_reading.dart`, regenerate the Hive TypeAdapters:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```
   *(Note on Windows: If you encounter an objective_c native-assets crash during build_runner on Windows, the serialization logic `pending_reading.g.dart` has been manually written to bypass this bug).*

4. **Run the App**
   ```bash
   flutter run
   ```

## Features Complete
- [x] JWT Authentication & Token Persistence
- [x] Custom Camera Viewfinder Overlay
- [x] Device Persistence (Hive Local Cache)
- [x] Background Syncing (Workmanager Offline Queueing)
- [x] Network Reconnection Handlers
- [x] Paginated History Dashboard (Readings & Bills Drilldown)
- [x] Integrated Dio Interceptors

## Workmanager Background Syncing
The application is designed for areas with poor cell service (like utility basements). It dynamically tracks network connectivity on the Confirmation Screen. If offline, the image is stored in Hive. A Workmanager OS thread ensures that the moment connectivity is restored, the `ApiService` will execute a `multipart/form-data` upload and clear the temp caches automatically!
