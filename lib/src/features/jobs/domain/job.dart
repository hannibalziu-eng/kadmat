import 'package:freezed_annotation/freezed_annotation.dart';

part 'job.freezed.dart';
part 'job.g.dart';

@freezed
class Job with _$Job {
  const factory Job({
    required String id,
    @JsonKey(name: 'customer_id') required String customerId,
    @JsonKey(name: 'service_id') required String serviceId,
    @JsonKey(name: 'technician_id') String? technicianId,
    required String status, // pending, accepted, price_pending, in_progress, completed, cancelled
    required double lat,
    required double lng,
    @JsonKey(name: 'address_text') String? addressText,
    String? description,
    @JsonKey(name: 'initial_price') double? initialPrice,
    @JsonKey(name: 'final_price') double? finalPrice,
    @JsonKey(name: 'technician_price') double? technicianPrice,
    @JsonKey(name: 'price_notes') String? priceNotes,
    @JsonKey(name: 'customer_offer') double? customerOffer,
    @JsonKey(name: 'customer_rating') int? customerRating,
    @JsonKey(name: 'customer_review') String? customerReview,
    @JsonKey(name: 'cancelled_by') String? cancelledBy,
    @JsonKey(name: 'cancel_reason') String? cancelReason,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'completed_at') DateTime? completedAt,
    @JsonKey(name: 'accepted_at') DateTime? acceptedAt,
    @JsonKey(name: 'cancelled_at') DateTime? cancelledAt,
    @JsonKey(name: 'rated_at') DateTime? ratedAt,
    @JsonKey(name: 'price_confirmed_at') DateTime? priceConfirmedAt,
    @JsonKey(name: 'search_radius') int? searchRadius,
    @JsonKey(name: 'search_data') Map<String, dynamic>? searchData,
    @JsonKey(name: 'service')
    Map<String, dynamic>? service, // Nested service object
    @JsonKey(name: 'customer')
    Map<String, dynamic>? customer, // Nested customer object
    @JsonKey(name: 'technician')
    Map<String, dynamic>? technician, // Nested technician object
  }) = _Job;

  factory Job.fromJson(Map<String, dynamic> json) => _$JobFromJson(json);
}

