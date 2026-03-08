class TechnicianProfile {
  final String id;
  final String fullName;
  final String? profileImageUrl;
  final String? specialization;
  final String? title; // Added
  final String? bio; // Added
  final String? location; // Added
  final double rating;
  final DateTime createdAt;
  final ProfileStats stats;
  final List<PortfolioItem> portfolio;
  final List<Review> reviews;

  TechnicianProfile({
    required this.id,
    required this.fullName,
    this.profileImageUrl,
    this.specialization,
    this.title,
    this.bio,
    this.location,
    required this.rating,
    required this.createdAt,
    required this.stats,
    required this.portfolio,
    required this.reviews,
  });

  factory TechnicianProfile.fromJson(Map<String, dynamic> json) {
    final createdAt =
        DateTime.tryParse((json['created_at'] ?? '').toString()) ??
        DateTime.now();

    final rawPortfolio = (json['portfolio'] as List?) ?? const [];
    final portfolioItems = rawPortfolio
        .whereType<Map>()
        .map((e) => PortfolioItem.fromJson(Map<String, dynamic>.from(e)))
        .where((item) => item.imageUrl.isNotEmpty)
        .toList();

    final rawReviews = (json['reviews'] as List?) ?? const [];
    final reviewItems = rawReviews
        .whereType<Map>()
        .map((e) => Review.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return TechnicianProfile(
      id: (json['id'] ?? '').toString(),
      fullName: (json['full_name'] ?? 'فني').toString(),
      profileImageUrl: _validUrlOrNull(json['profile_image_url']),
      specialization: (json['specialization'] as String?)?.trim(),
      title: (json['title'] as String?)?.trim(), // Added
      bio: (json['bio'] as String?)?.trim(), // Added
      location: _displayLocation(json['location']),
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      createdAt: createdAt,
      stats: ProfileStats.fromJson(
        Map<String, dynamic>.from(json['stats'] ?? {}),
      ),
      portfolio: portfolioItems,
      reviews: reviewItems,
    );
  }

  static String? _validUrlOrNull(Object? value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) return null;
    return raw;
  }

  static String? _displayLocation(Object? value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) return null;
    final normalized = raw.toUpperCase();
    if (normalized.contains('POINT(') || normalized.contains('SRID=')) {
      return null;
    }
    return raw;
  }
}

class ProfileStats {
  final int completedJobs;
  final double rating;
  final int totalReviews;

  ProfileStats({
    required this.completedJobs,
    required this.rating,
    required this.totalReviews,
  });

  factory ProfileStats.fromJson(Map<String, dynamic> json) {
    return ProfileStats(
      completedJobs:
          (json['completedJobs'] as num?)?.toInt() ??
          (json['completed_jobs'] as num?)?.toInt() ??
          0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      totalReviews:
          (json['totalReviews'] as num?)?.toInt() ??
          (json['total_reviews'] as num?)?.toInt() ??
          0,
    );
  }
}

class PortfolioItem {
  static const _legacyTitlePrefix = '__TITLE__:';
  final String id;
  final String imageUrl;
  final String? title; // Added
  final String? description;
  final DateTime? projectDate;

  PortfolioItem({
    required this.id,
    required this.imageUrl,
    this.title, // Added
    this.description,
    this.projectDate,
  });

  factory PortfolioItem.fromJson(Map<String, dynamic> json) {
    final projectDateRaw = json['project_date']?.toString();
    final normalized = _normalizeLegacyFields(
      title: (json['title'] as String?)?.trim(),
      description: (json['description'] as String?)?.trim(),
    );
    return PortfolioItem(
      id: (json['id'] ?? '').toString(),
      imageUrl: (json['image_url'] ?? '').toString(),
      title: normalized.title,
      description: normalized.description,
      projectDate: projectDateRaw == null
          ? null
          : DateTime.tryParse(projectDateRaw),
    );
  }

  static ({String? title, String? description}) _normalizeLegacyFields({
    String? title,
    String? description,
  }) {
    if (title != null && title.isNotEmpty) {
      return (title: title, description: description);
    }
    if (description == null || !description.startsWith(_legacyTitlePrefix)) {
      return (title: title, description: description);
    }

    final body = description.substring(_legacyTitlePrefix.length);
    final lines = body.split('\n');
    final legacyTitle = lines.first.trim();
    final legacyDescription = lines.skip(1).join('\n').trim();
    return (
      title: legacyTitle.isEmpty ? null : legacyTitle,
      description: legacyDescription.isEmpty ? null : legacyDescription,
    );
  }
}

class Review {
  final String id;
  final int rating;
  final String? comment;
  final DateTime createdAt;
  final String reviewerName;
  final String? reviewerImage;

  Review({
    required this.id,
    required this.rating,
    this.comment,
    required this.createdAt,
    required this.reviewerName,
    this.reviewerImage,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    final reviewer = Map<String, dynamic>.from(
      (json['reviewer'] as Map?) ?? const {},
    );
    final createdAt =
        DateTime.tryParse((json['created_at'] ?? '').toString()) ??
        DateTime.now();
    return Review(
      id: (json['id'] ?? '').toString(),
      rating: (json['rating'] as num?)?.toInt() ?? 5,
      comment: (json['comment'] as String?)?.trim(),
      createdAt: createdAt,
      reviewerName: (reviewer['full_name'] ?? 'عميل').toString(),
      reviewerImage: TechnicianProfile._validUrlOrNull(
        reviewer['profile_image_url'],
      ),
    );
  }
}
