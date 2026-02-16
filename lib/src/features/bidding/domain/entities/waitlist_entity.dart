import 'package:freezed_annotation/freezed_annotation.dart';

part 'waitlist_entity.freezed.dart';

@freezed
class WaitlistEntity with _$WaitlistEntity {
  const factory WaitlistEntity({
    required String id,
    required String jobId,
    required String bidId,
    required String technicianId,
    required double amount,
    required int rank,
    required WaitlistStatus status,
    DateTime? offeredAt,
    DateTime? expiresAt,
  }) = _WaitlistEntity;

  const WaitlistEntity._();

  bool get isWaiting => status == WaitlistStatus.waiting;
  bool get isOffered => status == WaitlistStatus.offered;
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
  bool get isAccepted => status == WaitlistStatus.accepted;
  bool get isDeclined => status == WaitlistStatus.declined;

  Duration? get timeRemaining {
    if (expiresAt == null) return null;
    return expiresAt!.difference(DateTime.now());
  }
}

enum WaitlistStatus { waiting, offered, accepted, expired, declined }
