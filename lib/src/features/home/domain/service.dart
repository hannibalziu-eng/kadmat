class Service {
  final String id;
  final String name;
  final String? nameAr;
  final double? basePrice;
  final double? commissionRate;
  final String? iconUrl;
  final bool isActive;
  final String pricingModeDefault;
  final String dispatchModeDefault;
  final bool isCatalogEnabled;
  final bool requiresQuote;
  final Map<String, dynamic> serviceConfig;

  const Service({
    required this.id,
    required this.name,
    this.nameAr,
    this.basePrice,
    this.commissionRate,
    this.iconUrl,
    required this.isActive,
    this.pricingModeDefault = 'technician_quote',
    this.dispatchModeDefault = 'manual_quote',
    this.isCatalogEnabled = false,
    this.requiresQuote = true,
    this.serviceConfig = const {},
  });

  factory Service.fromJson(Map<String, dynamic> json) {
    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    Map<String, dynamic> parseMap(dynamic value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) {
        return value.map((key, value) => MapEntry(key.toString(), value));
      }
      return <String, dynamic>{};
    }

    bool parseBool(dynamic value, {required bool fallback}) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        if (normalized == 'true' || normalized == '1') return true;
        if (normalized == 'false' || normalized == '0') return false;
      }
      return fallback;
    }

    return Service(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      nameAr: json['name_ar']?.toString(),
      basePrice: parseDouble(json['base_price']),
      commissionRate: parseDouble(json['commission_rate']),
      iconUrl: json['icon_url']?.toString(),
      isActive: parseBool(json['is_active'], fallback: true),
      pricingModeDefault: json['pricing_mode_default']?.toString() ?? 'technician_quote',
      dispatchModeDefault: json['dispatch_mode_default']?.toString() ?? 'manual_quote',
      isCatalogEnabled: parseBool(json['is_catalog_enabled'], fallback: false),
      requiresQuote: parseBool(json['requires_quote'], fallback: true),
      serviceConfig: parseMap(json['service_config']),
    );
  }
}
