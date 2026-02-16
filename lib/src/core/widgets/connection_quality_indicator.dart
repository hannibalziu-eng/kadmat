import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/presence/presence_service.dart';

class ConnectionQualityIndicator extends ConsumerWidget {
  const ConnectionQualityIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qualityStream = ref.watch(presenceServiceProvider).qualityStream;

    return StreamBuilder<ConnectionQuality>(
      stream: qualityStream,
      initialData: ConnectionQuality.good,
      builder: (context, snapshot) {
        final quality = snapshot.data ?? ConnectionQuality.good;
        return Tooltip(
          message: _getQualityText(quality),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              _getQualityIcon(quality),
              color: _getQualityColor(quality),
              size: 16,
            ),
          ),
        );
      },
    );
  }

  IconData _getQualityIcon(ConnectionQuality quality) {
    switch (quality) {
      case ConnectionQuality.good:
        return Icons.signal_wifi_4_bar;
      case ConnectionQuality.moderate:
        return Icons.network_wifi_3_bar;
      case ConnectionQuality.poor:
        return Icons.signal_wifi_bad;
      case ConnectionQuality.offline:
        return Icons.signal_wifi_off;
    }
  }

  Color _getQualityColor(ConnectionQuality quality) {
    switch (quality) {
      case ConnectionQuality.good:
        return Colors.green;
      case ConnectionQuality.moderate:
        return Colors.orange;
      case ConnectionQuality.poor:
        return Colors.red;
      case ConnectionQuality.offline:
        return Colors.grey;
    }
  }

  String _getQualityText(ConnectionQuality quality) {
    switch (quality) {
      case ConnectionQuality.good:
        return 'اتصال ممتاز';
      case ConnectionQuality.moderate:
        return 'اتصال متوسط';
      case ConnectionQuality.poor:
        return 'اتصال ضعيف';
      case ConnectionQuality.offline:
        return 'غير متصل';
    }
  }
}
