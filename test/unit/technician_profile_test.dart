import 'package:flutter_test/flutter_test.dart';
import 'package:kadmat/src/features/technician/domain/technician_profile.dart';

void main() {
  group('TechnicianProfile', () {
    test('fromJson should parse correctly with specialization', () {
      final json = {
        'id': 'tech_123',
        'full_name': 'Ahmed Ali',
        'profile_image_url': 'https://example.com/image.jpg',
        'specialization': 'Plumber',
        'rating': 4.5,
        'created_at': '2023-01-01T10:00:00Z',
        'stats': {'completedJobs': 10, 'rating': 4.5, 'totalReviews': 5},
        'portfolio': [],
        'reviews': [],
      };

      final profile = TechnicianProfile.fromJson(json);

      expect(profile.id, 'tech_123');
      expect(profile.fullName, 'Ahmed Ali');
      expect(profile.specialization, 'Plumber');
      expect(profile.stats.completedJobs, 10);
    });

    test('fromJson should handle missing specialization', () {
      final json = {
        'id': 'tech_123',
        'full_name': 'Ahmed Ali',
        'rating': 4.5,
        'created_at': '2023-01-01T10:00:00Z',
        'stats': {},
        'portfolio': [],
        'reviews': [],
      };

      final profile = TechnicianProfile.fromJson(json);

      expect(profile.specialization, null);
    });
  });
}
