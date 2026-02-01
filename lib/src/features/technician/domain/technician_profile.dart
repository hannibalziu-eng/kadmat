class TechnicianProfile {
  final String id;
  final String fullName;
  final String? profileImageUrl;
  final double rating;
  final DateTime createdAt;
  final ProfileStats stats;
  final List<PortfolioItem> portfolio;
  final List<Review> reviews;

  TechnicianProfile({
    required this.id,
    required this.fullName,
    this.profileImageUrl,
    required this.rating,
    required this.createdAt,
    required this.stats,
    required this.portfolio,
    required this.reviews,
  });

  factory TechnicianProfile.fromJson(Map<String, dynamic> json) {
    return TechnicianProfile(
      id: json['id'],
      fullName: json['full_name'],
      profileImageUrl: json['profile_image_url'],
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      createdAt: DateTime.parse(json['created_at']),
      stats: ProfileStats.fromJson(json['stats'] ?? {}),
      portfolio:
          (json['portfolio'] as List?)
              ?.map((e) => PortfolioItem.fromJson(e))
              .toList() ??
          [],
      reviews:
          (json['reviews'] as List?)?.map((e) => Review.fromJson(e)).toList() ??
          [],
    );
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
      completedJobs: json['completedJobs'] ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      totalReviews: json['totalReviews'] ?? 0,
    );
  }
}

class PortfolioItem {
  final String id;
  final String imageUrl;
  final String? description;
  final DateTime? projectDate;

  PortfolioItem({
    required this.id,
    required this.imageUrl,
    this.description,
    this.projectDate,
  });

  factory PortfolioItem.fromJson(Map<String, dynamic> json) {
    return PortfolioItem(
      id: json['id'],
      imageUrl: json['image_url'],
      description: json['description'],
      projectDate: json['project_date'] != null
          ? DateTime.parse(json['project_date'])
          : null,
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
    final reviewer = json['reviewer'] ?? {};
    return Review(
      id: json['id'],
      rating: json['rating'] ?? 5,
      comment: json['comment'],
      createdAt: DateTime.parse(json['created_at']),
      reviewerName: reviewer['full_name'] ?? 'Google Customer',
      reviewerImage: reviewer['profile_image_url'],
    );
  }
}
