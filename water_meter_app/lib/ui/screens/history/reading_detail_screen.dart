import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../repositories/reading_repository.dart';
import '../../../models/reading.dart';
import '../../../core/constants.dart';

class ReadingDetailScreen extends ConsumerWidget {
  final String readingId;

  const ReadingDetailScreen({super.key, required this.readingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // We intentionally fetch live details on navigating instead of passing full model
    // To grab any newly populated metadata (like OCR status updating server side)
    final readingFuture = ref.read(readingRepositoryProvider).getReadingById(readingId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reading Details'),
      ),
      body: FutureBuilder<Reading>(
        future: readingFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
             return Center(
               child: Text('Failed to load reading: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
             );
          }

          final reading = snapshot.data!;
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
                          reading.readingValue != null ? '${reading.readingValue} Units' : 'Processing OCR...',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                         _buildStatusChip(reading.validationStatus),
                        const SizedBox(height: 16),
                        const Divider(),
                        _DetailRow(label: 'Submitted Date', value: dateFormat.format(reading.submissionTime)),
                        _DetailRow(label: 'Identified Serial', value: reading.serialNumberExtracted ?? 'Scanning...'),
                        if (reading.confidence != null)
                          _DetailRow(
                            label: 'OCR Confidence', 
                            value: '${(reading.confidence! * 100).toStringAsFixed(1)}%',
                            valueColor: reading.confidence! > 0.8 ? Colors.green : Colors.orange,
                          ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // 2. Photo Evidence Viewer
                const Text('Captured Image Evidence', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (reading.imagePath != null && reading.imagePath!.isNotEmpty)
                   ClipRRect(
                     borderRadius: BorderRadius.circular(12),
                     child: Image.network(
                        // Path mapping the node static uploads alias cleanly
                        // We replace any leading slash so it merges into baseURL appropriately
                        '${Constants.baseUrl.replaceAll('/api', '')}/${reading.imagePath!.replaceAll('\\', '/')}',
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
                             child: const Center(child: Icon(Icons.broken_image, size: 48, color: Colors.grey)),
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
    switch(status) {
      case 'validated': color = Colors.green; break;
      case 'pending': color = Colors.orange; break;
      case 'failed': 
      case 'fraud_suspected': color = Colors.red; break;
      default: color = Colors.grey;
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
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: valueColor)),
        ],
      ),
    );
  }
}
