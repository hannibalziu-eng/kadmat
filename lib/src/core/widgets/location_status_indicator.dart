import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/location/location_service.dart';
import '../services/presence/presence_service.dart';

class LocationStatusIndicator extends ConsumerWidget {
  final bool isOnline;

  const LocationStatusIndicator({super.key, required this.isOnline});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationAsync = ref.watch(locationStreamProvider);
    final qualityStream = ref.watch(presenceServiceProvider).qualityStream;

    return StreamBuilder<ConnectionQuality>(
      stream: qualityStream,
      initialData: ref.read(presenceServiceProvider).currentQuality,
      builder: (context, snapshot) {
        final quality = snapshot.data ?? ConnectionQuality.good;

        if (!isOnline) {
          return _buildBadge(
            context,
            color: Colors.grey,
            text: 'غير متصل',
            icon: Icons.power_settings_new,
          );
        }

        return locationAsync.when(
          data: (_) {
            if (quality == ConnectionQuality.offline ||
                quality == ConnectionQuality.poor) {
              return _buildBadge(
                context,
                color: Colors.orange,
                text: 'GPS يعمل لكن الاتصال ضعيف',
                icon: Icons.wifi_off_rounded,
              );
            }

            return _buildBadge(
              context,
              color: Colors.green,
              text: 'GPS نشط',
              icon: Icons.gps_fixed_rounded,
            );
          },
          loading: () => _buildBadge(
            context,
            color: Colors.amber,
            text: 'جاري تحديد الموقع',
            icon: Icons.gps_not_fixed_rounded,
          ),
          error: (_, __) => _buildBadge(
            context,
            color: Colors.red,
            text: 'تعذر الوصول إلى GPS',
            icon: Icons.location_off_rounded,
          ),
        );
      },
    );
  }

  Widget _buildBadge(
    BuildContext context, {
    required Color color,
    required String text,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
