import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../repositories/reading_repository.dart';
import '../../../models/reading.dart';
import '../../../core/constants.dart';

class ReadingDetailScreen extends ConsumerStatefulWidget {
  final String readingId;

  const ReadingDetailScreen({super.key, required this.readingId});

  @override
  ConsumerState<ReadingDetailScreen> createState() => _ReadingDetailScreenState();
}

class _ReadingDetailScreenState extends ConsumerState<ReadingDetailScreen> {
  late Future<Reading> _readingFuture;

  @override
  void initState() {
    super.initState();
    _readingFuture = ref.read(readingRepositoryProvider).getReadingById(widget.readingId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reading Details')),
      body: FutureBuilder<Reading>(
        future: _readingFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load reading: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => setState(() {
                        _readingFuture = ref
                            .read(readingRepositoryProvider)
                            .getReadingById(widget.readingId);
                      }),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final reading = snapshot.data!;
          // Use rawText (exact OCR string) to preserve leading zeros
          // Fall back to readingValue if rawText not available
          final String? displayText = (reading.extracted != null && reading.extracted!.isNotEmpty)
              ? reading.extracted
              : reading.readingValue?.toString();
          final dateFormat = DateFormat('MMMM dd, yyyy - HH:mm');

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Core Header Specs
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          displayText != null
                              ? '$displayText m³'
                              : 'Processing OCR...',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                        const SizedBox(height: 8),
                        _buildStatusChip(reading.validationStatus),
                        const SizedBox(height: 16),
                        const Divider(),
                        _DetailRow(
                          label: 'Submitted Date',
                          value: dateFormat.format(reading.submissionTime),
                        ),
                        _DetailRow(
                          label: 'Identified Serial',
                          value: reading.serialNumberExtracted ?? 'Scanning...',
                        ),
                        if (reading.confidence != null)
                          _DetailRow(
                            label: 'OCR Confidence',
                            value:
                                '${(reading.confidence! * 100).toStringAsFixed(1)}%',
                            valueColor: reading.confidence! > 0.8
                                ? Colors.green
                                : (reading.confidence! > 0.5
                                      ? Colors.orange
                                      : Colors.red),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // 2. Photo Evidence Viewer
                const Text(
                  'Captured Image Evidence',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (reading.imagePath != null && reading.imagePath!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      // Construct proper HTTP URL from relative path
                      '${Constants.baseUrl.replaceAll('/api', '')}/${reading.imagePath!}',
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const SizedBox(
                          height: 200,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 200,
                          color: Colors.grey.shade200,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.broken_image,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Failed to load image',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'URL: ${reading.imagePath}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  )
                else
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: const Center(child: Text('Image data unavailable')),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'validated':
        color = Colors.green;
        break;
      case 'pending':
        color = Colors.orange;
        break;
      case 'failed':
      case 'fraud_suspected':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Chip(
      label: Text(
        status.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
      backgroundColor: color,
    );
  }

  /// Fallback: extract a numeric reading from raw OCR text when `readingValue` is null.
  num? _extractDigitsFromText(String? text) {
    if (text == null || text.isEmpty) return null;
    final dense = text.replaceAll(RegExp(r'\s+'), '');
    final match = RegExp(r'\d{3,}').firstMatch(dense);
    if (match == null) return null;
    return num.tryParse(match.group(0)!);
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, color: valueColor),
          ),
        ],
      ),
    );
  }
}
