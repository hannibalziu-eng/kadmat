import 'package:freezed_annotation/freezed_annotation.dart';
import '../../bidding/domain/entities/bid_entity.dart';

part 'job.freezed.dart';
part 'job.g.dart';

@freezed
class Job with _$Job {
  const factory Job({
    required String id,
    required String customerId,
    required String serviceId,
    String? technicianId,
    required String
    status, // pending, accepted, price_pending, in_progress, completed, cancelled
    required double lat,
    required double lng,
    String? addressText,
    String? description,
    double? initialPrice,
    double? finalPrice,
    double? technicianPrice,
    String? priceNotes,
    double? customerOffer,
    double? customerRating,
    String? customerReview,
    String? cancelledBy,
    String? cancelReason,
    required DateTime createdAt,
    DateTime? completedAt,
    DateTime? acceptedAt,
    DateTime? cancelledAt,
    DateTime? ratedAt,
    DateTime? priceConfirmedAt,
    int? searchRadius,
    Map<String, dynamic>? searchData,
    Map<String, dynamic>? service,
    Map<String, dynamic>? customer,
    Map<String, dynamic>? technician,
    List<String>? afterPhotos,
    String? workNotes,
    DateTime? paymentDate,
    String? paymentMethod,
    double? techRating,
    String? techReview,
    List<JobImage>? images,
    Map<String, dynamic>? permissions,
    Map<String, dynamic>? timeline,
    Map<String, dynamic>? priceSummary,
    // Bidding System Fields
    @JsonKey(name: 'bidding_status') @Default('open') String biddingStatus,
    @JsonKey(name: 'current_wave') @Default(1) int currentWave,
    @JsonKey(name: 'confirmation_code') String? confirmationCode,
    @JsonKey(name: 'is_paid') @Default(false) bool isPaid,
    @JsonKey(name: 'additional_cost') @Default(0.0) double additionalCost,
    @JsonKey(name: 'accepted_bid_id') String? acceptedBidId,
    @JsonKey(name: 'proposed_price') double? proposedPrice,
    @JsonKey(name: 'paid_at') DateTime? paidAt,
    List<BidEntity>? bids,
  }) = _Job;

  const Job._();

