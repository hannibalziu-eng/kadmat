import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'pending_request.g.dart';

@JsonSerializable()
@HiveType(typeId: 0)
class PendingRequest extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String endpoint;

  @HiveField(2)
  final String method;

  @HiveField(3)
  final Map<String, dynamic> payload;

  @HiveField(4)
  final DateTime createdAt;

  @HiveField(5)
  int retryCount;

  PendingRequest({
    required this.id,
    required this.endpoint,
    required this.method,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
  });

  factory PendingRequest.fromJson(Map<String, dynamic> json) =>
      _$PendingRequestFromJson(json);

  Map<String, dynamic> toJson() => _$PendingRequestToJson(this);

  PendingRequest copyWith({
    String? id,
    String? endpoint,
    String? method,
    Map<String, dynamic>? payload,
    DateTime? createdAt,
    int? retryCount,
  }) {
    return PendingRequest(
      id: id ?? this.id,
      endpoint: endpoint ?? this.endpoint,
      method: method ?? this.method,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
    );
  }
}
