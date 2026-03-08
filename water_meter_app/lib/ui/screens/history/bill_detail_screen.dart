import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../repositories/bill_repository.dart';
import '../../../models/bill.dart';
import 'reading_detail_screen.dart';

class BillDetailScreen extends ConsumerWidget {
  final String billId;

  const BillDetailScreen({super.key, required this.billId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billFuture = ref.read(billRepositoryProvider).getBillById(billId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill Summary'),
      ),
      body: FutureBuilder<Bill>(
        future: billFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
             return Center(
               child: Text('Failed to load bill: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
             );
          }

          final bill = snapshot.data!;
          final dateFormat = DateFormat('MMMM dd, yyyy');

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Total Bill Metric
                Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 16.0),
                    child: Column(
                      children: [
                        const Text('Amount Due', style: TextStyle(fontSize: 16)),
                        const SizedBox(height: 8),
                        Text(
                          '\$${bill.totalAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                         const SizedBox(height: 8),
                        _buildStatusChip(bill.status),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),

                // 2. Consumption Breakdown
                const Text('Billing Period Data', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         _DetailRow(label: 'Total Consumption', value: '${bill.consumption} Units'),
                         _DetailRow(label: 'Generation Date', value: dateFormat.format(bill.generatedDate)),
                         const Divider(height: 32),
                         const Text('Tariff Bracket Analysis', style: TextStyle(fontWeight: FontWeight.bold)),
                         const SizedBox(height: 12),
                         if (bill.tariffBands.isEmpty)
                            const Text('No tariff bands mapped to this computation', style: TextStyle(color: Colors.grey))
                         else
                            ...bill.tariffBands.map((band) {
                               return Padding(
                                 padding: const EdgeInsets.only(bottom: 8.0),
                                 child: Row(
                                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                   children: [
                                      Text('Tier up to ${band.upTo} units'),
                                      Text('\$${band.rate.toStringAsFixed(2)} / unit'),
                                   ],
                                 ),
                               );
                            }),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // 3. Optional Audit Link to the base reading
                if (bill.reading != null) ...[
                   const Text('Underlying Reading Audit', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                   const SizedBox(height: 8),
                   Card(
                     child: ListTile(
                       leading: const Icon(Icons.camera_alt),
                       title: Text('Reading Event: ${bill.reading!.readingValue ?? 'Unknown'} Units'),
                       subtitle: const Text('View exactly what photograph generated this bill'),
                       trailing: const Icon(Icons.arrow_forward),
                       onTap: () {
                         Navigator.push(
                           context, 
                           MaterialPageRoute(builder: (_) => ReadingDetailScreen(readingId: bill.reading!.id))
                         );
                       },
                     ),
                   )
                ]
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch(status) {
      case 'paid': color = Colors.green; break;
      case 'draft': color = Colors.grey; break;
      case 'final': color = Colors.blue; break;
      default: color = Colors.orange;
    }
    
    return Chip(
      label: Text(status.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
      backgroundColor: color,
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
