import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/dispute_entity.dart';

part 'dispute_model.freezed.dart';
part 'dispute_model.g.dart';

@freezed
class DisputeModel with _$DisputeModel {
  const factory DisputeModel({
    required String id,
    @JsonKey(name: 'job_id') required String jobId,
    @JsonKey(name: 'raised_by') required String raisedBy,
    @JsonKey(name: 'dispute_type') required String disputeType,
    required String description,
    @JsonKey(name: 'evidence_photo_urls') List<String>? evidencePhotoUrls,
    @Default('open') String status,
    @JsonKey(name: 'support_notes') String? supportNotes,
    @JsonKey(name: 'resolution_type') String? resolutionType,
    @JsonKey(name: 'resolved_by') String? resolvedBy,
    @JsonKey(name: 'resolved_at') DateTime? resolvedAt,
    @JsonKey(name: 'refund_amount') double? refundAmount,
    @JsonKey(name: 'compensation_amount') double? compensationAmount,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') required DateTime updatedAt,
  }) = _DisputeModel;

  factory DisputeModel.fromJson(Map<String, dynamic> json) =>
      _$DisputeModelFromJson(json);
}

extension DisputeModelX on DisputeModel {
  DisputeEntity toEntity() => DisputeEntity(
    id: id,
    jobId: jobId,
    raisedBy: raisedBy,
    disputeType: disputeType,
    description: description,
    evidencePhotoUrls: evidencePhotoUrls ?? [],
    status: DisputeStatus.values.byName(status),
    supportNotes: supportNotes,
    resolutionType: resolutionType,
    resolvedBy: resolvedBy,
    resolvedAt: resolvedAt,
    refundAmount: refundAmount,
    compensationAmount: compensationAmount,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
