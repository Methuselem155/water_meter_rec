import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../core/theme.dart';
import '../../../providers/auth_provider.dart';
import '../../../data/local/local_storage_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../auth/login_screen.dart';
import '../../../repositories/bill_repository.dart';
import '../../../providers/history_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(billSummaryProvider),
        child: CustomScrollView(
          slivers: [
            // ── Gradient header ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: _GreetingHeader(
                name: user?.fullName ?? 'User',
                accountNumber: user?.accountNumber,
                onLogout: () => _confirmLogout(context, ref),
              ),
            ),

            // ── Quick action ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: _QuickScanCard(
                  onTap: () =>
                      ref.read(activeTabProvider.notifier).state = 1,
                ),
              ),
            ),

            // ── Bill summary title ───────────────────────────────────────
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 28, 20, 12),
                child: _SectionTitle(title: 'Bill Overview'),
              ),
            ),

            // ── Bill cards ───────────────────────────────────────────────
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: _BillSummaryCards(),
              ),
            ),

            // ── Sync status title ────────────────────────────────────────
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 28, 20, 12),
                child: _SectionTitle(title: 'Sync Status'),
              ),
            ),

            // ── Sync card ────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                child: kIsWeb
                    ? const _StatusCard(
                        icon: Icons.cloud_done_rounded,
                        title: 'Web Platform',
                        subtitle: 'No offline queue on web.',
                        color: AppTheme.primaryBlue,
                      )
                    : ref.watch(localStorageProvider).when(
                          data: (ls) => _SyncBadge(localStorage: ls),
                          loading: () => const Center(
                              child: CircularProgressIndicator()),
                          error: (err, st) => const _StatusCard(
                            icon: Icons.error_outline_rounded,
                            title: 'Storage Error',
                            subtitle:
                                'Failed to initialize local storage.',
                            color: AppTheme.errorRed,
                          ),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log Out'),
        content:
            const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                      builder: (_) => const LoginScreen()),
                );
              }
            },
            child: Text('Log Out',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }
}

// ── Greeting header ───────────────────────────────────────────────────────────

class _GreetingHeader extends StatelessWidget {
  final String name;
  final String? accountNumber;
  final VoidCallback onLogout;

  const _GreetingHeader({
    required this.name,
    required this.accountNumber,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primaryBlue, Color(0xFF0D47A1)],
        ),
        borderRadius:
            BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 28),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_rounded,
                    color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _greeting(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (accountNumber != null)
                      Text(
                        'Account: $accountNumber',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onLogout,
                icon: const Icon(Icons.logout_rounded,
                    color: Colors.white60, size: 22),
                tooltip: 'Log Out',
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning,';
    if (h < 17) return 'Good afternoon,';
    return 'Good evening,';
  }
}

// ── Quick scan card ───────────────────────────────────────────────────────────

class _QuickScanCard extends StatelessWidget {
  final VoidCallback onTap;

  const _QuickScanCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.accentCyan,
              AppTheme.accentCyan.withValues(alpha: 0.75),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accentCyan.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.camera_alt_rounded,
                  color: Colors.white, size: 26),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Scan Meter',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Capture your meter reading now',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white60, size: 16),
          ],
        ),
      ),
    );
  }
}

// ── Section title ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

// ── Bill summary cards ────────────────────────────────────────────────────────

class _BillSummaryCards extends ConsumerWidget {
  const _BillSummaryCards();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(billSummaryProvider);

    return summaryAsync.when(
      loading: () => Row(
        children: List.generate(
          3,
          (_) => Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ),
      error: (err, st) => const SizedBox.shrink(),
      data: (summary) => Row(
        children: [
          _SummaryCard(
            label: 'Unpaid',
            count: summary.totalUnpaid,
            amount: summary.totalAmountUnpaid,
            icon: Icons.receipt_long_rounded,
            color: AppTheme.statusUnpaid,
            bg: AppTheme.statusUnpaidBg,
          ),
          const SizedBox(width: 10),
          _SummaryCard(
            label: 'Overdue',
            count: summary.totalOverdue,
            amount: summary.totalAmountOverdue,
            icon: Icons.warning_amber_rounded,
            color: AppTheme.statusOverdue,
            bg: AppTheme.statusOverdueBg,
          ),
          const SizedBox(width: 10),
          _SummaryCard(
            label: 'Paid',
            count: summary.totalPaid,
            amount: null,
            icon: Icons.check_circle_outline_rounded,
            color: AppTheme.statusPaid,
            bg: AppTheme.statusPaidBg,
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final int count;
  final num? amount;
  final IconData icon;
  final Color color;
  final Color bg;

  const _SummaryCard({
    required this.label,
    required this.count,
    required this.amount,
    required this.icon,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 10),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: color,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            if (amount != null) ...[
              const SizedBox(height: 4),
              Text(
                'RWF ${_fmt(amount!)}',
                style: TextStyle(
                    fontSize: 10, color: color.withValues(alpha: 0.7)),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _fmt(num n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : n.toStringAsFixed(0);
}

// ── Sync badge ────────────────────────────────────────────────────────────────

class _SyncBadge extends StatelessWidget {
  final LocalStorageService localStorage;

  const _SyncBadge({required this.localStorage});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BoxEvent>(
      stream: localStorage.watchPendingReadings(),
      builder: (context, _) {
        final count = localStorage.pendingCount;
        final failed = localStorage.getFailedReadings().length;

        if (count == 0 && failed == 0) {
          return const _StatusCard(
            icon: Icons.cloud_done_rounded,
            title: 'All Synced',
            subtitle: 'Your readings are up to date.',
            color: AppTheme.statusPaid,
          );
        }

        return Column(
          children: [
            if (count > 0)
              _StatusCard(
                icon: Icons.sync_rounded,
                title: '$count Pending Upload${count > 1 ? 's' : ''}',
                subtitle: 'Waiting for network.',
                color: AppTheme.statusUnpaid,
              ),
            if (failed > 0)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: GestureDetector(
                  onTap: () => _clearFailed(context),
                  child: _StatusCard(
                    icon: Icons.error_outline_rounded,
                    title: '$failed Failed Upload${failed > 1 ? 's' : ''}',
                    subtitle: 'Tap to clear.',
                    color: AppTheme.errorRed,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _clearFailed(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear Failed Uploads?'),
        content: const Text(
            'These readings failed permanently. Would you like to clear them?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final failed = localStorage.getFailedReadings();
              for (final r in failed) {
                await localStorage.deletePendingReading(r.id);
              }
            },
            child: Text('Clear All',
                style: TextStyle(
                    color: Theme.of(ctx).colorScheme.error)),
          ),
        ],
      ),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: color)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
