import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/theme.dart';
import 'core/constants.dart';
import 'ui/screens/auth/splash_screen.dart';
import 'ui/screens/camera/camera_screen.dart';
import 'ui/screens/home/home_screen.dart'; // Import the new Home badge
import 'ui/screens/history/history_screen.dart'; // Import Live History
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/background_service_provider.dart';
import 'workers/sync_worker.dart';
import 'data/local/pending_reading.dart';

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

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // Render Home dynamically mapping to 0
  final List<Widget> _screens = [
    const HomeScreen(),
    const CameraScreen(),
    const HistoryScreen(), // Now links live History Feed
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Water Meter System')),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt),
            label: 'Capture',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
        ],
      ),
    );
  }
}
