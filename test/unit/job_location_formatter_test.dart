import 'package:flutter_test/flutter_test.dart';
import 'package:kadmat/src/core/utils/job_location_formatter.dart';

void main() {
  test('formatCoordinates returns stable rounded coordinate text', () {
    expect(
      JobLocationFormatter.formatCoordinates(32.8872091, 13.1913388),
      '32.88721, 13.19134',
    );
  });

  test(
    'distanceAndEtaText falls back when current location is unavailable',
    () {
      expect(
        JobLocationFormatter.distanceAndEtaText(
          currentLat: null,
          currentLng: null,
          jobLat: 32.88721,
          jobLng: 13.19134,
        ),
        'المسافة غير متاحة حالياً',
      );
    },
  );

  test('distanceAndEtaText returns distance and eta for live location', () {
    final result = JobLocationFormatter.distanceAndEtaText(
      currentLat: 32.88721,
      currentLng: 13.19134,
      jobLat: 32.90000,
      jobLng: 13.21000,
    );

    expect(result, contains('المسافة التقريبية:'));
    expect(result, contains('كم'));
    expect(result, contains('دقيقة'));
  });

  test('compactDistanceLabel returns concise kilometer label', () {
    final result = JobLocationFormatter.compactDistanceLabel(
      currentLat: 32.88721,
      currentLng: 13.19134,
      jobLat: 32.90000,
      jobLng: 13.21000,
    );

    expect(result, isNotNull);
    expect(result, contains('كم'));
  });
}
