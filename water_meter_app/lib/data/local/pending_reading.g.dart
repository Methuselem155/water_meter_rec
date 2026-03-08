// GENERATED CODE - DO NOT MODIFY BY HAND
part of 'pending_reading.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PendingReadingAdapter extends TypeAdapter<PendingReading> {
  @override
  final int typeId = 0;

  @override
  PendingReading read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PendingReading(
      id: fields[0] as String,
      imagePath: fields[1] as String,
      meterSerial: fields[2] as String,
      timestamp: fields[3] as DateTime,
      userId: fields[4] as String,
      status: fields[5] as String,
      retryCount: fields[6] as int,
    );
  }

  @override
  void write(BinaryWriter writer, PendingReading obj) {
    writer
      ..writeByte(7) // Total number of fields
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.imagePath)
      ..writeByte(2)
      ..write(obj.meterSerial)
      ..writeByte(3)
      ..write(obj.timestamp)
      ..writeByte(4)
      ..write(obj.userId)
      ..writeByte(5)
      ..write(obj.status)
      ..writeByte(6)
      ..write(obj.retryCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingReadingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
