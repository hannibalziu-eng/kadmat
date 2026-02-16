import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:go_router/go_router.dart';
import 'package:kadmat/src/core/navigation/app_routes.dart';
import 'package:kadmat/src/features/technician/presentation/providers/technician_providers.dart';
import 'package:kadmat/src/features/technician/presentation/widgets/online_status_toggle.dart';
import 'package:kadmat/src/features/technician/presentation/widgets/technician_job_card.dart';
import 'package:latlong2/latlong.dart';

class AvailableJobsScreen extends ConsumerStatefulWidget {
  const AvailableJobsScreen({super.key});

  @override
  ConsumerState<AvailableJobsScreen> createState() =>
      _AvailableJobsScreenState();
}

class _AvailableJobsScreenState extends ConsumerState<AvailableJobsScreen> {
  final MapController _mapController = MapController();
  String _selectedFilter = 'all'; // all, 15km, 50km

  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(nearbyJobsWithDistanceProvider);
    final location = ref.watch(technicianLocationProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('الطلبات المتاحة'),
        centerTitle: true,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: OnlineStatusToggle(),
          ),
        ],
      ),
      body: location == null
          ? _buildLocationError()
          : jobsAsync.when(
              data: (jobsWithDistance) {
                // Filter by distance
                final filteredJobs = _filterJobs(jobsWithDistance);

                return Column(
                  children: [
                    // Map Section
                    SizedBox(
                      height: 250.h,
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: LatLng(
                            location.latitude,
                            location.longitude,
                          ),
                          initialZoom: 13.0,
                          minZoom: 10.0,
                          maxZoom: 18.0,
                        ),
                        children: [
                          // OpenStreetMap Tiles
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.kadmat.app',
                          ),

                          // Markers
                          MarkerLayer(
                            markers: [
                              // Current Location Marker
                              Marker(
                                point: LatLng(
                                  location.latitude,
                                  location.longitude,
                                ),
                                width: 40,
                                height: 40,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 3,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),

                              // Job Markers
                              ...filteredJobs.map((jobWithDist) {
                                final job = jobWithDist.job;
                                return Marker(
                                  point: LatLng(job.lat, job.lng),
                                  width: 40,
                                  height: 40,
                                  child: GestureDetector(
                                    onTap: () {
                                      _showJobBottomSheet(context, jobWithDist);
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF13b6ec),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.work,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Filter Chips
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 12.h,
                      ),
                      child: Row(
                        children: [
                          _buildFilterChip('الكل', 'all'),
                          SizedBox(width: 8.w),
                          _buildFilterChip('15 كم', '15km'),
                          SizedBox(width: 8.w),
                          _buildFilterChip('50 كم', '50km'),
                        ],
                      ),
                    ),

                    // Jobs List
                    Expanded(
                      child: filteredJobs.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              onRefresh: () async {
                                ref.invalidate(nearbyJobsWithDistanceProvider);
                              },
                              child: ListView.builder(
                                padding: EdgeInsets.only(bottom: 16.h),
                                itemCount: filteredJobs.length,
                                itemBuilder: (context, index) {
                                  final jobWithDist = filteredJobs[index];
                                  return TechnicianJobCard(
                                    job: jobWithDist.job,
                                    distanceKm: jobWithDist.distanceKm,
                                    onTap: () {
                                      _showJobBottomSheet(context, jobWithDist);
                                    },
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) =>
                  _buildErrorState(_friendlyErrorMessage(error)),
            ),
    );
  }

  List<JobWithDistance> _filterJobs(List<JobWithDistance> jobs) {
    switch (_selectedFilter) {
      case '15km':
        return jobs.where((j) => j.distanceKm <= 15).toList();
      case '50km':
        return jobs.where((j) => j.distanceKm <= 50).toList();
      default:
        return jobs;
    }
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
      },
      selectedColor: const Color(0xFF13b6ec).withValues(alpha: 0.2),
      checkmarkColor: const Color(0xFF13b6ec),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF13b6ec) : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildLocationError() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 64.s, color: Colors.grey),
            SizedBox(height: 16.h),
            Text(
              'فعّل الموقع لعرض الطلبات القريبة',
              style: TextStyle(fontSize: 16.fz, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16.h),
            ElevatedButton.icon(
              onPressed: () {
                ref.invalidate(technicianLocationProvider);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 80.s, color: Colors.grey),
            SizedBox(height: 16.h),
            Text(
              'لا توجد طلبات متاحة حالياً',
              style: TextStyle(fontSize: 16.fz, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64.s, color: Colors.red),
            SizedBox(height: 16.h),
            Text(
              'حدث خطأ',
              style: TextStyle(fontSize: 16.fz, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8.h),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.fz, color: Colors.grey),
            ),
            SizedBox(height: 16.h),
            ElevatedButton(
              onPressed: () {
                ref.invalidate(nearbyJobsWithDistanceProvider);
              },
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  String _friendlyErrorMessage(Object error) {
    final normalized = error.toString().toLowerCase();
    if (normalized.contains('invalidjwttoken') ||
        normalized.contains('jwt') ||
        normalized.contains('expired')) {
      return 'انتهت الجلسة. يرجى تسجيل الدخول مرة أخرى.';
    }
    if (normalized.contains('realtimesubscribeexception') ||
        normalized.contains('timedout')) {
      return 'تعذر الاتصال بالتحديث اللحظي. حاول التحديث بعد لحظات.';
    }
    if (normalized.contains('socketexception') ||
        normalized.contains('failed host lookup')) {
      return 'لا يوجد اتصال بالإنترنت حالياً.';
    }
    return 'تعذر تحميل الطلبات الآن. يرجى المحاولة مرة أخرى.';
  }

  void _showJobBottomSheet(BuildContext context, JobWithDistance jobWithDist) {
    final parentContext = context;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (bottomSheetContext) => Container(
        padding: EdgeInsets.all(24.w),
        decoration: BoxDecoration(
          color: Theme.of(bottomSheetContext).cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.grey,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            SizedBox(height: 20.h),

            // Job Details
            Text(
              jobWithDist.job.service?['name'] ?? 'خدمة',
              style: TextStyle(fontSize: 20.fz, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16.h),

            Row(
              children: [
                Icon(Icons.location_on, size: 20.s, color: Colors.grey),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    '${jobWithDist.formattedDistance} • ${jobWithDist.job.addressText}',
                    style: TextStyle(fontSize: 14.fz, color: Colors.grey),
                  ),
                ),
              ],
            ),

            if (jobWithDist.job.description != null) ...[
              SizedBox(height: 16.h),
              Text(
                'الوصف:',
                style: TextStyle(fontSize: 14.fz, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8.h),
              Text(
                jobWithDist.job.description!,
                style: TextStyle(fontSize: 14.fz, color: Colors.grey[700]),
              ),
            ],

            SizedBox(height: 20.h),

            // Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(bottomSheetContext);
                  parentContext.push(
                    AppRoutes.buildTechnicianBiddingPath(jobWithDist.job.id),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF13b6ec),
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: Text(
                  'تقديم عرض',
                  style: TextStyle(
                    fontSize: 16.fz,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
}
