import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../../../providers/history_provider.dart';
import 'reading_detail_screen.dart';
import 'bill_detail_screen.dart';

// ── Shared status badge ───────────────────────────────────────────────────────
class BillStatusBadge extends StatelessWidget {
  final String status;
  const BillStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (status) {
      case 'paid':
        bg = AppTheme.statusPaidBg;
        fg = AppTheme.statusPaid;
        break;
      case 'overdue':
        bg = AppTheme.statusOverdueBg;
        fg = AppTheme.statusOverdue;
        break;
      default:
        bg = AppTheme.statusUnpaidBg;
        fg = AppTheme.statusUnpaid;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

// ── Filter chips ──────────────────────────────────────────────────────────────
const _kFilters = [
  (label: 'All',     value: null,      color: AppTheme.primaryBlue),
  (label: 'Unpaid',  value: 'unpaid',  color: AppTheme.statusUnpaid),
  (label: 'Paid',    value: 'paid',    color: AppTheme.statusPaid),
  (label: 'Overdue', value: 'overdue', color: AppTheme.statusOverdue),
];

class _FilterChips extends StatelessWidget {
  final String? active;
  final ValueChanged<String?> onChanged;

  const _FilterChips({required this.active, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: _kFilters.map((f) {
          final isActive = active == f.value;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(f.label),
              selected: isActive,
              onSelected: (_) => onChanged(f.value),
              backgroundColor: Theme.of(context).colorScheme.surface,
              selectedColor: f.color.withValues(alpha: 0.12),
              checkmarkColor: f.color,
              side: BorderSide(
                color: isActive ? f.color : Colors.grey.shade300,
                width: isActive ? 1.5 : 1,
              ),
              labelStyle: TextStyle(
                color: isActive ? f.color : Colors.grey.shade600,
                fontWeight:
                    isActive ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Main screen ───────────────────────────────────────────────────────────────
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final ScrollController _scrollController = ScrollController();
  final DateFormat _dateFmt = DateFormat('MMM dd, yyyy · HH:mm');
  final DateFormat _shortFmt = DateFormat('MMM dd, yyyy');

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(historyProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(historyProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(state.showingBills ? 'Bills' : 'Readings'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _ViewToggle(
              showingBills: state.showingBills,
              onToggle: () =>
                  ref.read(historyProvider.notifier).toggleView(),
            ),
          ),
        ],
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(HistoryState state) {
    if (state.isLoading &&
        state.readings.isEmpty &&
        state.bills.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return _ErrorView(
        message: state.error!,
        onRetry: () => ref.read(historyProvider.notifier).refreshAll(),
      );
    }

    return state.showingBills
        ? _buildBillsList(state)
        : _buildReadingsList(state);
  }

  // ── Readings list ────────────────────────────────────────────────────────────
  Widget _buildReadingsList(HistoryState state) {
    if (state.readings.isEmpty) {
      return _EmptyState(
        icon: Icons.camera_alt_outlined,
        title: 'No readings yet',
        subtitle: 'Tap Capture below to scan your first meter reading.',
        onRefresh: () => ref.read(historyProvider.notifier).refreshAll(),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(historyProvider.notifier).refreshAll(),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        itemCount: state.readings.length +
            (state.isFetchingMore && state.hasMoreReadings ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == state.readings.length) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final r = state.readings[index];
          final display =
              (r.extracted?.isNotEmpty == true) ? r.extracted : r.readingValue?.toString();

          return _ReadingCard(
            displayValue: display,
            date: _dateFmt.format(r.submissionTime),
            status: r.validationStatus,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      ReadingDetailScreen(readingId: r.id)),
            ),
          );
        },
      ),
    );
  }

  // ── Bills list ───────────────────────────────────────────────────────────────
  Widget _buildBillsList(HistoryState state) {
    final bills = state.billStatusFilter == null
        ? state.bills
        : state.bills
            .where((b) => b.status == state.billStatusFilter)
            .toList();

    return Column(
      children: [
        _FilterChips(
          active: state.billStatusFilter,
          onChanged: (v) =>
              ref.read(historyProvider.notifier).setStatusFilter(v),
        ),
        Expanded(
          child: bills.isEmpty && !state.isLoading
              ? _EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: state.billStatusFilter == null
                      ? 'No bills found'
                      : 'No ${state.billStatusFilter} bills',
                  subtitle: 'Bills will appear here once generated.',
                  onRefresh: () =>
                      ref.read(historyProvider.notifier).refreshAll(),
                )
              : RefreshIndicator(
                  onRefresh: () =>
                      ref.read(historyProvider.notifier).refreshAll(),
                  child: ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding:
                        const EdgeInsets.only(top: 4, bottom: 24),
                    itemCount: bills.length +
                        (state.isFetchingMore && state.hasMoreBills
                            ? 1
                            : 0),
                    itemBuilder: (context, index) {
                      if (index == bills.length) {
                        return const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(
                              child: CircularProgressIndicator()),
                        );
                      }
                      final b = bills[index];
                      final amount =
                          b.totalAmountVatInclusive ?? b.totalAmount;

                      return _BillCard(
                        amount: amount,
                        status: b.status,
                        generatedDate: _shortFmt.format(b.generatedDate),
                        dueDate: b.dueDate != null
                            ? _shortFmt.format(b.dueDate!)
                            : null,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  BillDetailScreen(billId: b.id)),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

// ── View toggle ───────────────────────────────────────────────────────────────

class _ViewToggle extends StatelessWidget {
  final bool showingBills;
  final VoidCallback onToggle;

  const _ViewToggle(
      {required this.showingBills, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              showingBills
                  ? Icons.speed_rounded          // switch TO readings
                  : Icons.receipt_long_rounded,  // switch TO bills
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 5),
            Text(
              showingBills ? 'Readings' : 'Bills', // shows the OTHER view
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reading card ──────────────────────────────────────────────────────────────

class _ReadingCard extends StatelessWidget {
  final String? displayValue;
  final String date;
  final String status;
  final VoidCallback onTap;

  const _ReadingCard({
    required this.displayValue,
    required this.date,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = _statusInfo(status);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
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
                  Text(
                    displayValue != null
                        ? '$displayValue m³'
                        : 'Pending OCR',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(date,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded,
                color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }

  (Color, IconData, String) _statusInfo(String s) {
    switch (s) {
      case 'validated':
        return (AppTheme.statusPaid, Icons.check_circle_rounded,
            'VALID');
      case 'pending':
        return (AppTheme.statusUnpaid, Icons.hourglass_top_rounded,
            'PENDING');
      case 'failed':
      case 'fraud_suspected':
        return (AppTheme.statusOverdue, Icons.cancel_rounded, 'FAILED');
      default:
        return (Colors.grey, Icons.help_outline_rounded, 'UNKNOWN');
    }
  }
}

// ── Bill card ─────────────────────────────────────────────────────────────────

class _BillCard extends StatelessWidget {
  final num amount;
  final String status;
  final String generatedDate;
  final String? dueDate;
  final VoidCallback onTap;

  const _BillCard({
    required this.amount,
    required this.status,
    required this.generatedDate,
    required this.dueDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (color, icon) = _statusIconColor(status);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
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
                  Text(
                    'RWF ${amount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Generated $generatedDate',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (dueDate != null && status != 'paid')
                    Text(
                      'Due $dueDate',
                      style: TextStyle(
                        fontSize: 12,
                        color: status == 'overdue'
                            ? AppTheme.statusOverdue
                            : Colors.grey.shade600,
                        fontWeight: status == 'overdue'
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            BillStatusBadge(status: status),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded,
                color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }

  (Color, IconData) _statusIconColor(String s) {
    switch (s) {
      case 'paid':
        return (AppTheme.statusPaid, Icons.check_circle_outline_rounded);
      case 'overdue':
        return (AppTheme.statusOverdue, Icons.warning_amber_rounded);
      default:
        return (AppTheme.statusUnpaid, Icons.receipt_long_rounded);
    }
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Future<void> Function() onRefresh;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.55,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon,
                        size: 38,
                        color: AppTheme.primaryBlue
                            .withValues(alpha: 0.5)),
                  ),
                  const SizedBox(height: 20),
                  Text(title,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded,
                size: 56,
                color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('Something went wrong',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
