import 'package:equatable/equatable.dart';
import 'reading.dart';

class TariffBand extends Equatable {
  final num upTo;
  final num rate;
  final num? units;
  final num? cost;
  final String? tierName;

  const TariffBand({
    required this.upTo,
    required this.rate,
    this.units,
    this.cost,
    this.tierName,
  });

  factory TariffBand.fromJson(Map<String, dynamic> json) {
    return TariffBand(
      upTo: json['upTo'] ?? double.infinity,
      rate: json['rate'] ?? 0,
      units: json['units'] != null ? num.tryParse(json['units'].toString()) : null,
      cost: json['cost'] != null ? num.tryParse(json['cost'].toString()) : null,
      tierName: json['tierName'] as String?,
    );
  }

  @override
  List<Object?> get props => [upTo, rate, units, cost, tierName];
}

class Bill extends Equatable {
  final String id;
  final String readingId;
  final String? previousReadingId;
  final num? previousReadingValue;
  final num? currentReadingValue;
  final num consumption;
  final List<TariffBand> tariffBands;
  final num totalAmount;
  final num? vatAmount;
  final num? totalAmountVatInclusive;
  final DateTime generatedDate;
  final DateTime? dueDate;
  final String status;
  final DateTime? paidAt;
  final String? paymentMethod;
  final String? paymentReference;
  final String? category;
  final Reading? reading;

  const Bill({
    required this.id,
    required this.readingId,
    this.previousReadingId,
    this.previousReadingValue,
    this.currentReadingValue,
    required this.consumption,
    this.tariffBands = const [],
    required this.totalAmount,
    this.vatAmount,
    this.totalAmountVatInclusive,
    required this.generatedDate,
    this.dueDate,
    required this.status,
    this.paidAt,
    this.paymentMethod,
    this.paymentReference,
    this.category,
    this.reading,
  });

  factory Bill.fromJson(Map<String, dynamic> json) {
    return Bill(
      id: json['_id'] ?? json['id'] ?? '',
      readingId: json['readingId'] is Map
          ? (json['readingId']['_id'] ?? '')
          : (json['readingId'] ?? ''),
      previousReadingId: json['previousReadingId'] is Map
          ? (json['previousReadingId']['_id'] ?? '')
          : json['previousReadingId'] as String?,
      previousReadingValue: json['previousReadingValue'] != null
          ? num.tryParse(json['previousReadingValue'].toString())
          : null,
      currentReadingValue: json['currentReadingValue'] != null
          ? num.tryParse(json['currentReadingValue'].toString())
          : null,
      consumption: json['consumption'] ?? 0,
      tariffBands: (json['tariffBands'] as List<dynamic>?)
              ?.map((e) => TariffBand.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      totalAmount: json['totalAmount'] ?? 0,
      vatAmount: json['vatAmount'] != null
          ? num.tryParse(json['vatAmount'].toString())
          : null,
      totalAmountVatInclusive: json['totalAmountVatInclusive'] != null
          ? num.tryParse(json['totalAmountVatInclusive'].toString())
          : null,
      generatedDate: json['generatedDate'] != null
          ? DateTime.parse(json['generatedDate'])
          : DateTime.now(),
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
      status: json['status'] ?? 'unpaid',
      paidAt: json['paidAt'] != null ? DateTime.parse(json['paidAt']) : null,
      paymentMethod: json['paymentMethod'] as String?,
      paymentReference: json['paymentReference'] as String?,
      category: json['category'] as String?,
      reading: json['readingId'] is Map
          ? Reading.fromJson(json['readingId'] as Map<String, dynamic>)
          : null,
    );
  }

  @override
  List<Object?> get props => [
        id, readingId, previousReadingId, previousReadingValue,
        currentReadingValue, consumption, tariffBands, totalAmount,
        vatAmount, totalAmountVatInclusive, generatedDate, dueDate,
        status, paidAt, paymentMethod, paymentReference, category, reading,
      ];
}

class BillSummary {
  final int totalUnpaid;
  final int totalPaid;
  final int totalOverdue;
  final num totalAmountUnpaid;
  final num totalAmountOverdue;

  const BillSummary({
    required this.totalUnpaid,
    required this.totalPaid,
    required this.totalOverdue,
    required this.totalAmountUnpaid,
    required this.totalAmountOverdue,
  });

  factory BillSummary.fromJson(Map<String, dynamic> json) {
    final d = json['data'] as Map<String, dynamic>? ?? json;
    return BillSummary(
      totalUnpaid: (d['totalUnpaid'] as num?)?.toInt() ?? 0,
      totalPaid: (d['totalPaid'] as num?)?.toInt() ?? 0,
      totalOverdue: (d['totalOverdue'] as num?)?.toInt() ?? 0,
      totalAmountUnpaid: d['totalAmountUnpaid'] as num? ?? 0,
      totalAmountOverdue: d['totalAmountOverdue'] as num? ?? 0,
    );
  }
}

class PaginatedBills {
  final List<Bill> bills;
  final int count;
  final bool hasNextPage;

  PaginatedBills({
    required this.bills,
    required this.count,
    required this.hasNextPage,
  });

  factory PaginatedBills.fromJson(Map<String, dynamic> json) {
    final List<dynamic> data = json['data'] ?? [];
    return PaginatedBills(
      bills: data.map((e) => Bill.fromJson(e as Map<String, dynamic>)).toList(),
      count: json['count'] ?? 0,
      hasNextPage: json['pagination']?['next'] != null,
    );
  }
}
