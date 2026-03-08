import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../providers/history_provider.dart';
import 'reading_detail_screen.dart';
import 'bill_detail_screen.dart';

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
    // Attach pagination listener
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      // User is nearing the bottom, request next data chunk
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
          // Toggle between Viewing Raw Readings vs Audited Bills
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Row(
              children: [
                const Text('Readings', style: TextStyle(fontSize: 12)),
                Switch(
                  value: historyState.showingBills,
                  activeThumbColor: Theme.of(context).colorScheme.secondary,
                  onChanged: (val) {
                    ref.read(historyProvider.notifier).toggleView();
                  },
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
                      onPressed: () => ref.read(historyProvider.notifier).refreshAll(),
                      child: const Text('Try Again'),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (state.showingBills) {
      return _buildBillsList(state);
    } else {
      return _buildReadingsList(state);
    }
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
        itemCount: state.readings.length + (state.isFetchingMore && state.hasMoreReadings ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == state.readings.length) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final reading = state.readings[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: _getValidationIcon(reading.validationStatus),
              title: Text('Reading @ ${reading.readingValue ?? 'Pending OCR'}'),
              subtitle: Text(_dateFormat.format(reading.submissionTime)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ReadingDetailScreen(readingId: reading.id)),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildBillsList(HistoryState state) {
    if (state.bills.isEmpty) {
      return _buildEmptyState('No bills generated yet.');
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(historyProvider.notifier).refreshAll(),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: state.bills.length + (state.isFetchingMore && state.hasMoreBills ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == state.bills.length) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final bill = state.bills[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: bill.status == 'paid' ? Colors.green.shade100 : Colors.orange.shade100,
                child: Icon(
                  bill.status == 'paid' ? Icons.check_circle : Icons.receipt_long,
                  color: bill.status == 'paid' ? Colors.green : Colors.orange,
                ),
              ),
              title: Text('Total: \$${bill.totalAmount.toStringAsFixed(2)}'),
              subtitle: Text('Generated: ${_dateFormat.format(bill.generatedDate)}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => BillDetailScreen(billId: bill.id)),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return RefreshIndicator(
      onRefresh: () => ref.read(historyProvider.notifier).refreshAll(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(message, style: TextStyle(color: Colors.grey.shade600)),
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
}
