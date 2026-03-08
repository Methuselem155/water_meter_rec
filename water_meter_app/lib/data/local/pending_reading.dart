import 'package:hive/hive.dart';

part 'pending_reading.g.dart';

@HiveType(typeId: 0)
class PendingReading extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String imagePath;

  @HiveField(2)
  final String meterSerial;

  @HiveField(3)
  final DateTime timestamp;

  @HiveField(4)
  final String userId;

  @HiveField(5)
  String status; // 'pending', 'uploading', 'failed'

  @HiveField(6)
  int retryCount;

  PendingReading({
    required this.id,
    required this.imagePath,
    required this.meterSerial,
    required this.timestamp,
    required this.userId,
    this.status = 'pending',
    this.retryCount = 0,
  });
}
