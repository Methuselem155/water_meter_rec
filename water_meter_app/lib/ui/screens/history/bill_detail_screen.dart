import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../repositories/bill_repository.dart';
import '../../../models/bill.dart';
import '../../../models/reading.dart';
import 'reading_detail_screen.dart';
import 'history_screen.dart' show BillStatusBadge;

class BillDetailScreen extends ConsumerWidget {
  final String billId;
  const BillDetailScreen({super.key, required this.billId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billFuture = ref.read(billRepositoryProvider).getBillById(billId);

    return Scaffold(
      appBar: AppBar(title: const Text('Bill Summary')),
      body: FutureBuilder<Bill>(
        future: billFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Failed to load bill: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red)),
            );
          }

          final bill = snapshot.data!;
          final dateFormat = DateFormat('MMM dd, yyyy');
          final primaryColor = Theme.of(context).colorScheme.primary;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Overdue banner ──────────────────────────────────────────
                if (bill.status == 'overdue')
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.red.shade700),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'This bill is overdue. Please pay as soon as possible.',
                            style: TextStyle(
                                color: Colors.red.shade800,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Amount hero card ────────────────────────────────────────
                Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 28, horizontal: 16),
                    child: Column(
                      children: [
                        const Text('Amount Due',
                            style: TextStyle(fontSize: 15)),
                        const SizedBox(height: 6),
                        Text(
                          'RWF ${(bill.totalAmountVatInclusive ?? bill.totalAmount).toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 10),
                        BillStatusBadge(status: bill.status),
                        // Due date
                        if (bill.dueDate != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Due by ${dateFormat.format(bill.dueDate!)}',
                            style: TextStyle(
                              color: bill.status == 'paid'
                                  ? Colors.grey
                                  : Colors.red.shade700,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Reading breakdown ───────────────────────────────────────
                if (bill.reading != null) ...[
                  const Text('Meter Reading',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _MeterReadingDisplay(
                            reading: bill.reading!,
                            primaryColor: primaryColor,
                            baseStyle: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '* Red digits are estimated',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Consumption & amount summary ────────────────────────────
                const Text('Consumption Summary',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Previous → Current → Consumption
                        if (bill.previousReadingValue != null &&
                            bill.currentReadingValue != null)
                          _DetailRow(
                            label: 'Reading',
                            value:
                                '${bill.previousReadingValue} → ${bill.currentReadingValue} m³',
                          ),
                        _DetailRow(
                          label: 'Consumption',
                          value: '${bill.consumption} m³',
                        ),
                        if (bill.category != null)
                          _DetailRow(
                              label: 'Category', value: bill.category!),
                        const Divider(height: 24),
                        // Tariff bands
                        if (bill.tariffBands.isNotEmpty) ...[
                          const Text('Tariff Breakdown',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ...bill.tariffBands.map((band) => Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      band.tierName ??
                                          'Up to ${band.upTo} m³',
                                      style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 13),
                                    ),
                                    Text(
                                      band.cost != null
                                          ? 'RWF ${band.cost!.toStringAsFixed(2)}'
                                          : '${band.units} × ${band.rate}',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ],
                                ),
                              )),
                          const Divider(height: 24),
                        ],
                        // Totals
                        _DetailRow(
                          label: 'Subtotal',
                          value:
                              'RWF ${bill.totalAmount.toStringAsFixed(2)}',
                        ),
                        if (bill.vatAmount != null)
                          _DetailRow(
                            label: 'VAT (18%)',
                            value:
                                'RWF ${bill.vatAmount!.toStringAsFixed(2)}',
                          ),
                        const Divider(height: 16),
                        _DetailRow(
                          label: 'Total',
                          value:
                              'RWF ${(bill.totalAmountVatInclusive ?? bill.totalAmount).toStringAsFixed(2)}',
                          bold: true,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Payment details (paid only) ─────────────────────────────
                if (bill.status == 'paid' && bill.paidAt != null) ...[
                  const Text('Payment Details',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DetailRow(
                          label: 'Paid on',
                          value: dateFormat.format(bill.paidAt!),
                        ),
                        _DetailRow(
                          label: 'Method',
                          value: bill.paymentMethod?.toUpperCase() ?? '—',
                        ),
                        _DetailRow(
                          label: 'Reference',
                          value: bill.paymentReference?.isNotEmpty == true
                              ? bill.paymentReference!
                              : 'No reference',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Link to underlying reading ──────────────────────────────
                if (bill.reading != null) ...[
                  const Text('Reading Audit',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.camera_alt),
                      title: Text(
                          'Reading: ${bill.reading!.readingValue ?? 'Unknown'} m³'),
                      subtitle: const Text(
                          'View the photo that generated this bill'),
                      trailing: const Icon(Icons.arrow_forward),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ReadingDetailScreen(
                                readingId: bill.reading!.id)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Meter reading display (reuses same pattern as ReadingDetailScreen) ────────
class _MeterReadingDisplay extends StatelessWidget {
  final Reading reading;
  final Color primaryColor;
  final TextStyle? baseStyle;

  const _MeterReadingDisplay({
    required this.reading,
    required this.primaryColor,
    required this.baseStyle,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = reading.extracted?.isNotEmpty == true
        ? reading.extracted
        : reading.readingValue?.toString();

    if (reading.integerReading == null) {
      return Text(
        fallback != null ? '$fallback m³' : 'Processing OCR...',
        style: baseStyle?.copyWith(color: primaryColor),
      );
    }

    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: [
          TextSpan(
              text: reading.integerReading,
              style: TextStyle(color: primaryColor)),
          TextSpan(text: '.', style: TextStyle(color: primaryColor)),
          TextSpan(
              text: reading.decimalReading ?? '---',
              style: const TextStyle(color: Colors.red)),
          TextSpan(text: ' m³', style: TextStyle(color: primaryColor)),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _DetailRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(value,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.w500)),
        ],
      ),
    );
  }
}
