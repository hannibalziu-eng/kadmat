import 'package:geolocator/geolocator.dart';

class JobLocationFormatter {
  const JobLocationFormatter._();

  static String formatCoordinates(double lat, double lng, {int decimals = 5}) {
    return '${lat.toStringAsFixed(decimals)}, ${lng.toStringAsFixed(decimals)}';
  }

  static String distanceAndEtaText({
    required double? currentLat,
    required double? currentLng,
    required double jobLat,
    required double jobLng,
  }) {
    if (currentLat == null || currentLng == null) {
      return 'المسافة غير متاحة حالياً';
    }

    final meters = Geolocator.distanceBetween(
      currentLat,
      currentLng,
      jobLat,
      jobLng,
    );
    final km = meters / 1000;
    final etaMinutes = ((km / 35) * 60).ceil().clamp(1, 240);

    return 'المسافة التقريبية: ${km.toStringAsFixed(1)} كم (حوالي $etaMinutes دقيقة)';
  }

  static String? compactDistanceLabel({
    required double? currentLat,
    required double? currentLng,
    required double jobLat,
    required double jobLng,
  }) {
    if (currentLat == null || currentLng == null) {
      return null;
    }

    final meters = Geolocator.distanceBetween(
      currentLat,
      currentLng,
      jobLat,
      jobLng,
    );
    if (meters < 1000) {
      return '${meters.round()} م';
    }
    return '${(meters / 1000).toStringAsFixed(1)} كم';
  }
}
