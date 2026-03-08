import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/app_theme.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/navigation/job_flow_redirects.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/widgets/job_progress_stepper.dart';
import '../../../messages/presentation/chat_screen.dart';
import '../../data/job_repository.dart';
import '../../domain/job.dart';
import '../../domain/job_communication_policy.dart';
import '../../domain/job_status.dart';
import '../widgets/job_widgets.dart';

class CustomerJobTrackingScreen extends ConsumerStatefulWidget {
  final String jobId;

  const CustomerJobTrackingScreen({super.key, required this.jobId});

  @override
  ConsumerState<CustomerJobTrackingScreen> createState() =>
      _CustomerJobTrackingScreenState();
}

class _CustomerJobTrackingScreenState
    extends ConsumerState<CustomerJobTrackingScreen> {
  final MapController _mapController = MapController();

  // Default center (Riyadh) if no data

  @override
  Widget build(BuildContext context) {
    // Watch Job Data
    final jobAsync = ref.watch(watchJobProvider(widget.jobId));

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('تتبع الطلب'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(
          onPressed: () => context.go(AppRoutes.home), // Go home on back
          color: Colors.black, // Dark icon for visibility on map (usually)
          // But I'll add a container background if needed or check theme.
          // AppTheme dark? Then text is white. Map is light?
          // I'll make it standard styling.
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withValues(alpha: 0.5), Colors.transparent],
            ),
          ),
        ),
      ),
      body: jobAsync.when(
        data: (job) => _buildContent(job),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              ErrorHandler.getMessage(err),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(Job job) {
    final route = customerRouteForJobStatus(
      status: job.status,
      jobId: widget.jobId,
    );
    final inProgressRoute = AppRoutes.buildCustomerInProgressPath(widget.jobId);

    if (route != null && route != inProgressRoute) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.go(route);
      });
    }

    final jobLocation = LatLng(job.lat, job.lng);

    return Stack(
      children: [
        // Map Layer
        StreamBuilder<Map<String, dynamic>>(
          stream: job.technicianId != null
              ? ref
                    .read(jobRepositoryProvider)
                    .trackTechnician(job.technicianId!)
              : const Stream.empty(),
          builder: (context, snapshot) {
            LatLng? techLocation;
            if (snapshot.hasData && snapshot.data != null) {
              final data = snapshot.data!;
              if (data['lat'] != null && data['lng'] != null) {
                techLocation = LatLng(data['lat'], data['lng']);
              }
            }

            return FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: jobLocation, // Start validation
                initialZoom: 13.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.kadmat.app',
                ),
                MarkerLayer(
                  markers: [
                    // Job Location (Home)
                    Marker(
                      point: jobLocation,
                      width: 40.s,
                      height: 40.s,
                      child: const _LocationMarker(
                        icon: Icons.home,
                        color: Colors.blue,
                      ),
                    ),
                    // Technician Location
                    if (techLocation != null)
                      Marker(
                        point: techLocation,
                        width: 40.s,
                        height: 40.s,
                        child: const _LocationMarker(
                          icon: Icons.directions_car,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),

        // Bottom Card Info
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Badge
                Center(
                  child: Container(
                    width: 40.w,
                    height: 4.h,
                    margin: EdgeInsets.only(bottom: 16.h),
                    decoration: BoxDecoration(
                      color: Colors.grey[600],
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ),

                // 📊 Progress Stepper - توضيح مراحل الطلب للعميل
                JobProgressStepper.forCustomer(job.status, isHorizontal: true),
                SizedBox(height: 16.h),
                Divider(color: Colors.white12),
                SizedBox(height: 12.h),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'حالة الطلب',
                      style: TextStyle(fontSize: 16.fz, color: Colors.white70),
                    ),
                    JobStatusBadge(status: job.status),
                  ],
                ),
                SizedBox(height: 16.h),

                Text(
                  _getStatusMessage(job.status),
                  style: TextStyle(
                    fontSize: 20.fz,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                if (job.technician != null) ...[
                  SizedBox(height: 20.h),
                  Divider(color: Colors.white12),
                  SizedBox(height: 12.h),
                  ProfileCard(
                    name: job.technician?['full_name'],
                    phone: job.technician?['phone'],
                    imageUrl: job.technician?['profile_image_url'],
                    rating: (job.technician?['rating'] as num?)?.toDouble(),
                    label: 'الفني',
                  ),
                ],
              ],
            ),
          ),
        ),
        // Chat FAB
        if (job.technicianId != null &&
            JobCommunicationPolicy.canUseJobCommunication(job))
          Positioned(
            bottom: 220,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'chat_fab',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      jobId: widget.jobId,
                      otherUserName: job.technician?['full_name'],
                      otherUserImage: job.technician?['profile_image_url'],
                      otherUserPhone: job.technician?['phone']?.toString(),
                    ),
                  ),
                );
              },
              backgroundColor: AppTheme.primaryColor,
              child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
            ),
          ),
      ],
    );
  }

  String _getStatusMessage(String status) {
    final normalizedStatus = JobStatus.normalize(status);
    switch (normalizedStatus) {
      case JobStatus.onTheWay:
        return 'الفني في الطريق إليك الآن...';
      case JobStatus.arrived:
        return 'الفني وصل إلى موقعك.';
      case JobStatus.inProgress:
        return 'الفني يعمل على طلبك الآن...';
      case JobStatus.accepted:
        return 'تم قبول الطلب، الفني في الطريق!';
      default:
        return 'جاري التنفيذ...';
    }
  }
}

class _LocationMarker extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _LocationMarker({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Icon(icon, color: color, size: 24.s),
      ),
    );
  }
}

// Simple provider wrapper for convenience if not generated
final watchJobProvider = StreamProvider.family.autoDispose<Job, String>((
  ref,
  jobId,
) {
  return ref.watch(jobRepositoryProvider).watchJob(jobId);
});
