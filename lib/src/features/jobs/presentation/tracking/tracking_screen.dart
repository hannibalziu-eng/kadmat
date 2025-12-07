import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_scalify/flutter_scalify.dart';

import '../../data/job_repository.dart';

class TrackingScreen extends ConsumerStatefulWidget {
  final String jobId;
  final String technicianId;
  final double customerLat;
  final double customerLng;

  const TrackingScreen({
    super.key,
    required this.jobId,
    required this.technicianId,
    required this.customerLat,
    required this.customerLng,
  });

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  late final MapController _mapController;
  LatLng? _technicianLocation;
  StreamSubscription? _locationSubscription;
  String _eta = 'جاري الحساب...';

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _subscribeToTechnicianLocation();
  }

  void _subscribeToTechnicianLocation() {
    final jobRepo = ref.read(jobRepositoryProvider);
    _locationSubscription = jobRepo.trackTechnician(widget.technicianId).listen(
      (user) {
        if (user.isNotEmpty) {
          final loc = user['location'];
          if (loc != null) {
            try {
              // Simplified handling for WKT / GeoJSON variants
              if (loc is Map) {
                final coords = loc['coordinates'] as List;
                final lng = coords[0] as double;
                final lat = coords[1] as double;
                _updateTechnicianLocation(LatLng(lat, lng));
              } else if (loc is String && loc.startsWith('POINT')) {
                final content = loc.substring(6, loc.length - 1);
                final parts = content.split(' ');
                final lng = double.parse(parts[0]);
                final lat = double.parse(parts[1]);
                _updateTechnicianLocation(LatLng(lat, lng));
              }
            } catch (e) {
              debugPrint('Error parsing location: $e');
            }
          }
        }
      },
    );
  }

  void _updateTechnicianLocation(LatLng newLoc) {
    if (!mounted) return;
    setState(() {
      _technicianLocation = newLoc;
      _calculateETA();
    });
    // Optional: auto-center map or fit bounds
  }

  void _calculateETA() {
    if (_technicianLocation == null) return;

    final distance = const Distance().as(
      LengthUnit.Kilometer,
      LatLng(widget.customerLat, widget.customerLng),
      _technicianLocation!,
    );

    // Rough estimate: 30km/h average speed in city + traffic
    // Time = Distance / Speed
    final hours = distance / 30.0;
    final minutes = (hours * 60).round();

    setState(() {
      if (minutes < 1) {
        _eta = 'أقل من دقيقة';
      } else {
        _eta = '$minutes دقيقة';
      }
    });
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customerLoc = LatLng(widget.customerLat, widget.customerLng);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تتبع الفني'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: customerLoc, initialZoom: 14.0),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.kadmat.app',
              ),
              MarkerLayer(
                markers: [
                  // Customer Marker (Home)
                  Marker(
                    point: customerLoc,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.home, color: Colors.blue, size: 40),
                  ),
                  // Technician Marker (Car)
                  if (_technicianLocation != null)
                    Marker(
                      point: _technicianLocation!,
                      width: 40,
                      height: 40,
                      child: const _CarMarker(),
                    ),
                ],
              ),
              // Route (Polyline) - Simplified straight line for now
              if (_technicianLocation != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [_technicianLocation!, customerLoc],
                      strokeWidth: 4.0,
                      color: Colors.blueAccent,
                    ),
                  ],
                ),
            ],
          ),

          // Bottom Sheet for ETA
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'الوقت المقدر للوصول',
                            style: TextStyle(
                              fontSize: 14.fz,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            _eta,
                            style: TextStyle(
                              fontSize: 24.fz,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.directions_car,
                          color: Colors.blue,
                          size: 32.s,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        // Call functionality could go here
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: const Text(
                        'اتصال بالفني',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CarMarker extends StatelessWidget {
  const _CarMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      padding: const EdgeInsets.all(6),
      child: const Icon(Icons.local_shipping, size: 20, color: Colors.blue),
    );
  }
}
