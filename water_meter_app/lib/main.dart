import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/theme.dart';
import 'core/constants.dart';
import 'ui/screens/auth/splash_screen.dart';
import 'ui/screens/camera/camera_screen.dart';
import 'ui/screens/home/home_screen.dart';
import 'ui/screens/history/history_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/background_service_provider.dart';
import 'workers/sync_worker.dart';
import 'data/local/pending_reading.dart';
import 'providers/history_provider.dart';

void main() async {
  // Ensure flutter gets initialized before running any async platform code.
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive storage for offline capabilities (works on web & mobile)
  await Hive.initFlutter();

  // Register adapter regardless of platform
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(PendingReadingAdapter());
  }

  // Open the primary box
  await Hive.openBox<PendingReading>(Constants.pendingReadingsBox);

  // Initialize Background Service (conditional under the hood)
  backgroundService.initialize(callbackDispatcher);

  runApp(const ProviderScope(child: WaterMeterApp()));
}

class WaterMeterApp extends StatelessWidget {
  const WaterMeterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Water Meter App',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system, // Respects device settings
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  static const List<Widget> _screens = [
    HomeScreen(),
    CameraScreen(),
    HistoryScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(activeTabProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Water Meter System')),
      body: IndexedStack(
        index: currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => ref.read(activeTabProvider.notifier).state = index,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: 'Capture'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
        ],
      ),
    );
  }
}
