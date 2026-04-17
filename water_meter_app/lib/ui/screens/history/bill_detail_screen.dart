import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
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
    final billFuture =
        ref.read(billRepositoryProvider).getBillById(billId);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Bill Details')),
      body: FutureBuilder<Bill>(
        future: billFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorBody(message: '${snapshot.error}');
          }

          final bill = snapshot.data!;
          final dateFmt = DateFormat('MMM dd, yyyy');
          final amount =
              bill.totalAmountVatInclusive ?? bill.totalAmount;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Overdue banner ────────────────────────────────────
                if (bill.status == 'overdue') ...[
                  _Banner(
                    icon: Icons.warning_amber_rounded,
                    message:
                        'This bill is overdue. Please pay as soon as possible.',
                    color: AppTheme.statusOverdue,
                    bg: AppTheme.statusOverdueBg,
                  ),
                  const SizedBox(height: 12),
                ],

                // ── Amount hero ───────────────────────────────────────
                _AmountHero(
                  amount: amount,
                  status: bill.status,
                  dueDate: bill.dueDate != null
                      ? dateFmt.format(bill.dueDate!)
                      : null,
                ),
                const SizedBox(height: 16),

                // ── Consumption summary ───────────────────────────────
                _SectionCard(
                  title: 'Consumption Summary',
                  icon: Icons.water_drop_outlined,
                  child: Column(
                    children: [
                      if (bill.previousReadingValue != null &&
                          bill.currentReadingValue != null)
                        _Row(
                          label: 'Reading',
                          value:
                              '${bill.previousReadingValue} → ${bill.currentReadingValue} m³',
                        ),
                      _Row(
                          label: 'Consumption',
                          value: '${bill.consumption} m³'),
                      if (bill.category != null)
                        _Row(
                            label: 'Category',
                            value: bill.category!),
                      if (bill.tariffBands.isNotEmpty) ...[
                        const _Divider(),
                        const _Label('Tariff Breakdown'),
                        const SizedBox(height: 8),
                        ...bill.tariffBands.map(
                          (band) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  band.tierName ??
                                      'Up to ${band.upTo} m³',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium,
                                ),
                                Text(
                                  band.cost != null
                                      ? 'RWF ${band.cost!.toStringAsFixed(0)}'
                                      : '${band.units} × ${band.rate}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const _Divider(),
                      _Row(
                          label: 'Subtotal',
                          value:
                              'RWF ${bill.totalAmount.toStringAsFixed(0)}'),
                      if (bill.vatAmount != null)
                        _Row(
                            label: 'VAT (18%)',
                            value:
                                'RWF ${bill.vatAmount!.toStringAsFixed(0)}'),
                      const _Divider(),
                      _Row(
                        label: 'Total Due',
                        value: 'RWF ${amount.toStringAsFixed(0)}',
                        bold: true,
                        valueColor: AppTheme.primaryBlue,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Meter reading ─────────────────────────────────────
                if (bill.reading != null) ...[
                  _SectionCard(
                    title: 'Meter Reading',
                    icon: Icons.speed_rounded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ReadingDisplay(
                          reading: bill.reading!,
                          primaryColor:
                              Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '* Decimal digits shown in red',
                          style:
                              Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // ── Payment info ──────────────────────────────────────
                if (bill.status == 'paid' && bill.paidAt != null) ...[
                  _SectionCard(
                    title: 'Payment Details',
                    icon: Icons.check_circle_outline_rounded,
                    iconColor: AppTheme.statusPaid,
                    child: Column(
                      children: [
                        _Row(
                            label: 'Paid on',
                            value: dateFmt.format(bill.paidAt!)),
                        _Row(
                          label: 'Method',
                          value:
                              bill.paymentMethod?.toUpperCase() ?? '—',
                        ),
                        _Row(
                          label: 'Reference',
                          value: bill.paymentReference?.isNotEmpty ==
                                  true
                              ? bill.paymentReference!
                              : 'No reference',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // ── Reading audit link ────────────────────────────────
                if (bill.reading != null)
                  _AuditLink(
                    readingValue: bill.reading!.readingValue,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReadingDetailScreen(
                            readingId: bill.reading!.id),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Amount hero ───────────────────────────────────────────────────────────────

class _AmountHero extends StatelessWidget {
  final num amount;
  final String status;
  final String? dueDate;

  const _AmountHero(
      {required this.amount, required this.status, this.dueDate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryBlue, Color(0xFF0D47A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Text('Amount Due',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 14)),
          const SizedBox(height: 8),
          Text(
            'RWF ${amount.toStringAsFixed(0)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          BillStatusBadge(status: status),
          if (dueDate != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 13,
                  color: status == 'paid'
                      ? Colors.white54
                      : Colors.white,
                ),
                const SizedBox(width: 5),
                Text(
                  'Due $dueDate',
                  style: TextStyle(
                    color: status == 'paid'
                        ? Colors.white54
                        : Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Section card ──────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? iconColor;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? AppTheme.primaryBlue;
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(color: color)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ── Detail row ────────────────────────────────────────────────────────────────

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  const _Row(
      {required this.label,
      required this.value,
      this.bold = false,
      this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label,
                style: Theme.of(context).textTheme.bodyMedium),
          ),
          const SizedBox(width: 16),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
              color: valueColor ?? Colors.white,
              fontSize: 14,
            ),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      Divider(height: 20, color: Colors.grey.shade200);
}

class _Label extends StatelessWidget {
  final String text;

  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.5));
  }
}

// ── Banner ────────────────────────────────────────────────────────────────────

class _Banner extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;
  final Color bg;

  const _Banner(
      {required this.icon,
      required this.message,
      required this.color,
      required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ── Audit link ────────────────────────────────────────────────────────────────

class _AuditLink extends StatelessWidget {
  final num? readingValue;
  final VoidCallback onTap;

  const _AuditLink({required this.readingValue, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: AppTheme.primaryBlue.withValues(alpha: 0.2)),
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
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.camera_alt_rounded,
                  color: AppTheme.primaryBlue, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('View Source Reading',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryBlue)),
                  Text(
                    readingValue != null
                        ? '$readingValue m³ — tap to see the captured photo'
                        : 'View the photo that generated this bill',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: AppTheme.primaryBlue, size: 14),
          ],
        ),
      ),
    );
  }
}

// ── Reading display ───────────────────────────────────────────────────────────

class _ReadingDisplay extends StatelessWidget {
  final Reading reading;
  final Color primaryColor;

  const _ReadingDisplay(
      {required this.reading, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    final fallback = reading.extracted?.isNotEmpty == true
        ? reading.extracted
        : reading.readingValue?.toString();

    final style = Theme.of(context)
        .textTheme
        .headlineSmall
        ?.copyWith(fontWeight: FontWeight.w800);

    if (reading.integerReading == null) {
      return Text(
        fallback != null ? '$fallback m³' : 'Processing…',
        style: style?.copyWith(color: primaryColor),
      );
    }

    return RichText(
      text: TextSpan(
        style: style,
        children: [
          TextSpan(
              text: reading.integerReading,
              style: TextStyle(color: primaryColor)),
          TextSpan(text: '.', style: TextStyle(color: primaryColor)),
          TextSpan(
              text: reading.decimalReading ?? '---',
              style:
                  const TextStyle(color: AppTheme.statusOverdue)),
          TextSpan(
              text: ' m³',
              style: TextStyle(color: primaryColor)),
        ],
      ),
    );
  }
}

// ── Error body ────────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  final String message;

  const _ErrorBody({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 48, color: AppTheme.errorRed),
            const SizedBox(height: 16),
            Text('Failed to load bill',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
