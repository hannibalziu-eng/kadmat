import 'package:freezed_annotation/freezed_annotation.dart';

part 'bid_entity.freezed.dart';
part 'bid_entity.g.dart';

@freezed
class BidEntity with _$BidEntity {
  const factory BidEntity({
    required String id,
    @JsonKey(name: 'job_id') required String jobId,
    @JsonKey(name: 'technician_id') required String technicianId,
    @JsonKey(readValue: _readTechnicianName) required String technicianName,
    @JsonKey(readValue: _readTechnicianAvatar) String? technicianAvatar,
    @JsonKey(readValue: _readTechnicianRating) required double rating,
    @JsonKey(readValue: _readCompletedJobs) required int completedJobs,
    @JsonKey(readValue: _readIsVerified) required bool isVerified,
    required double amount,
    String? notes,
    @JsonKey(name: 'estimated_duration_minutes') int? estimatedDurationMinutes,
    @JsonKey(name: 'availability_days') List<int>? availabilityDays,
    @JsonKey(name: 'submitted_at') required DateTime submittedAt,
    @Default(BidStatus.pending) BidStatus status,
  }) = _BidEntity;

  const BidEntity._();

  bool get isPending => status == BidStatus.pending;
  bool get isAccepted => status == BidStatus.accepted;
  bool get isRejected => status == BidStatus.rejected;

  String get formattedAmount => '${amount.toStringAsFixed(0)} ريال';

  String? get estimatedDurationText {
    if (estimatedDurationMinutes == null) return null;
    final hours = estimatedDurationMinutes! ~/ 60;
    final minutes = estimatedDurationMinutes! % 60;
    if (hours > 0) return '$hours ساعة${minutes > 0 ? ' $minutes دقيقة' : ''}';
    return '$minutes دقيقة';
  }

  factory BidEntity.fromJson(Map<String, dynamic> json) =>
      _$BidEntityFromJson(json);
}

// Helper functions for reading values from nested 'technician' object
Object? _readTechnicianName(Map<dynamic, dynamic> json, String key) {
  final tech = json['technician'] as Map<String, dynamic>?;
  return tech?['full_name'] ?? 'فني';
}

Object? _readTechnicianAvatar(Map<dynamic, dynamic> json, String key) {
  final tech = json['technician'] as Map<String, dynamic>?;
  return tech?['profile_image_url'];
}

Object? _readTechnicianRating(Map<dynamic, dynamic> json, String key) {
  final tech = json['technician'] as Map<String, dynamic>?;
  return tech?['rating'] ?? 5.0;
}

Object? _readCompletedJobs(Map<dynamic, dynamic> json, String key) {
  final tech = json['technician'] as Map<String, dynamic>?;
  return tech?['completed_jobs'] ?? 0;
}

Object? _readIsVerified(Map<dynamic, dynamic> json, String key) {
  final tech = json['technician'] as Map<String, dynamic>?;
  return tech?['is_verified'] ?? false;
}

enum BidStatus {
  pending,
  accepted,
  rejected,
  expired,
  withdrawn,
  waiting,
  offered,
}
