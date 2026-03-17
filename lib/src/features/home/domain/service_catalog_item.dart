class ServiceCatalogItem {
  final String id;
  final String serviceId;
  final String name;
  final String? nameAr;
  final String? description;
  final String? descriptionAr;
  final double price;
  final String currencyCode;
  final int sortOrder;
  final bool isActive;
  final Map<String, dynamic> itemConfig;

  const ServiceCatalogItem({
    required this.id,
    required this.serviceId,
    required this.name,
    this.nameAr,
    this.description,
    this.descriptionAr,
    required this.price,
    this.currencyCode = 'LYD',
    this.sortOrder = 0,
    this.isActive = true,
    this.itemConfig = const {},
  });

  factory ServiceCatalogItem.fromJson(Map<String, dynamic> json) {
    double parsePrice(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0.0;
    }

    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
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

    Map<String, dynamic> parseMap(dynamic value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) {
        return value.map((key, value) => MapEntry(key.toString(), value));
      }
      return <String, dynamic>{};
    }

    return ServiceCatalogItem(
      id: json['id']?.toString() ?? '',
      serviceId: json['service_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      nameAr: json['name_ar']?.toString(),
      description: json['description']?.toString(),
      descriptionAr: json['description_ar']?.toString(),
      price: parsePrice(json['price']),
      currencyCode: json['currency_code']?.toString() ?? 'LYD',
      sortOrder: parseInt(json['sort_order']),
      isActive: parseBool(json['is_active'], fallback: true),
      itemConfig: parseMap(json['item_config']),
    );
  }
}
