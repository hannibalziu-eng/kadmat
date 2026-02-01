import 'package:freezed_annotation/freezed_annotation.dart';

part 'service.freezed.dart';
part 'service.g.dart';

@freezed
class Service with _$Service {
  const factory Service({
    required String id,
    required String name,
    String? nameAr,
    required double basePrice,
    double? commissionRate,
    String? iconUrl,
    @Default(true) bool isActive,
  }) = _Service;

  const Service._();

  factory Service.fromJson(Map<String, dynamic> json) =>
      _$ServiceFromJson(json);

  @override
  @JsonKey(name: 'name_ar')
  String? get nameAr => throw UnimplementedError();
  @override
  @JsonKey(name: 'base_price')
  double get basePrice => throw UnimplementedError();
  @override
  @JsonKey(name: 'commission_rate')
  double? get commissionRate => throw UnimplementedError();
  @override
  @JsonKey(name: 'icon_url')
  String? get iconUrl => throw UnimplementedError();
  @override
  @JsonKey(name: 'is_active')
  bool get isActive => throw UnimplementedError();
}
