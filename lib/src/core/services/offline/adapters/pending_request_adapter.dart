import 'package:hive/hive.dart';
import '../pending_request.dart';

/// Manual Hive TypeAdapter for PendingRequest
/// Created manually because hive_generator conflicts with riverpod_generator
class PendingRequestAdapter extends TypeAdapter<PendingRequest> {
  @override
  final int typeId = 0;

  @override
  PendingRequest read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PendingRequest(
      id: fields[0] as String,
      endpoint: fields[1] as String,
      method: fields[2] as String,
      payload: (fields[3] as Map).cast<String, dynamic>(),
      createdAt: fields[4] as DateTime,
      retryCount: fields[5] as int? ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, PendingRequest obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.endpoint)
      ..writeByte(2)
      ..write(obj.method)
      ..writeByte(3)
      ..write(obj.payload)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.retryCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingRequestAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
