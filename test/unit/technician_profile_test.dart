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
        'title': 'Master Plumber',
        'bio': '15 years of experience',
        'location': 'Tripoli',
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
      expect(profile.title, 'Master Plumber');
      expect(profile.bio, '15 years of experience');
      expect(profile.location, 'Tripoli');
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

    test('fromJson hides geometry-like location values', () {
      final json = {
        'id': 'tech_123',
        'full_name': 'Ahmed Ali',
        'location': 'SRID=4326;POINT(13.2 32.8)',
        'created_at': '2023-01-01T10:00:00Z',
        'stats': {},
        'portfolio': [],
        'reviews': [],
      };

      final profile = TechnicianProfile.fromJson(json);

      expect(profile.location, isNull);
    });

    test('portfolio item restores title from legacy encoded description', () {
      final profile = TechnicianProfile.fromJson({
        'id': 'tech_123',
        'full_name': 'Ahmed Ali',
        'created_at': '2023-01-01T10:00:00Z',
        'stats': {},
        'portfolio': [
          {
            'id': 'work-1',
            'image_url': 'https://example.com/work.jpg',
            'description':
                '__TITLE__:تنظيف الوحدة الخارجية\nتنظيف شامل مع تبديل فلاتر',
          },
        ],
        'reviews': [],
      });

      expect(profile.portfolio, hasLength(1));
      expect(profile.portfolio.first.title, 'تنظيف الوحدة الخارجية');
      expect(profile.portfolio.first.description, 'تنظيف شامل مع تبديل فلاتر');
    });
  });
}
