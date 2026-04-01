import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../providers/auth_provider.dart';
import '../../../data/local/local_storage_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../auth/login_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;

    return SafeArea(
      child: Center(
        child: Column(
          children: [
            const SizedBox(height: 48),
            // User Greeting Info
            Text(
              'Welcome, ${user?.fullName ?? 'User'}',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (user != null)
              Text(
                'Account: ${user.accountNumber}',
                style: const TextStyle(color: Colors.grey),
              ),

            const SizedBox(height: 64),

            // Hive Sync Badge Monitor (only on mobile)
            if (!kIsWeb)
              ref.watch(localStorageProvider).when(
                data: (localStorage) => _buildSyncBadge(localStorage),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => const _StatusCard(
                  icon: Icons.error_outline,
                  title: 'Storage Error',
                  subtitle: 'Failed to initialize local storage.',
                  color: Colors.red,
                ),
              )
            else
              const _StatusCard(
                icon: Icons.cloud_done,
                title: 'Web Reader',
                subtitle: 'No offline queues on web platform.',
                color: Colors.blue,
              ),

            const SizedBox(height: 64),

            ElevatedButton.icon(
              onPressed: () async {
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('Log Out'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Reactively listens to Hive DB changes rendering sync status
  Widget _buildSyncBadge(LocalStorageService localStorage) {
    return StreamBuilder<BoxEvent>(
      stream: localStorage.watchPendingReadings(),
      builder: (context, snapshot) {
        // Every time box alters, we recalculate quantities natively
        final count = localStorage.pendingCount;
        final failedCount = localStorage.getFailedReadings().length;

        if (count == 0 && failedCount == 0) {
          return const _StatusCard(
            icon: Icons.cloud_done,
            title: 'All Readings Synced',
            subtitle: 'Your device is fully up to date.',
            color: Colors.green,
          );
        }

        return Column(
          children: [
            if (count > 0)
              _StatusCard(
                icon: Icons.sync,
                title: '$count Pending Uploads',
                subtitle: 'Waiting for network to sync readings.',
                color: Colors.orange,
              ),
            if (failedCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Clear Failed Uploads?'),
                        content: const Text(
                          'These readings failed permanently (often due to cache purges). Would you like to clear them?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.pop(ctx);
                              final failedReadings = localStorage.getFailedReadings();
                              for (var r in failedReadings) {
                                await localStorage.deletePendingReading(r.id);
                              }
                            },
                            child: const Text(
                              'Clear All',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  child: _StatusCard(
                    icon: Icons.error_outline,
                    title: '$failedCount Failed Uploads',
                    subtitle: 'Tap to clear and review.',
                    color: Colors.red,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _StatusCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: color,
                  ),
                ),
                Text(subtitle, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
