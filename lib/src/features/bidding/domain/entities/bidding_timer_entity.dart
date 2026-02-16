import 'package:freezed_annotation/freezed_annotation.dart';

part 'bidding_timer_entity.freezed.dart';

@freezed
class BiddingTimerEntity with _$BiddingTimerEntity {
  const factory BiddingTimerEntity({
    required String id,
    required String jobId,
    required DateTime startedAt,
    required DateTime endsAt,
    required int durationMinutes,
    required int extendedByMinutes,
    DateTime? extendedAt,
    required TimerStatus status,
  }) = _BiddingTimerEntity;

  const BiddingTimerEntity._();

  bool get isRunning => status == TimerStatus.running;
  bool get isExtended => status == TimerStatus.extended;
  bool get isExpired => status == TimerStatus.expired;
  bool get isCompleted => status == TimerStatus.completed;
  bool get canExtend => isRunning && extendedByMinutes == 0;

  Duration get remaining => endsAt.difference(DateTime.now());
  bool get isUrgent => remaining.inMinutes <= 2 && !remaining.isNegative;
  bool get isAlmostDone => remaining.inMinutes <= 5 && !remaining.isNegative;

  double get progress {
    final total = durationMinutes * 60;
    final passed = DateTime.now().difference(startedAt).inSeconds;
    return (passed / total).clamp(0.0, 1.0);
  }

  String get formattedRemaining {
    if (remaining.isNegative) return '00:00';
    final m = remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

enum TimerStatus { running, extended, expired, completed }
