import 'package:flutter_test/flutter_test.dart';
import 'package:kadmat/src/core/utils/technician_summary.dart';

void main() {
  group('TechnicianSummary', () {
    test('prefers title and keeps specialization as secondary label', () {
      final summary = TechnicianSummary.fromMap({
        'id': 'tech-1',
        'full_name': 'أحمد الفني',
        'title': 'خبير صيانة تكييف',
        'service': {'name_ar': 'صيانة تكييف'},
        'address': 'طرابلس - حي الأندلس',
        'rating': 4.8,
        'completed_jobs': 12,
        'profile_image_url': 'https://example.com/avatar.png',
      });

      expect(summary.id, 'tech-1');
      expect(summary.fullName, 'أحمد الفني');
      expect(summary.primaryTitle, 'خبير صيانة تكييف');
      expect(summary.secondaryTitle, 'صيانة تكييف');
      expect(summary.location, 'طرابلس - حي الأندلس');
      expect(summary.completedJobs, 12);
      expect(summary.rating, 4.8);
      expect(summary.profileImageUrl, 'https://example.com/avatar.png');
    });

    test('falls back to specialization when title is missing', () {
      final summary = TechnicianSummary.fromMap({
        'full_name': 'سالم',
        'service': {'name_ar': 'تنظيف'},
        'stats': {'completedJobs': 3},
      });

      expect(summary.primaryTitle, 'تنظيف');
      expect(summary.secondaryTitle, isNull);
      expect(summary.completedJobs, 3);
    });

    test('hides geographic point values from display location', () {
      final summary = TechnicianSummary.fromMap({
        'full_name': 'سالم',
        'location': 'SRID=4326;POINT(13.2 32.8)',
      });

      expect(summary.location, isNull);
    });
  });
}
