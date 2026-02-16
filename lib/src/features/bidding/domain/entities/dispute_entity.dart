import 'package:freezed_annotation/freezed_annotation.dart';

part 'dispute_entity.freezed.dart';

@freezed
class DisputeEntity with _$DisputeEntity {
  const factory DisputeEntity({
    required String id,
    required String jobId,
    required String raisedBy,
    required String disputeType,
    required String description,
    required List<String> evidencePhotoUrls,
    required DisputeStatus status,
    String? supportNotes,
    String? resolutionNotes, // Added
    String? resolutionType,
    String? resolvedBy,
    DateTime? resolvedAt,
    double? refundAmount,
    double? compensationAmount,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _DisputeEntity;

  const DisputeEntity._();

  bool get isOpen => status == DisputeStatus.open;
  bool get isUnderReview => status == DisputeStatus.underReview;
  bool get isResolved =>
      status == DisputeStatus.resolvedCustomerFavor ||
      status == DisputeStatus.resolvedTechnicianFavor ||
      status == DisputeStatus.compromise;
}

enum DisputeStatus {
  open,
  underReview,
  resolvedCustomerFavor,
  resolvedTechnicianFavor,
  compromise,
  closed,
}
