import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../../../repositories/reading_repository.dart';
import '../../../models/reading.dart';
import '../../../core/constants.dart';

class ReadingDetailScreen extends ConsumerStatefulWidget {
  final String readingId;

  const ReadingDetailScreen({super.key, required this.readingId});

  @override
  ConsumerState<ReadingDetailScreen> createState() =>
      _ReadingDetailScreenState();
}

class _ReadingDetailScreenState
    extends ConsumerState<ReadingDetailScreen> {
  late Future<Reading> _readingFuture;

  @override
  void initState() {
    super.initState();
    _readingFuture = ref
        .read(readingRepositoryProvider)
        .getReadingById(widget.readingId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Reading Details')),
      body: FutureBuilder<Reading>(
        future: _readingFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _ErrorBody(
              message: '${snapshot.error}',
              onRetry: () => setState(() {
                _readingFuture = ref
                    .read(readingRepositoryProvider)
                    .getReadingById(widget.readingId);
              }),
            );
          }

          final reading = snapshot.data!;
          final display =
              (reading.extracted?.isNotEmpty == true)
                  ? reading.extracted
                  : reading.readingValue?.toString();
          final dateFmt = DateFormat('MMMM dd, yyyy · HH:mm');
          final primary = Theme.of(context).colorScheme.primary;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Reading hero ──────────────────────────────────────
                _ReadingHero(
                  reading: reading,
                  displayText: display,
                  primaryColor: primary,
                ),
                const SizedBox(height: 14),

                // ── Details card ──────────────────────────────────────
                _SectionCard(
                  title: 'Reading Info',
                  icon: Icons.info_outline_rounded,
                  child: Column(
                    children: [
                      _Row(
                        label: 'Submitted',
                        value: dateFmt
                            .format(reading.submissionTime),
                      ),
                      _Row(
                        label: 'Serial Number',
                        value: reading.serialNumberExtracted ??
                            'Scanning…',
                      ),
                      if (reading.confidence != null)
                        _ConfidenceRow(
                            confidence: reading.confidence!.toDouble()),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── Image evidence ────────────────────────────────────
                _SectionCard(
                  title: 'Captured Image',
                  icon: Icons.photo_camera_outlined,
                  child: _ImageEvidence(
                      imagePath: reading.imagePath),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Reading hero ──────────────────────────────────────────────────────────────

class _ReadingHero extends StatelessWidget {
  final Reading reading;
  final String? displayText;
  final Color primaryColor;

  const _ReadingHero({
    required this.reading,
    required this.displayText,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusIcon, statusLabel) =
        _statusInfo(reading.validationStatus);

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
          Text(
            'Extracted Reading',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          _ReadingDisplay(
            integerReading: reading.integerReading,
            decimalReading: reading.decimalReading,
            displayText: displayText,
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: statusColor.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon,
                    color: statusColor, size: 15),
                const SizedBox(width: 6),
                Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  (Color, IconData, String) _statusInfo(String s) {
    switch (s) {
      case 'validated':
        return (Colors.greenAccent, Icons.check_circle_rounded,
            'VALIDATED');
      case 'pending':
        return (Colors.amberAccent, Icons.hourglass_top_rounded,
            'PENDING');
      case 'failed':
      case 'fraud_suspected':
        return (Colors.redAccent, Icons.cancel_rounded, 'FAILED');
      default:
        return (Colors.white54, Icons.help_outline_rounded, 'UNKNOWN');
    }
  }
}

// ── Reading display ───────────────────────────────────────────────────────────

class _ReadingDisplay extends StatelessWidget {
  final String? integerReading;
  final String? decimalReading;
  final String? displayText;

  const _ReadingDisplay({
    required this.integerReading,
    required this.decimalReading,
    required this.displayText,
  });

  @override
  Widget build(BuildContext context) {
    const white = TextStyle(
      color: Colors.white,
      fontSize: 38,
      fontWeight: FontWeight.w800,
      letterSpacing: -1,
    );

    if (integerReading == null) {
      return Text(
        displayText != null ? '$displayText m³' : 'Processing…',
        style: white,
        textAlign: TextAlign.center,
      );
    }

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: white,
        children: [
          TextSpan(text: integerReading),
          const TextSpan(text: '.'),
          TextSpan(
            text: decimalReading ?? '---',
            style: const TextStyle(color: Color(0xFFFF8A80)),
          ),
          const TextSpan(
              text: ' m³',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Confidence row ────────────────────────────────────────────────────────────

class _ConfidenceRow extends StatelessWidget {
  final double confidence;

  const _ConfidenceRow({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final pct = confidence * 100;
    final color = pct >= 80
        ? AppTheme.statusPaid
        : pct >= 50
            ? AppTheme.statusUnpaid
            : AppTheme.statusOverdue;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('OCR Confidence',
                  style: Theme.of(context).textTheme.bodyMedium),
              Text(
                '${pct.toStringAsFixed(1)}%',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: color,
                    fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: confidence,
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section card ──────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard(
      {required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
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
              Icon(icon, size: 17, color: AppTheme.primaryBlue),
              const SizedBox(width: 7),
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(color: AppTheme.primaryBlue)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;

  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
              child: Text(label,
                  style:
                      Theme.of(context).textTheme.bodyMedium)),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontSize: 14),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Image evidence ────────────────────────────────────────────────────────────

class _ImageEvidence extends StatelessWidget {
  final String? imagePath;

  const _ImageEvidence({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    if (imagePath == null || imagePath!.isEmpty) {
      return Container(
        height: 150,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.image_not_supported_outlined,
                  size: 36, color: Colors.grey.shade400),
              const SizedBox(height: 8),
              Text('No image available',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );
    }

    final url =
        '${Constants.baseUrl.replaceAll('/api', '')}/$imagePath';

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        width: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            height: 200,
            color: Colors.grey.shade100,
            child: Center(
              child: CircularProgressIndicator(
                value: progress.expectedTotalBytes != null
                    ? progress.cumulativeBytesLoaded /
                        progress.expectedTotalBytes!
                    : null,
                color: AppTheme.primaryBlue,
                strokeWidth: 2,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stack) => Container(
          height: 160,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image_outlined,
                    size: 36, color: Colors.grey.shade400),
                const SizedBox(height: 8),
                Text('Failed to load image',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Error body ────────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBody(
      {required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 52, color: AppTheme.errorRed),
            const SizedBox(height: 16),
            Text('Could not load reading',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
