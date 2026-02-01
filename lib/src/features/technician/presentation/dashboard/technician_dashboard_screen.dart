import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import 'package:url_launcher/url_launcher.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/utils/global_error_handler.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/shimmer_skeletons.dart';
import '../../../../core/widgets/kadmat_toast.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../jobs/presentation/job_controller.dart';
import '../../../jobs/domain/job.dart';
import '../../../../core/services/location_service.dart';

class TechnicianDashboardScreen extends ConsumerStatefulWidget {
  const TechnicianDashboardScreen({super.key});

  @override
  ConsumerState<TechnicianDashboardScreen> createState() =>
      _TechnicianDashboardScreenState();
}

class _TechnicianDashboardScreenState
    extends ConsumerState<TechnicianDashboardScreen> {
  bool _isOnline = true;

  bool _isRetryingToken = false;

  Future<void> _refreshJobs() async {
    // Attempt to refresh session first if we are here (manual retry)
    try {
      if (mounted) {
        await Supabase.instance.client.auth.refreshSession();
      }
    } catch (e) {
      debugPrint('Error refreshing session: $e');
    }

    if (!mounted) return;

    // final userProfile = ref.read(authRepositoryProvider).userProfile;
    // final serviceId = userProfile?['service_id'] as String?;

    final location = ref.read(locationStreamProvider).valueOrNull;
    final lat = location?.latitude ?? 32.08168824752129;
    final lng = location?.longitude ?? 20.054815423923195;

    ref.invalidate(
      watchNearbyJobsStreamProvider(
        lat: lat,
        lng: lng,
        // serviceId: serviceId, // Disable service filter for testing
        serviceId: null,
      ),
    );
  }

  Future<void> _handleTokenError() async {
    if (_isRetryingToken) return;
    _isRetryingToken = true;
    debugPrint('🔄 Token expired, attempting to refresh session...');

    try {
      await Supabase.instance.client.auth.refreshSession();
      debugPrint('✅ Session refreshed successfully');

      if (mounted) {
        final location = ref.read(locationStreamProvider).valueOrNull;
        final lat = location?.latitude ?? 32.08168824752129;
        final lng = location?.longitude ?? 20.054815423923195;

        // Invalidate to restart the stream
        ref.invalidate(
          watchNearbyJobsStreamProvider(
            lat: lat,
            lng: lng,
            // serviceId: serviceId, // Disable service filter for testing
            serviceId: null,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Failed to refresh session: $e');
    } finally {
      if (mounted) {
        setState(() => _isRetryingToken = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = ref.watch(authRepositoryProvider).userProfile;
    final userName = userProfile?['full_name'] ?? 'الفني';
    final serviceId = userProfile?['service_id'] as String?;

    // Watch current location
    final locationAsync = ref.watch(locationStreamProvider);

    // Default to Benghazi for testing (matches customer job)
    final lat = locationAsync.valueOrNull?.latitude ?? 32.08168824752129;
    final lng = locationAsync.valueOrNull?.longitude ?? 20.054815423923195;
    debugPrint('📍 Technician Dashboard Search Location: $lat, $lng');

    // Watch for real-time nearby jobs using the stream
    final nearbyJobsStream = ref.watch(
      watchNearbyJobsStreamProvider(lat: lat, lng: lng, serviceId: serviceId),
    );

    // Listen for new jobs to show notification
    // Listen for new jobs to show notification
    ref.listen(
      watchNearbyJobsStreamProvider(lat: lat, lng: lng, serviceId: serviceId),
      (previous, next) {
        // Handle Error State (Token Expiry)
        if (next is AsyncError) {
          final error = next.error.toString();
          if (error.contains('InvalidJWTToken') ||
              error.contains('expired') ||
              error.contains('RealtimeSubscribeException')) {
            _handleTokenError();
          }
        }

        if (next is AsyncData && next.value != null) {
          final newJobs = next.value!;
          final oldJobs = previous?.value ?? [];

          // If we have more jobs than before, show notification
          if (newJobs.length > oldJobs.length) {
            // Only show if it's not the initial load (previous is not null or loading)
            if (previous is AsyncData) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(
                        Icons.notifications_active,
                        color: Colors.white,
                      ),
                      SizedBox(width: 8.w),
                      const Text('🔔 يوجد طلب جديد بالقرب منك!'),
                    ],
                  ),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                  margin: EdgeInsets.all(16.w),
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          }
        }
      },
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('لوحة التحكم'),
        centerTitle: true,
        actions: [
          Switch(
            value: _isOnline,
            onChanged: (value) => setState(() => _isOnline = value),
            activeThumbColor: Colors.green,
          ),
          SizedBox(width: 16.w),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _refreshJobs();
          // Small delay to allow the stream to reconnect
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: SingleChildScrollView(
          physics:
              const AlwaysScrollableScrollPhysics(), // Ensure scroll even if content is short
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting with real name
              Text(
                'مرحباً، $userName 👋',
                style: TextStyle(
                  fontSize: 24.fz,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ).animate().fadeIn().slideX(),
              SizedBox(height: 8.h),
              Text(
                _isOnline ? 'أنت متصل الآن وتستقبل الطلبات' : 'أنت غير متصل',
                style: TextStyle(
                  fontSize: 14.fz,
                  color: _isOnline ? Colors.green : Colors.grey,
                ),
              ).animate().fadeIn().slideX(delay: 100.ms),
              SizedBox(height: 24.h),

              // Stats Grid - Use real data from myJobs
              _buildStatsSection(),

              SizedBox(height: 24.h),

              // New Requests Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'طلبات جديدة قريبة',
                    style: TextStyle(
                      fontSize: 18.fz,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      // Navigate to requests tab
                    },
                    child: const Text('عرض الكل'),
                  ),
                ],
              ).animate().fadeIn(delay: 300.ms),
              SizedBox(height: 12.h),

              // Real-time jobs list
              nearbyJobsStream.when(
                data: (jobs) {
                  if (jobs.isEmpty) {
                    return const EmptyStateWidget(
                      title: 'لا توجد طلبات قريبة',
                      subtitle: 'سنقوم بإخطارك عند توفر طلبات جديدة في منطقتك',
                      icon: Icons.search_off_rounded,
                    );
                  }
                  return Column(
                    children: jobs
                        .take(3)
                        .map(
                          (job) => Padding(
                            padding: EdgeInsets.only(bottom: 12.h),
                            child: _buildJobCard(job),
                          ),
                        )
                        .toList(),
                  );
                },
                loading: () => const ListSkeleton(
                  itemCount: 2,
                  itemHeight: 120,
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                ),
                error: (err, _) => _buildErrorCard(err.toString()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    final myJobsAsync = ref.watch(watchMyJobsRealtimeProvider);

    return myJobsAsync.when(
      data: (jobs) {
        final todayJobs = jobs
            .where(
              (j) =>
                  j.completedAt != null &&
                  j.completedAt!.day == DateTime.now().day,
            )
            .toList();

        final todayEarnings = todayJobs.fold<double>(
          0,
          (sum, job) => sum + (job.technicianPrice ?? job.initialPrice ?? 0),
        );

        return Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'أرباح اليوم',
                '${todayEarnings.toStringAsFixed(0)} ر.س',
                Icons.account_balance_wallet,
                Colors.green,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: _buildStatCard(
                'الطلبات المكتملة',
                '${todayJobs.length}',
                Icons.check_circle_outline,
                Colors.blue,
              ),
            ),
          ],
        ).animate().fadeIn().slideY(begin: 0.2, delay: 200.ms);
      },
      loading: () => _buildStatsShimmer(),
      error: (_, __) => _buildStatsShimmer(),
    );
  }

  Widget _buildStatsShimmer() {
    return Row(
      children: [
        Expanded(
          child: SkeletonBase(
            width: double.infinity,
            height: 100.h,
            borderRadius: 16.r,
          ),
        ),
        SizedBox(width: 16.w),
        Expanded(
          child: SkeletonBase(
            width: double.infinity,
            height: 100.h,
            borderRadius: 16.r,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorCard(String error) {
    String displayError = 'حدث خطأ في الاتصال';
    if (error.contains('InvalidJWTToken') || error.contains('expired')) {
      displayError = 'انتهت الجلسة، جاري إعادة الاتصال...';
    } else if (error.contains('SocketException')) {
      displayError = 'لا يوجد اتصال بالإنترنت';
    }

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 24.s),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              displayError,
              style: TextStyle(fontSize: 14.fz, color: Colors.red),
            ),
          ),
          if (_isRetryingToken)
            SizedBox(
              width: 20.w,
              height: 20.w,
              child: const CircularProgressIndicator(strokeWidth: 2),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.red),
              onPressed: _refreshJobs,
            ),
        ],
      ),
    );
  }

  // Track jobs currently being accepted to prevent double-clicks
  final Set<String> _processingJobs = {};

  Widget _buildJobCard(Job job) {
    final isProcessing = _processingJobs.contains(job.id);

    // Extract service name
    final serviceName = job.service?['name'] ?? 'خدمة';

    // Extract customer name
    final customerName = job.customer?['full_name'] ?? 'عميل';

    // Extract location info
    final addressText = job.addressText ?? 'موقع غير محدد';
    final hasCoordinates = job.lat != 0 && job.lng != 0;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            blurRadius: 15.r,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Customer info + Status badge
          Row(
            children: [
              CircleAvatar(
                radius: 24.r,
                backgroundColor: Theme.of(context).primaryColor,
                child: Icon(Icons.person, color: Colors.white, size: 24.s),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customerName,
                      style: TextStyle(
                        fontSize: 16.fz,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    // Service Name with icon
                    Row(
                      children: [
                        Icon(
                          Icons.build_circle_outlined,
                          size: 14.s,
                          color: Theme.of(context).primaryColor,
                        ),
                        SizedBox(width: 4.w),
                        Expanded(
                          child: Text(
                            serviceName,
                            style: TextStyle(
                              fontSize: 13.fz,
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  ['pending', 'no_technician_found'].contains(job.status)
                      ? 'جديد'
                      : 'قيد التنفيذ',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 12.fz,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 12.h),

          // Description / Problem Summary
          if (job.description != null && job.description!.isNotEmpty) ...[
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 18.s,
                    color: Colors.grey[600],
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      job.description!,
                      style: TextStyle(
                        fontSize: 13.fz,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12.h),
          ],

          // Location Row
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.location_on, size: 20.s, color: Colors.blue),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    addressText,
                    style: TextStyle(fontSize: 13.fz, color: Colors.blue[700]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 12.h),

          // Price Row
          Row(
            children: [
              Icon(Icons.attach_money, size: 18.s, color: Colors.green),
              SizedBox(width: 4.w),
              Text(
                'السعر المبدئي:',
                style: TextStyle(fontSize: 12.fz, color: Colors.grey),
              ),
              SizedBox(width: 4.w),
              Text(
                '${job.initialPrice?.toStringAsFixed(0) ?? '0'} ر.س',
                style: TextStyle(
                  fontSize: 15.fz,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),

          SizedBox(height: 16.h),

          // Action Buttons Row
          Row(
            children: [
              // Accept Button
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: isProcessing
                      ? null
                      : () async {
                          setState(() {
                            _processingJobs.add(job.id);
                          });

                          try {
                            debugPrint(
                              '🟢 [TechnicianDashboard] Accepting job ${job.id}...',
                            );

                            // 1. Get Router instance first to capture context
                            final goRouter = GoRouter.of(context);

                            // 2. Perform acceptance
                            await ref
                                .read(jobControllerProvider.notifier)
                                .acceptJob(job.id);

                            debugPrint(
                              '✅ [TechnicianDashboard] Job accepted. Navigating to Set Price...',
                            );

                            // 3. Navigate immediately without manual refresh
                            // Real-time stream will handle list update automatically
                            if (mounted) {
                              goRouter.pushNamed(
                                AppRoutes.technicianPriceInput,
                                pathParameters: {'jobId': job.id},
                                extra: {
                                  'orderId': job.id,
                                  'serviceName': serviceName,
                                },
                              );
                            }
                          } on JobAlreadyAcceptedException catch (e) {
                            debugPrint('🔴 Job already accepted: ${e.message}');
                            if (mounted) {
                              KadmatToast.showError(
                                context,
                                title: 'تم قبول الطلب',
                                message: e.message,
                              );
                            }
                          } on TechnicianLockedException catch (e) {
                            debugPrint('🔴 Technician locked: ${e.message}');
                            if (mounted) {
                              KadmatToast.showWarning(
                                context,
                                title: 'طلب قيد التنفيذ',
                                message: e.message,
                              );
                            }
                          } on InvalidStatusException catch (e) {
                            debugPrint('🔴 Invalid status: ${e.message}');
                            if (mounted) {
                              KadmatToast.showError(
                                context,
                                title: 'حالة غير صحيحة',
                                message: e.message,
                              );
                            }
                          } on NetworkException catch (e) {
                            debugPrint('🔴 Network error: ${e.message}');
                            if (mounted) {
                              KadmatToast.showError(
                                context,
                                title: 'خطأ في الاتصال',
                                message: e.message,
                              );
                            }
                          } on JobNotFoundException catch (e) {
                            debugPrint('🔴 Job not found: ${e.message}');
                            if (mounted) {
                              KadmatToast.showError(
                                context,
                                title: 'الطلب غير موجود',
                                message: e.message,
                              );
                            }
                          } catch (e, stack) {
                            debugPrint('🔴 EXCEPTION in acceptance button: $e');
                            debugPrint('🔴 Stack trace: $stack');
                            if (mounted) {
                              GlobalErrorHandler.handle(context, e);
                            }
                          } finally {
                            if (mounted) {
                              setState(() {
                                _processingJobs.remove(job.id);
                              });
                            }
                          }
                        },
                  icon: isProcessing
                      ? SizedBox(
                          width: 20.w,
                          height: 20.w,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(isProcessing ? 'جاري القبول...' : 'قبول الطلب'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.green.withValues(
                      alpha: 0.6,
                    ),
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              // Location Button - Opens map
              Expanded(
                flex: 1,
                child: OutlinedButton.icon(
                  onPressed: hasCoordinates
                      ? () => _openLocationInMaps(job.lat, job.lng, addressText)
                      : null,
                  icon: Icon(Icons.map_outlined, size: 20.s),
                  label: const Text('الموقع'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                    side: BorderSide(
                      color: hasCoordinates ? Colors.blue : Colors.grey,
                    ),
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.2, delay: 400.ms);
  }

  /// Opens the customer location in the default maps app
  Future<void> _openLocationInMaps(double lat, double lng, String label) async {
    // Using Google Maps URL scheme that works on both Android and iOS
    final googleMapsUrl =
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng';

    try {
      final uri = Uri.parse(googleMapsUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback: show coordinates in a snackbar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('الإحداثيات: $lat, $lng'),
              action: SnackBarAction(
                label: 'نسخ',
                onPressed: () {
                  // Could add clipboard copy here
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error opening maps: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ في فتح الخريطة: $e')));
      }
    }
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10.r,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24.s),
          ),
          SizedBox(height: 12.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 20.fz,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            title,
            style: TextStyle(fontSize: 12.fz, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
