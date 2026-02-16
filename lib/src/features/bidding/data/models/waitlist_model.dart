import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/waitlist_entity.dart';

part 'waitlist_model.freezed.dart';
part 'waitlist_model.g.dart';

@freezed
class WaitlistModel with _$WaitlistModel {
  const factory WaitlistModel({
    required String id,
    @JsonKey(name: 'job_id') required String jobId,
    @JsonKey(name: 'bid_id') required String bidId,
    @JsonKey(name: 'technician_id') required String technicianId,
    required double amount,
    required int rank,
    @Default('waiting') String status,
    @JsonKey(name: 'offered_at') DateTime? offeredAt,
    @JsonKey(name: 'expires_at') DateTime? expiresAt,
  }) = _WaitlistModel;

  factory WaitlistModel.fromJson(Map<String, dynamic> json) =>
      _$WaitlistModelFromJson(json);
}

extension WaitlistModelX on WaitlistModel {
  WaitlistEntity toEntity() => WaitlistEntity(
    id: id,
    jobId: jobId,
    bidId: bidId,
    technicianId: technicianId,
    amount: amount,
    rank: rank,
    status: WaitlistStatus.values.byName(status),
    offeredAt: offeredAt,
    expiresAt: expiresAt,
  );
}
