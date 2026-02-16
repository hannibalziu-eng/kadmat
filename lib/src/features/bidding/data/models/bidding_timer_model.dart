import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/bidding_timer_entity.dart';

part 'bidding_timer_model.freezed.dart';
part 'bidding_timer_model.g.dart';

@freezed
class BiddingTimerModel with _$BiddingTimerModel {
  const factory BiddingTimerModel({
    required String id,
    @JsonKey(name: 'job_id') required String jobId,
    @JsonKey(name: 'started_at') required DateTime startedAt,
    @JsonKey(name: 'ends_at') required DateTime endsAt,
    @JsonKey(name: 'duration_minutes') @Default(15) int durationMinutes,
    @JsonKey(name: 'extended_by_minutes') @Default(0) int extendedByMinutes,
    @JsonKey(name: 'extended_at') DateTime? extendedAt,
    @Default('running') String status,
  }) = _BiddingTimerModel;

  factory BiddingTimerModel.fromJson(Map<String, dynamic> json) =>
      _$BiddingTimerModelFromJson(json);
}

extension BiddingTimerModelX on BiddingTimerModel {
  BiddingTimerEntity toEntity() => BiddingTimerEntity(
    id: id,
    jobId: jobId,
    startedAt: startedAt,
    endsAt: endsAt,
    durationMinutes: durationMinutes,
    extendedByMinutes: extendedByMinutes,
    extendedAt: extendedAt,
    status: TimerStatus.values.byName(status),
  );
}
