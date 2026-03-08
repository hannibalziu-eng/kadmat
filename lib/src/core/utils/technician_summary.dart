import 'service_name_formatter.dart';

class TechnicianSummary {
  final String id;
  final String fullName;
  final String? profileImageUrl;
  final double rating;
  final int completedJobs;
  final String primaryTitle;
  final String? secondaryTitle;
  final String? location;

  const TechnicianSummary({
    required this.id,
    required this.fullName,
    required this.profileImageUrl,
    required this.rating,
    required this.completedJobs,
    required this.primaryTitle,
    required this.secondaryTitle,
    required this.location,
  });

  factory TechnicianSummary.fromMap(
    Map<String, dynamic>? raw, {
    String fallbackName = 'فني',
    String fallbackTitle = 'فني خدمات عامة',
  }) {
    final map = raw == null
        ? const <String, dynamic>{}
        : Map<String, dynamic>.from(raw);
    final title = _stringOrNull(map['title']);
    final specialization =
        _stringOrNull(map['specialization']) ??
        formatServiceDisplayName(map['service'], fallback: fallbackTitle);
    final primaryTitle = title ?? specialization;
    final secondaryTitle =
        title != null && specialization.isNotEmpty && specialization != title
        ? specialization
        : null;

    return TechnicianSummary(
      id: _stringOrNull(map['id']) ?? '',
      fullName: _stringOrNull(map['full_name']) ?? fallbackName,
      profileImageUrl: _validUrlOrNull(
        map['profile_image_url'] ?? map['avatar_url'],
      ),
      rating: (map['rating'] as num?)?.toDouble() ?? 5.0,
      completedJobs: _readCompletedJobs(map),
      primaryTitle: primaryTitle,
      secondaryTitle: secondaryTitle,
      location: _readDisplayLocation(map),
    );
  }

  static int _readCompletedJobs(Map<String, dynamic> map) {
    final directValue = map['completed_jobs'] ?? map['completedJobs'];
    if (directValue is num) {
      return directValue.toInt();
    }

    final stats = map['stats'];
    if (stats is Map) {
      final completed = stats['completed_jobs'] ?? stats['completedJobs'];
      if (completed is num) {
        return completed.toInt();
      }
    }

    return 0;
  }

  static String? _readDisplayLocation(Map<String, dynamic> map) {
    final direct = _stringOrNull(map['location']);
    if (_isDisplayLocation(direct)) {
      return direct;
    }

    final address = _stringOrNull(map['address']);
    if (_isDisplayLocation(address)) {
      return address;
    }

    return null;
  }

  static bool _isDisplayLocation(String? value) {
    if (value == null || value.isEmpty) {
      return false;
    }
    final normalized = value.toUpperCase();
    return !(normalized.contains('POINT(') || normalized.contains('SRID='));
  }

  static String? _stringOrNull(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    return text;
  }

  static String? _validUrlOrNull(Object? value) {
    final raw = _stringOrNull(value);
    if (raw == null) {
      return null;
    }
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return null;
    }
    return raw;
  }
}
