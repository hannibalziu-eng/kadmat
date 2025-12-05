import 'package:freezed_annotation/freezed_annotation.dart';

part 'service.freezed.dart';
part 'service.g.dart';

@freezed
class Service with _$Service {
  const factory Service({
    required String id,
    required String name,
    @JsonKey(name: 'name_ar') String? nameAr,
    @JsonKey(name: 'base_price') required double basePrice,
    @JsonKey(name: 'commission_rate') double? commissionRate,
    @JsonKey(name: 'icon_url') String? iconUrl,
    @JsonKey(name: 'is_active') @Default(true) bool isActive,
  }) = _Service;

  factory Service.fromJson(Map<String, dynamic> json) => _$ServiceFromJson(json);
}
