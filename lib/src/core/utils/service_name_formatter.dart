const Map<String, String> _knownServiceNamesAr = {
  'electrical_repair': 'إصلاح كهربائي',
  'plumbing_repair': 'إصلاح سباكة',
  'ac_maintenance': 'صيانة تكييف',
  'carpentry': 'نجارة',
  'painting': 'صباغة',
  'cleaning': 'تنظيف',
  'appliance_repair': 'تصليح أجهزة',
};

String formatServiceDisplayName(
  Object? serviceOrName, {
  String fallback = 'خدمة',
}) {
  if (serviceOrName is Map) {
    final map = Map<String, dynamic>.from(serviceOrName);
    final localizedName = _firstNonEmpty([
      map['name_ar'],
      map['nameAr'],
      map['display_name_ar'],
      map['displayNameAr'],
    ]);
    if (localizedName != null) {
      return localizedName;
    }

    return formatServiceSlug(
      _firstNonEmpty([
        map['name'],
        map['slug'],
        map['service_name'],
        map['serviceName'],
      ]),
      fallback: fallback,
    );
  }

  if (serviceOrName is String) {
    return formatServiceSlug(serviceOrName, fallback: fallback);
  }

  return fallback;
}

String formatServiceSlug(String? rawName, {String fallback = 'خدمة'}) {
  final normalized = rawName?.trim();
  if (normalized == null || normalized.isEmpty) {
    return fallback;
  }

  final localized = _knownServiceNamesAr[normalized.toLowerCase()];
  if (localized != null) {
    return localized;
  }

  if (RegExp(r'^[a-z0-9_ -]+$').hasMatch(normalized)) {
    return normalized
        .split(RegExp(r'[_\s-]+'))
        .where((segment) => segment.isNotEmpty)
        .map(_capitalizeWord)
        .join(' ');
  }

  return normalized;
}

String? _firstNonEmpty(List<Object?> values) {
  for (final value in values) {
    final text = value?.toString().trim();
    if (text != null && text.isNotEmpty) {
      return text;
    }
  }
  return null;
}

String _capitalizeWord(String value) {
  if (value.isEmpty) {
    return value;
  }
  return value[0].toUpperCase() + value.substring(1).toLowerCase();
}
