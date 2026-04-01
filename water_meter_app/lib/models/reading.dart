import 'package:equatable/equatable.dart';

class Reading extends Equatable {
  final String id;
  final String meterId;
  final String? imagePath;
  final String? serialNumberExtracted;
  // Raw OCR text returned from backend (aliased as "extracted")
  final String? extracted;
  final num? readingValue;
  final num? confidence;
  final String validationStatus;
  final DateTime submissionTime;
  final String? billingPeriod;

  const Reading({
    required this.id,
    required this.meterId,
    this.imagePath,
    this.serialNumberExtracted,
    this.extracted,
    this.readingValue,
    this.confidence,
    required this.validationStatus,
    required this.submissionTime,
    this.billingPeriod,
  });

  factory Reading.fromJson(Map<String, dynamic> json) {
    // Safely parse readingValue which might be a String from backend
    num? parsedValue;
    if (json['readingValue'] != null) {
      if (json['readingValue'] is num) {
        parsedValue = json['readingValue'];
      } else {
        parsedValue = num.tryParse(json['readingValue'].toString());
      }
    }

    return Reading(
      id: json['_id'] ?? json['id'] ?? '',
      // Sometimes meterId is fully populated, sometimes just ID, sometimes keyed as 'meter'
      meterId: json['meterId'] is Map
          ? (json['meterId']['_id'] ?? '')
          : json['meterId'] != null
              ? (json['meterId'] ?? '')
              : json['meter'] is Map
                  ? (json['meter']['_id'] ?? '')
                  : (json['meter'] ?? ''),
      imagePath: json['imagePath'],
      serialNumberExtracted: json['serialNumberExtracted'],
      extracted: json['extracted'] ?? json['ocrRawText'],
      readingValue: parsedValue,
      confidence: json['confidence'] != null
          ? num.tryParse(json['confidence'].toString())
          : null,
      validationStatus: json['validationStatus'] ?? 'pending',
      submissionTime: json['submissionTime'] != null
          ? DateTime.parse(json['submissionTime'])
          : DateTime.now(),
      billingPeriod: json['billingPeriod'],
    );
  }

  @override
  List<Object?> get props => [
        id, meterId, imagePath, serialNumberExtracted, extracted, readingValue,
        confidence, validationStatus, submissionTime, billingPeriod
      ];
}

// Wrapper for paginated response
class PaginatedReadings {
  final List<Reading> readings;
  final int count;
  final bool hasNextPage;
  
  PaginatedReadings({required this.readings, required this.count, required this.hasNextPage});

  factory PaginatedReadings.fromJson(Map<String, dynamic> json) {
    final List<dynamic> data = json['data'] ?? [];
    return PaginatedReadings(
      readings: data.map((e) => Reading.fromJson(e)).toList(),
      count: json['count'] ?? 0,
      hasNextPage: json['pagination']?['next'] != null,
    );
  }
}
