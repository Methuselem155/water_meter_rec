import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../providers/history_provider.dart';
import 'reading_detail_screen.dart';
import 'bill_detail_screen.dart';

// ── Status badge ─────────────────────────────────────────────────────────────
class BillStatusBadge extends StatelessWidget {
  final String status;
  const BillStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (status) {
      case 'paid':
        bg = Colors.green.shade100;
        fg = Colors.green.shade800;
        break;
      case 'overdue':
        bg = Colors.red.shade100;
        fg = Colors.red.shade800;
        break;
      default: // unpaid
        bg = Colors.amber.shade100;
        fg = Colors.amber.shade900;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── Filter tabs ───────────────────────────────────────────────────────────────
const _kFilters = [
  (label: 'All', value: null, color: Colors.blue),
  (label: 'Unpaid', value: 'unpaid', color: Colors.amber),
  (label: 'Paid', value: 'paid', color: Colors.green),
  (label: 'Overdue', value: 'overdue', color: Colors.red),
];

class _FilterTabs extends StatelessWidget {
  final String? active;
  final ValueChanged<String?> onChanged;

  const _FilterTabs({required this.active, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: _kFilters.map((f) {
          final isActive = active == f.value;
          final color = f.color as Color;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(f.label),
              selected: isActive,
              selectedColor: color.withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: isActive ? color : Colors.grey.shade600,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
              side: BorderSide(
                color: isActive ? color : Colors.grey.shade300,
              ),
              onSelected: (_) => onChanged(f.value),
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
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy - HH:mm');

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
    final historyState = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account History'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Row(
              children: [
                const Text('Readings', style: TextStyle(fontSize: 12)),
                Switch(
                  value: historyState.showingBills,
                  activeThumbColor: Theme.of(context).colorScheme.secondary,
                  onChanged: (_) =>
                      ref.read(historyProvider.notifier).toggleView(),
                ),
                const Text('Bills', style: TextStyle(fontSize: 12)),
              ],
            ),
          )
        ],
      ),
      body: _buildBody(historyState),
    );
  }

  Widget _buildBody(HistoryState state) {
    if (state.isLoading && state.readings.isEmpty && state.bills.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return RefreshIndicator(
        onRefresh: () => ref.read(historyProvider.notifier).refreshAll(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(state.error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () =>
                          ref.read(historyProvider.notifier).refreshAll(),
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return state.showingBills
        ? _buildBillsList(state)
        : _buildReadingsList(state);
  }

  Widget _buildReadingsList(HistoryState state) {
    if (state.readings.isEmpty) {
      return _buildEmptyState('No readings found. Snap some photos!');
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(historyProvider.notifier).refreshAll(),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: state.readings.length +
            (state.isFetchingMore && state.hasMoreReadings ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == state.readings.length) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final reading = state.readings[index];
          final String? displayText =
              (reading.extracted != null && reading.extracted!.isNotEmpty)
                  ? reading.extracted
                  : reading.readingValue?.toString();
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: _getValidationIcon(reading.validationStatus),
              title: Text(displayText != null ? '$displayText m³' : 'Pending OCR'),
              subtitle: Text(_dateFormat.format(reading.submissionTime)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        ReadingDetailScreen(readingId: reading.id)),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBillsList(HistoryState state) {
    return Column(
      children: [
        // Filter tabs
        _FilterTabs(
          active: state.billStatusFilter,
          onChanged: (v) =>
              ref.read(historyProvider.notifier).setStatusFilter(v),
        ),
        Expanded(
          child: state.bills.isEmpty && !state.isLoading
              ? _buildEmptyState('No bills found.')
              : RefreshIndicator(
                  onRefresh: () =>
                      ref.read(historyProvider.notifier).refreshAll(),
                  child: ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: state.bills.length +
                        (state.isFetchingMore && state.hasMoreBills ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == state.bills.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final bill = state.bills[index];
                      final displayAmount = bill.totalAmountVatInclusive ??
                          bill.totalAmount;
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _statusBgColor(bill.status),
                            child: Icon(
                              _statusIcon(bill.status),
                              color: _statusColor(bill.status),
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'RWF ${displayAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              BillStatusBadge(status: bill.status),
                            ],
                          ),
                          subtitle: Text(
                              'Generated: ${_dateFormat.format(bill.generatedDate)}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    BillDetailScreen(billId: bill.id)),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return RefreshIndicator(
      onRefresh: () => ref.read(historyProvider.notifier).refreshAll(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(message,
                    style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _getValidationIcon(String status) {
    switch (status) {
      case 'validated':
        return const Icon(Icons.check_circle, color: Colors.green);
      case 'pending':
        return const Icon(Icons.pending, color: Colors.orange);
      case 'failed':
      case 'fraud_suspected':
        return const Icon(Icons.warning, color: Colors.red);
      default:
        return const Icon(Icons.help_outline, color: Colors.grey);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'paid':
        return Colors.green;
      case 'overdue':
        return Colors.red;
      default:
        return Colors.amber.shade800;
    }
  }

  Color _statusBgColor(String status) {
    switch (status) {
      case 'paid':
        return Colors.green.shade100;
      case 'overdue':
        return Colors.red.shade100;
      default:
        return Colors.amber.shade100;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'paid':
        return Icons.check_circle;
      case 'overdue':
        return Icons.warning_amber_rounded;
      default:
        return Icons.receipt_long;
    }
  }
}
