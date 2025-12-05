import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../data/tracking_repository.dart';

class TrackingScreen extends ConsumerWidget {
  final String bookingId;

  const TrackingScreen({super.key, required this.bookingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providerLocationAsync = ref.watch(
      providerLocationProvider(bookingId),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('تتبع الطلب')),
      body: FlutterMap(
        options: const MapOptions(
          initialCenter: LatLng(32.8872, 13.1913), // Tripoli
          initialZoom: 13.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.kadmat',
          ),
          providerLocationAsync.when(
            data: (location) => MarkerLayer(
              markers: [
                Marker(
                  point: location,
                  width: 80,
                  height: 80,
                  child: const Icon(
                    Icons.delivery_dining,
                    color: Colors.red,
                    size: 40,
                  ),
                ),
              ],
            ),
            loading: () => const MarkerLayer(markers: []),
            error: (err, stack) => const MarkerLayer(markers: []),
          ),
        ],
      ),
    );
  }
}