  factory Job.fromJson(Map<String, dynamic> json) => _$JobFromJson(json);

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, dynamic val) => MapEntry(key.toString(), val));
    }
    return null;
  }

  static List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map(
          (entry) =>
              entry.map((key, dynamic val) => MapEntry(key.toString(), val)),
        )
        .toList(growable: false);
  }

  static List<Map<String, dynamic>> _firstNonEmptyMapList(
    List<dynamic> values,
  ) {
    for (final value in values) {
      final list = _asMapList(value);
      if (list.isNotEmpty) return list;
    }
    return const [];
  }

  static double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static bool? _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true') return true;
      if (normalized == 'false') return false;
    }
    return null;
  }

  Map<String, dynamic>? get pricingContextData =>
      _asMap(priceSummary?['pricingContext']) ??
      _asMap(priceSummary?['pricing_context']);

  String get effectivePricingMode {
    final rawValue =
        pricingContextData?['pricingMode'] ??
        pricingContextData?['pricing_mode'] ??
        priceSummary?['pricingMode'] ??
        priceSummary?['pricing_mode'];
    final normalized = rawValue?.toString().trim();
    if (normalized == null || normalized.isEmpty) {
      return 'technician_quote';
    }
    return normalized;
  }

  bool get isCatalogFixed => effectivePricingMode == 'catalog_fixed';

  String? get effectiveDispatchMode {
    final rawValue =
        pricingContextData?['dispatchMode'] ??
        pricingContextData?['dispatch_mode'] ??
        priceSummary?['dispatchMode'] ??
        priceSummary?['dispatch_mode'];
    final normalized = rawValue?.toString().trim();
    if (normalized == null || normalized.isEmpty) return null;
    return normalized;
  }

  bool get effectiveQuoteRequired =>
      _asBool(
        pricingContextData?['quoteRequired'] ??
            pricingContextData?['quote_required'] ??
            priceSummary?['quoteRequired'] ??
            priceSummary?['quote_required'],
      ) ??
      true;

  double? get effectiveCatalogSubtotal => _asDouble(
    pricingContextData?['catalogSubtotal'] ??
        pricingContextData?['catalog_subtotal'] ??
        priceSummary?['catalogSubtotal'] ??
        priceSummary?['catalog_subtotal'],
  );

  int get effectiveCatalogItemCount =>
      _asInt(
        pricingContextData?['catalogItemCount'] ??
            pricingContextData?['catalog_item_count'] ??
            priceSummary?['catalogItemCount'] ??
            priceSummary?['catalog_item_count'],
      ) ??
      effectiveJobCatalogItems.length;

  Map<String, dynamic>? get effectivePricingSummary =>
      _asMap(pricingContextData?['pricingSummary']) ??
      _asMap(pricingContextData?['pricing_summary']) ??
      _asMap(priceSummary?['pricingSummary']) ??
      _asMap(priceSummary?['pricing_summary']);

  List<Map<String, dynamic>> get effectiveJobCatalogItems =>
      _firstNonEmptyMapList([
        pricingContextData?['jobCatalogItems'],
        pricingContextData?['job_catalog_items'],
        priceSummary?['jobCatalogItems'],
        priceSummary?['job_catalog_items'],
      ]);

  double get effectiveRuntimePrice =>
      finalPrice ??
      technicianPrice ??
      effectiveCatalogSubtotal ??
      initialPrice ??
      0;

  bool get canSetPrice => permissions?['canSetPrice'] == true;

  bool get canConfirmPrice => permissions?['canConfirmPrice'] == true;

  bool get canStartTravel => permissions?['canStartTravel'] == true;

  bool get canAcceptDirectly => permissions?['canAccept'] == true;

  @override
  @JsonKey(name: 'customer_id')
  String get customerId => throw UnimplementedError();
  @override
  @JsonKey(name: 'service_id')
  String get serviceId => throw UnimplementedError();
  @override
  @JsonKey(name: 'technician_id')
  String? get technicianId => throw UnimplementedError();
  @override
  @JsonKey(name: 'address_text')
  String? get addressText => throw UnimplementedError();
  @override
  @JsonKey(name: 'initial_price')
  double? get initialPrice => throw UnimplementedError();
  @override
  @JsonKey(name: 'final_price')
  double? get finalPrice => throw UnimplementedError();
  @override
  @JsonKey(name: 'technician_price')
  double? get technicianPrice => throw UnimplementedError();
  @override
  @JsonKey(name: 'price_notes')
  String? get priceNotes => throw UnimplementedError();
  @override
  @JsonKey(name: 'customer_offer')
  double? get customerOffer => throw UnimplementedError();
  @override
  @JsonKey(name: 'customer_rating')
  double? get customerRating => throw UnimplementedError();
  @override
  @JsonKey(name: 'customer_review')
  String? get customerReview => throw UnimplementedError();
  @override
  @JsonKey(name: 'cancelled_by')
  String? get cancelledBy => throw UnimplementedError();
  @override
  @JsonKey(name: 'cancel_reason')
  String? get cancelReason => throw UnimplementedError();
  @override
  @JsonKey(name: 'created_at')
  DateTime get createdAt => throw UnimplementedError();
  @override
  @JsonKey(name: 'completed_at')
  DateTime? get completedAt => throw UnimplementedError();
  @override
  @JsonKey(name: 'accepted_at')
  DateTime? get acceptedAt => throw UnimplementedError();
  @override
  @JsonKey(name: 'cancelled_at')
  DateTime? get cancelledAt => throw UnimplementedError();
  @override
  @JsonKey(name: 'rated_at')
  DateTime? get ratedAt => throw UnimplementedError();
  @override
  @JsonKey(name: 'price_confirmed_at')
  DateTime? get priceConfirmedAt => throw UnimplementedError();
  @override
  @JsonKey(name: 'search_radius')
  int? get searchRadius => throw UnimplementedError();
  @override
  @JsonKey(name: 'search_data')
  Map<String, dynamic>? get searchData => throw UnimplementedError();
  @override
  @JsonKey(name: 'service')
  Map<String, dynamic>? get service => throw UnimplementedError();
  @override
  @JsonKey(name: 'customer')
  Map<String, dynamic>? get customer => throw UnimplementedError();
  @override
  @JsonKey(name: 'technician')
  Map<String, dynamic>? get technician => throw UnimplementedError();
  @override
  @JsonKey(name: 'after_photos')
  List<String>? get afterPhotos => throw UnimplementedError();
  @override
  @JsonKey(name: 'work_notes')
  String? get workNotes => throw UnimplementedError();
  @override
  @JsonKey(name: 'payment_date')
  DateTime? get paymentDate => throw UnimplementedError();
  @override
  @JsonKey(name: 'payment_method')
  String? get paymentMethod => throw UnimplementedError();
  @override
  @JsonKey(name: 'tech_rating')
  double? get techRating => throw UnimplementedError();
  @override
  @JsonKey(name: 'tech_review')
  String? get techReview => throw UnimplementedError();
  @override
  @JsonKey(name: 'job_images')
  List<JobImage>? get images => throw UnimplementedError();
  @override
  @JsonKey(name: 'priceSummary')
  Map<String, dynamic>? get priceSummary => throw UnimplementedError();
  @override
  List<BidEntity>? get bids => throw UnimplementedError();
}

@freezed
class JobImage with _$JobImage {
  const factory JobImage({
    required String id,
    required String imageUrl,
    String? mediaType,
  }) = _JobImage;

  const JobImage._();

  factory JobImage.fromJson(Map<String, dynamic> json) =>
      _$JobImageFromJson(json);

  @override
  @JsonKey(name: 'image_url')
  String get imageUrl => throw UnimplementedError();
  @override
  @JsonKey(name: 'media_type')
  String? get mediaType => throw UnimplementedError();
}
