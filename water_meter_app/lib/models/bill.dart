import 'package:equatable/equatable.dart';
import 'reading.dart';

class TariffBand extends Equatable {
  final num upTo;
  final num rate;

  const TariffBand({required this.upTo, required this.rate});

  factory TariffBand.fromJson(Map<String, dynamic> json) {
    return TariffBand(
      upTo: json['upTo'] ?? double.infinity,
      rate: json['rate'] ?? 0,
    );
  }

  @override
  List<Object?> get props => [upTo, rate];
}

class Bill extends Equatable {
  final String id;
  // Can be ID string or fully populated Reading object, but usually we just want details
  final String readingId;
  final String? previousReadingId;
  final num consumption;
  final List<TariffBand> tariffBands;
  final num totalAmount;
  final DateTime generatedDate;
  final String status;
  // If populated from endpoint
  final Reading? reading; 

  const Bill({
    required this.id,
    required this.readingId,
    this.previousReadingId,
    required this.consumption,
    this.tariffBands = const [],
    required this.totalAmount,
    required this.generatedDate,
    required this.status,
    this.reading,
  });

  factory Bill.fromJson(Map<String, dynamic> json) {
    return Bill(
      id: json['_id'] ?? json['id'] ?? '',
      readingId: json['readingId'] is Map ? (json['readingId']['_id'] ?? '') : (json['readingId'] ?? ''),
      previousReadingId: json['previousReadingId'] is Map ? (json['previousReadingId']['_id'] ?? '') : json['previousReadingId'],
      consumption: json['consumption'] ?? 0,
      tariffBands: (json['tariffBands'] as List<dynamic>?)?.map((e) => TariffBand.fromJson(e)).toList() ?? [],
      totalAmount: json['totalAmount'] ?? 0,
      generatedDate: json['generatedDate'] != null ? DateTime.parse(json['generatedDate']) : DateTime.now(),
      status: json['status'] ?? 'draft',
      // If the API populated the reading field (e.g., getting a single bill)
      reading: json['readingId'] is Map ? Reading.fromJson(json['readingId']) : null,
    );
  }

  @override
  List<Object?> get props => [
        id, readingId, previousReadingId, consumption, tariffBands,
        totalAmount, generatedDate, status, reading
      ];
}

class PaginatedBills {
  final List<Bill> bills;
  final int count;
  final bool hasNextPage;
  
  PaginatedBills({required this.bills, required this.count, required this.hasNextPage});

  factory PaginatedBills.fromJson(Map<String, dynamic> json) {
    final List<dynamic> data = json['data'] ?? [];
    return PaginatedBills(
      bills: data.map((e) => Bill.fromJson(e)).toList(),
      count: json['count'] ?? 0,
      hasNextPage: json['pagination']?['next'] != null,
    );
  }
}
