import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart' show Position;
import 'package:go_router/go_router.dart';

import '../../../../core/app_theme.dart';
import '../../../../core/design/kadmat_tokens.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/utils/logger_service.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/shimmer_skeletons.dart';
import '../../../../core/widgets/kadmat_toast.dart';
import '../../../../core/widgets/technician_appbar.dart';
import 'technician_stats_grid.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../jobs/domain/job.dart';
import '../../../jobs/domain/job_status.dart';
import '../../../jobs/presentation/job_controller.dart';
import '../../../notifications/data/notification_repository.dart';
import '../../../../core/services/location/location_service.dart';
import '../../../../core/widgets/location_status_indicator.dart';
import '../../../../core/services/presence/presence_service.dart';
import '../providers/technician_dispatch_feed_provider.dart';
import '../providers/technician_providers.dart';
import '../providers/technician_tab_provider.dart';
import '../utils/technician_dispatch_queue.dart';

enum _NearbySortMode { newest, closest }

enum _NearbyCardMode { detailed, compact }

class TechnicianDashboardScreen extends ConsumerStatefulWidget {
  const TechnicianDashboardScreen({super.key});

  @override
  ConsumerState<TechnicianDashboardScreen> createState() =>
      _TechnicianDashboardScreenState();
}

class _TechnicianDashboardScreenState
    extends ConsumerState<TechnicianDashboardScreen> {
  bool _isOnline = false;
  bool _isRetryingToken = false;
  bool _didBootstrapRealtime = false;
  DateTime? _lastTokenRecoveryAttempt;

  ProviderSubscription<AsyncValue<TechnicianDispatchFeed>>?
  _dispatchFeedSubscription;
  List<Job> _cachedNearbyJobs = const <Job>[];
  final Set<String> _telemetryLoggedJobs = <String>{};
  _NearbySortMode _nearbySortMode = _NearbySortMode.newest;
  _NearbyCardMode _nearbyCardMode = _NearbyCardMode.detailed;
  bool _urgentOnly = false;

  @override
  void initState() {
    super.initState();
    _setupDispatchFeedSideEffects();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrapRealtimeServices();
    });
  }

  @override
  void dispose() {
    _dispatchFeedSubscription?.close();
    super.dispose();
  }

  void _setupDispatchFeedSideEffects() {
    _dispatchFeedSubscription = ref
        .listenManual<AsyncValue<TechnicianDispatchFeed>>(
          technicianDispatchFeedProvider,
          (_, next) {
            next.whenOrNull(
              error: (error, _) {
                if (_isRecoverableRealtimeError(error)) {
                  _handleTokenError();
                }
              },
              data: (feed) {
                final visibleJobs = feed.visibleJobs;
                _trackDispatchTelemetry(visibleJobs);

                _cachedNearbyJobs = visibleJobs;
              },
            );
          },
          fireImmediately: true,
        );
  }

  bool _isRecoverableRealtimeError(Object error) {
    final normalized = error.toString().toLowerCase();
    return normalized.contains('invalidjwttoken') ||
        normalized.contains('realtimesubscribeexception') ||
        normalized.contains('timedout') ||
        normalized.contains('expired') ||
        normalized.contains('jwt');
  }

  void _trackDispatchTelemetry(List<Job> visibleJobs) {
    final now = DateTime.now();

    for (final job in visibleJobs) {
      if (_telemetryLoggedJobs.contains(job.id)) continue;
      _telemetryLoggedJobs.add(job.id);

      final waitSeconds = now
          .difference(job.createdAt)
          .inSeconds
          .clamp(0, 86400);
      LoggerService.i(
        'dispatch.telemetry nearby_job_visible '
        'job_id=${job.id} '
        'wait_seconds=$waitSeconds '
        'status=${job.status}',
      );
    }

    if (_telemetryLoggedJobs.length > 3000) {
      _telemetryLoggedJobs.clear();
    }
  }

  List<Job> _sortNearbyJobs(List<Job> jobs, Position? currentLocation) {
    return TechnicianDispatchQueue.prepareJobs(
      jobs: jobs,
      sortMode: _nearbySortMode == _NearbySortMode.closest
          ? TechnicianDispatchSortMode.closest
          : TechnicianDispatchSortMode.newest,
      urgentOnly: false,
      technicianLocation: _toGeoPoint(currentLocation),
    );
  }

  double _distanceMeters({
    required Position currentLocation,
    required double jobLat,
    required double jobLng,
  }) {
    return TechnicianDispatchQueue.distanceBetweenPointsMeters(
      from: _toGeoPoint(currentLocation)!,
      to: TechnicianGeoPoint(lat: jobLat, lng: jobLng),
    );
  }

  String _formatWaitingTime(DateTime createdAt) {
    return TechnicianDispatchQueue.waitingLabel(createdAt);
  }

  bool _isUrgentJob(Job job) {
    return TechnicianDispatchQueue.isUrgentJob(job);
  }

  List<Job> _applyJobFilters(List<Job> jobs) {
    if (!_urgentOnly) return jobs;
    return jobs.where(_isUrgentJob).toList();
  }

  Job? _pickPriorityJob(List<Job> jobs, Position? currentLocation) {
    return TechnicianDispatchQueue.pickPriorityJob(
      jobs: jobs,
      technicianLocation: _toGeoPoint(currentLocation),
    );
  }

  TechnicianGeoPoint? _toGeoPoint(Position? position) {
    if (position == null) return null;
    return TechnicianGeoPoint(lat: position.latitude, lng: position.longitude);
  }

  Future<void> _openBidding(String jobId) async {
    if (!mounted) return;
    await context.push(AppRoutes.buildTechnicianBiddingPath(jobId));
  }

  Future<void> _bootstrapRealtimeServices() async {
    if (!mounted || _didBootstrapRealtime) return;

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final profileIsOnline =
        ref.read(authRepositoryProvider).userProfile?['is_online'] == true;
    if (mounted && _isOnline != profileIsOnline) {
      setState(() => _isOnline = profileIsOnline);
    }

    _didBootstrapRealtime = true;

    try {
      await ref.read(presenceServiceProvider).initialize(userId);

      if (_isOnline) {
        try {
          await LocationService().startTracking(userId);
          await LocationService().setTrackingMode(LocationTrackingMode.idle);
        } catch (e) {
          debugPrint('⚠️ Location tracking unavailable during bootstrap: $e');
        }
        await ref
            .read(presenceServiceProvider)
            .setStatus(UserPresenceStatus.online, userId);
      } else {
        await ref
            .read(presenceServiceProvider)
            .setStatus(UserPresenceStatus.offline, userId);
      }
    } catch (e) {
      debugPrint('⚠️ Failed to bootstrap realtime services: $e');
    }
  }

  Future<void> _refreshJobs() async {
    // Attempt to refresh session first if we are here (manual retry)
    try {
      if (context.mounted) {
        await Supabase.instance.client.auth.refreshSession();
      }
    } catch (e) {
      debugPrint('Error refreshing session: $e');
    }

    if (!mounted) return;
    ref.invalidate(technicianDispatchFeedProvider);
    ref.invalidate(watchNearbyJobsStreamProvider);
  }

  Future<void> _handleTokenError() async {
    if (_isRetryingToken) return;
    final now = DateTime.now();
    if (_lastTokenRecoveryAttempt != null &&
        now.difference(_lastTokenRecoveryAttempt!) <
            const Duration(seconds: 8)) {
      return;
    }

    _lastTokenRecoveryAttempt = now;
    _isRetryingToken = true;
    debugPrint('🔄 Token expired, attempting to refresh session...');

    try {
      await Supabase.instance.client.auth.refreshSession();
      debugPrint('✅ Session refreshed successfully');

      if (context.mounted) {
        ref.invalidate(technicianDispatchFeedProvider);
        ref.invalidate(watchNearbyJobsStreamProvider);
      }
    } catch (e) {
      debugPrint('❌ Failed to refresh session: $e');
    } finally {
      if (context.mounted) {
        setState(() => _isRetryingToken = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = ref.watch(authRepositoryProvider).userProfile;
    final userName = userProfile?['full_name'] ?? 'الفني';
    final unreadNotifications = ref.watch(liveUnreadNotificationsCountProvider);
    final dispatchFeedAsync = ref.watch(technicianDispatchFeedProvider);
    final location = dispatchFeedAsync.valueOrNull?.location;
    final nearbyJobsCount =
        dispatchFeedAsync.valueOrNull?.visibleJobs.length ?? 0;

    if (location != null) {
      debugPrint(
        '📍 Technician Dashboard Search Location: ${location.latitude}, ${location.longitude}',
      );
    } else {
      debugPrint(
        '⚠️ Technician location unavailable, nearby jobs stream paused',
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: TechnicianAppBar(
        isOnline: _isOnline,
        onToggleOnline: () async {
          final userId = Supabase.instance.client.auth.currentUser?.id;
          if (userId == null) return;

          setState(() => _isOnline = !_isOnline);
          ref.read(authRepositoryProvider).mergeCachedUserProfile({
            'is_online': _isOnline,
          });

          try {
            await ref.read(presenceServiceProvider).initialize(userId);

            if (_isOnline) {
              var locationStarted = true;
              try {
                await LocationService().startTracking(userId);
                await LocationService().setTrackingMode(
                  LocationTrackingMode.idle,
                );
              } catch (e) {
                locationStarted = false;
                debugPrint('⚠️ Location tracking unavailable while going online: $e');
              }

              await ref
                  .read(presenceServiceProvider)
                  .setStatus(UserPresenceStatus.online, userId);

              if (context.mounted) {
                if (locationStarted) {
                  KadmatToast.showSuccess(
                    context,
                    title: 'أنت الآن متصل',
                    message: 'تم تفعيل تتبع الموقع.',
                  );
                } else {
                  KadmatToast.showInfo(
                    context,
                    title: 'تم تفعيل الاتصال',
                    message:
                        'اسمح بالموقع أو حدده يدويًا من شاشة الطلبات لإظهار الطلبات القريبة.',
                  );
                }
              }
            } else {
              await LocationService().stopTracking();
              ref.read(technicianManualLocationProvider.notifier).state = null;
              await ref
                  .read(presenceServiceProvider)
                  .setStatus(UserPresenceStatus.offline, userId);

              if (context.mounted) {
                KadmatToast.showInfo(
                  context,
                  title: 'تم قطع الاتصال',
                  message: 'توقف تتبع الموقع',
                );
              }
            }

            ref.invalidate(technicianResolvedLocationProvider);
            ref.invalidate(technicianDispatchFeedProvider);
            ref.invalidate(watchNearbyJobsStreamProvider);
          } catch (e) {
            setState(() => _isOnline = !_isOnline);
            ref.read(authRepositoryProvider).mergeCachedUserProfile({
              'is_online': _isOnline,
            });
            if (context.mounted) {
              KadmatToast.showError(
                context,
                title: 'خطأ',
                message: _friendlyLocationToggleError(e),
              );
            }
          }
        },
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
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDashboardHero(
                    userName: userName,
                    nearbyJobsCount: nearbyJobsCount,
                    unreadNotifications: unreadNotifications,
                    location: location,
                  ).animate().fadeIn(delay: 180.ms).slideY(begin: 0.06),
                  SizedBox(height: 18.h),
                  _buildSectionHeader(
                    title: 'طلبات قريبة الآن',
                    subtitle:
                        'ابدأ بأقرب طلب مناسب الآن، ثم افتح القائمة الكاملة إذا أردت خيارات أكثر.',
                    actionLabel: 'عرض الكل',
                    onAction: () {
                      ref.read(technicianTabIndexProvider.notifier).state = 1;
                    },
                  ).animate().fadeIn(delay: 300.ms),
                  if (unreadNotifications > 0) ...[
                    SizedBox(height: 8.h),
                    _buildRealtimeNoticeCard(
                      message:
                          'لديك $unreadNotifications إشعارات جديدة. افتح أيقونة الجرس للمراجعة.',
                    ),
                  ],
                  SizedBox(height: 8.h),
                  _buildFocusCard(nearbyJobsCount: nearbyJobsCount),
                  SizedBox(height: 12.h),
                  if (_isOnline && nearbyJobsCount > 1) ...[
                    _buildSortControls(location),
                    SizedBox(height: 12.h),
                  ],

                  // Real-time jobs list
                  dispatchFeedAsync.when(
                    data: (feed) {
                      return _buildNearbyJobsListSection(
                        sourceJobs: feed.visibleJobs,
                        currentLocation: location,
                      );
                    },
                    loading: () {
                      if (_cachedNearbyJobs.isNotEmpty) {
                        return _buildNearbyJobsListSection(
                          sourceJobs: _cachedNearbyJobs,
                          currentLocation: location,
                          noticeMessage: 'جاري تحديث البيانات الحية...',
                        );
                      }

                      return const ListSkeleton(
                        itemCount: 2,
                        itemHeight: 120,
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                      );
                    },
                    error: (err, _) {
                      if (_cachedNearbyJobs.isNotEmpty) {
                        return _buildNearbyJobsListSection(
                          sourceJobs: _cachedNearbyJobs,
                          currentLocation: location,
                          noticeMessage:
                              'تعذر التحديث اللحظي مؤقتاً. يتم عرض آخر بيانات متاحة.',
                          noticeWarning: true,
                        );
                      }

                      return _buildErrorCard(err.toString());
                    },
                  ),

                  SizedBox(height: 24.h),

                  _buildSectionHeader(
                    title: 'أداء الحساب',
                    subtitle:
                        'ملخص سريع عن نشاطك الحالي، الأعمال المكتملة، واستقبال الطلبات.',
                  ).animate().fadeIn(delay: 220.ms),
                  SizedBox(height: 10.h),
                  LocationStatusIndicator(
                    isOnline: _isOnline,
                  ).animate().fadeIn(delay: 200.ms),
                  SizedBox(height: 16.h),
                  const TechnicianStatsGrid(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    String displayError = 'حدث خطأ في الاتصال';
    final normalized = error.toLowerCase();
    if (normalized.contains('invalidjwttoken') ||
        normalized.contains('expired') ||
        normalized.contains('jwt')) {
      displayError = 'انتهت الجلسة، جاري إعادة الاتصال...';
    } else if (normalized.contains('realtimesubscribeexception') ||
        normalized.contains('timedout')) {
      displayError = 'تعذر الاتصال بالتحديث اللحظي، جاري إعادة المحاولة...';
    } else if (normalized.contains('socketexception') ||
        normalized.contains('failed host lookup')) {
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

  Widget _buildDashboardHero({
    required String userName,
    required int nearbyJobsCount,
    required int unreadNotifications,
    required Position? location,
  }) {
    final locationLabel = location == null
        ? 'في انتظار تحديد الموقع'
        : '${location.latitude.toStringAsFixed(3)}, ${location.longitude.toStringAsFixed(3)}';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28.r),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF19323C), Color(0xFF0D1E26)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48.w,
                height: 48.w,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: Icon(
                  _isOnline ? Icons.radar_rounded : Icons.pause_circle_outline,
                  color: Colors.white,
                  size: 22.s,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مرحباً، $userName',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22.fz,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      _isOnline
                          ? 'أنت متصل الآن وتستقبل الطلبات في محيطك.'
                          : 'فعّل حالة الاتصال حتى تبدأ باستقبال الطلبات الجديدة.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 12.5.fz,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              _buildHeroPill(
                icon: Icons.explore_outlined,
                label: locationLabel,
              ),
              _buildHeroPill(
                icon: Icons.notifications_none_rounded,
                label: unreadNotifications > 0
                    ? '$unreadNotifications إشعارات تحتاج مراجعة'
                    : 'لا توجد إشعارات جديدة',
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: _buildHeroMetric(
                  label: 'طلبات قريبة',
                  value: '$nearbyJobsCount',
                  accent: KadmatColors.brandAccent,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _buildHeroMetric(
                  label: 'الحالة',
                  value: _isOnline ? 'متصل' : 'غير متصل',
                  accent: _isOnline
                      ? KadmatColors.stateSuccess
                      : KadmatColors.stateWarning,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroPill({required IconData icon, required String label}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.84), size: 16.s),
          SizedBox(width: 6.w),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 11.5.fz,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroMetric({
    required String label,
    required String value,
    required Color accent,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8.w,
            height: 8.w,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          SizedBox(height: 10.h),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20.fz,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 11.5.fz,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 20.fz, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 4.h),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: KadmatColors.lightTextSecondary,
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    );
  }

  Widget _buildRealtimeNoticeCard({
    required String message,
    bool isWarning = false,
  }) {
    final color = isWarning ? Colors.orange : Colors.blue;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            isWarning ? Icons.wifi_tethering_off : Icons.sync,
            color: color,
            size: 18.s,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12.fz,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNearbyJobsListSection({
    required List<Job> sourceJobs,
    required Position? currentLocation,
    String? noticeMessage,
    bool noticeWarning = false,
  }) {
    final sortedJobs = _sortNearbyJobs(sourceJobs, currentLocation);
    final filteredJobs = _applyJobFilters(sortedJobs);
    if (filteredJobs.isEmpty) {
      if (_urgentOnly) {
        return const EmptyStateWidget(
          title: 'لا توجد طلبات عاجلة الآن',
          subtitle: 'يمكنك إلغاء فلتر العاجل لرؤية كل الطلبات',
          icon: Icons.alarm_off_rounded,
        );
      }
      return const EmptyStateWidget(
        title: 'لا توجد طلبات قريبة',
        subtitle: 'سنقوم بإخطارك عند توفر طلبات جديدة في منطقتك',
        icon: Icons.search_off_rounded,
      );
    }

    final priorityJob = _pickPriorityJob(filteredJobs, currentLocation);
    final listLimit = _nearbyCardMode == _NearbyCardMode.compact ? 4 : 3;
    final listJobs = priorityJob == null
        ? filteredJobs.take(listLimit).toList()
        : filteredJobs
              .where((job) => job.id != priorityJob.id)
              .take(listLimit)
              .toList();
    final shownCount = listJobs.length + (priorityJob == null ? 0 : 1);
    final hiddenCount = (filteredJobs.length - shownCount).clamp(0, 999);

    return Column(
      children: [
        if (noticeMessage != null) ...[
          _buildRealtimeNoticeCard(
            message: noticeMessage,
            isWarning: noticeWarning,
          ),
          SizedBox(height: 12.h),
        ],
        _buildQueueHealthStrip(filteredJobs),
        SizedBox(height: 12.h),
        if (priorityJob != null) ...[
          _buildPriorityHeroCard(priorityJob, currentLocation: currentLocation),
          SizedBox(height: 12.h),
        ],
        ...listJobs.map(
          (job) => Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: _buildJobCard(
              job,
              currentLocation: currentLocation,
              compact: _nearbyCardMode == _NearbyCardMode.compact,
            ),
          ),
        ),
        if (hiddenCount > 0) _buildMoreJobsHint(hiddenCount),
      ],
    );
  }

  Widget _buildPriorityHeroCard(Job job, {Position? currentLocation}) {
    final hasCoordinates = job.lat != 0 && job.lng != 0;
    final serviceName = job.service?['name'] ?? 'خدمة';
    final customerName = job.customer?['full_name'] ?? 'عميل';
    final addressText = job.addressText ?? 'موقع غير محدد';
    final waitLabel = _formatWaitingTime(job.createdAt);
    final distanceText = currentLocation == null
        ? null
        : '${(_distanceMeters(currentLocation: currentLocation, jobLat: job.lat, jobLng: job.lng) / 1000).toStringAsFixed(1)} كم';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Colors.red.withValues(alpha: 0.14),
            Theme.of(context).cardColor.withValues(alpha: 0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.red.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.priority_high_rounded, color: Colors.red, size: 20.s),
              SizedBox(width: 6.w),
              Text(
                'أولوية قصوى',
                style: TextStyle(
                  fontSize: 13.fz,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const Spacer(),
              Text(
                waitLabel,
                style: TextStyle(
                  fontSize: 12.fz,
                  color: Colors.red,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            serviceName,
            style: TextStyle(fontSize: 16.fz, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 2.h),
          Text(
            customerName,
            style: TextStyle(
              fontSize: 13.fz,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 16.s, color: Colors.blue),
              SizedBox(width: 4.w),
              Expanded(
                child: Text(
                  addressText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.fz, color: Colors.blue[700]),
                ),
              ),
              if (distanceText != null) ...[
                SizedBox(width: 8.w),
                Icon(Icons.route, size: 16.s, color: Colors.blue),
                SizedBox(width: 4.w),
                Text(
                  distanceText,
                  style: TextStyle(
                    fontSize: 12.fz,
                    color: Colors.blue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openBidding(job.id),
                  icon: const Icon(Icons.local_offer_outlined),
                  label: const Text('تقديم عرض'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 10.h),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              OutlinedButton.icon(
                onPressed: hasCoordinates
                    ? () => _openLocationInMaps(job.lat, job.lng, addressText)
                    : null,
                icon: Icon(Icons.map_outlined, size: 18.s),
                label: const Text('الموقع'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMoreJobsHint(int hiddenCount) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: 2.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        'يوجد $hiddenCount طلبات إضافية. افتح "عرض الكل" لإدارتها بسرعة.',
        style: TextStyle(
          fontSize: 12.fz,
          color: Theme.of(context).textTheme.bodySmall?.color,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildSortControls(Position? currentLocation) {
    return Wrap(
      spacing: 8.w,
      runSpacing: 6.h,
      children: [
        ChoiceChip(
          label: const Text('الأحدث'),
          selected: _nearbySortMode == _NearbySortMode.newest,
          onSelected: (_) {
            setState(() {
              _nearbySortMode = _NearbySortMode.newest;
            });
          },
        ),
        ChoiceChip(
          label: const Text('الأقرب'),
          selected: _nearbySortMode == _NearbySortMode.closest,
          onSelected: currentLocation == null
              ? null
              : (_) {
                  setState(() {
                    _nearbySortMode = _NearbySortMode.closest;
                  });
                },
        ),
        FilterChip(
          label: const Text('عاجل فقط'),
          selected: _urgentOnly,
          onSelected: (selected) {
            setState(() {
              _urgentOnly = selected;
            });
          },
          selectedColor: Colors.red.withValues(alpha: 0.18),
          checkmarkColor: Colors.red,
        ),
        FilterChip(
          label: const Text('عرض مختصر'),
          selected: _nearbyCardMode == _NearbyCardMode.compact,
          onSelected: (selected) {
            setState(() {
              _nearbyCardMode = selected
                  ? _NearbyCardMode.compact
                  : _NearbyCardMode.detailed;
            });
          },
        ),
      ],
    );
  }

  Widget _buildFocusCard({required int nearbyJobsCount}) {
    final title = !_isOnline
        ? 'فعّل الاتصال لتبدأ استقبال الطلبات'
        : nearbyJobsCount == 0
        ? 'لا يوجد طلب مناسب الآن'
        : nearbyJobsCount == 1
        ? 'لديك طلب واحد مناسب الآن'
        : 'ابدأ بأعلى طلب مناسب ثم راجع الباقي';
    final description = !_isOnline
        ? 'لن تظهر لك الطلبات الجديدة حتى تعود إلى وضع متصل من مؤشر الحالة أدناه.'
        : nearbyJobsCount == 0
        ? 'أبقِ التطبيق مفتوحًا وتابع حالة الاتصال، وستظهر الطلبات الجديدة هنا تلقائيًا.'
        : nearbyJobsCount == 1
        ? 'راجع تفاصيل الطلب الظاهر وقدّم عرضًا سريعًا إذا كان مناسبًا لك.'
        : 'اعرض البطاقة الأولى أولًا، ثم استخدم الفرز فقط إذا أردت تغيير ترتيب الأولوية.';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: KadmatColors.lightBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44.w,
            height: 44.w,
            decoration: BoxDecoration(
              color: KadmatColors.brandAccent,
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Icon(
              _isOnline ? Icons.track_changes_rounded : Icons.wifi_off_rounded,
              color: KadmatColors.brandSecondary,
              size: 20.s,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15.fz,
                    fontWeight: FontWeight.w800,
                    color: KadmatColors.lightTextPrimary,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12.5.fz,
                    height: 1.55,
                    color: KadmatColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueHealthStrip(List<Job> jobs) {
    if (jobs.isEmpty) return const SizedBox.shrink();
    final now = DateTime.now();
    final agesInMinutes = jobs
        .map((job) => now.difference(job.createdAt).inMinutes.clamp(0, 1440))
        .toList();
    final totalAge = agesInMinutes.fold<int>(0, (sum, age) => sum + age);
    final avgAge = (totalAge / agesInMinutes.length).round();
    final maxAge = agesInMinutes.fold<int>(
      0,
      (max, age) => age > max ? age : max,
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildQueueMetric(
              title: 'متاح الآن',
              value: '${jobs.length}',
              icon: Icons.badge_outlined,
            ),
          ),
          Expanded(
            child: _buildQueueMetric(
              title: 'متوسط الانتظار',
              value: avgAge < 1 ? 'أقل من دقيقة' : '$avgAge د',
              icon: Icons.timelapse,
            ),
          ),
          Expanded(
            child: _buildQueueMetric(
              title: 'أطول انتظار',
              value: maxAge < 1 ? 'أقل من دقيقة' : '$maxAge د',
              icon: Icons.schedule,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueMetric({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Column(
      children: [
        Icon(icon, size: 16.s, color: Theme.of(context).primaryColor),
        SizedBox(height: 4.h),
        Text(
          title,
          style: TextStyle(
            fontSize: 11.fz,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 2.h),
        Text(
          value,
          style: TextStyle(fontSize: 12.fz, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _friendlyLocationToggleError(Object error) {
    final normalized = error.toString().toLowerCase();
    if (normalized.contains('permission')) {
      return 'تعذر تشغيل الحالة المتصلة. يرجى السماح بالموقع من إعدادات الجهاز.';
    }
    if (normalized.contains('socketexception') ||
        normalized.contains('failed host lookup')) {
      return 'لا يوجد اتصال بالإنترنت حالياً.';
    }
    return 'تعذر تحديث الحالة الآن. حاول مرة أخرى.';
  }

  Widget _buildJobCard(
    Job job, {
    Position? currentLocation,
    bool compact = false,
  }) {
    final normalizedStatus = JobStatus.normalize(job.status);
    final isUrgent = _isUrgentJob(job);
    final waitLabel = _formatWaitingTime(job.createdAt);
    final distanceText = currentLocation == null
        ? null
        : '${(_distanceMeters(currentLocation: currentLocation, jobLat: job.lat, jobLng: job.lng) / 1000).toStringAsFixed(1)} كم';

    // Extract service name
    final serviceName = job.service?['name'] ?? 'خدمة';

    // Extract customer name
    final customerName = job.customer?['full_name'] ?? 'عميل';

    // Extract location info
    final addressText = job.addressText ?? 'موقع غير محدد';
    final hasCoordinates = job.lat != 0 && job.lng != 0;
    final avatarSize = compact ? 40.w : 48.w;
    final avatarRadius = compact ? 20.r : 24.r;

    return Container(
      padding: EdgeInsets.all(compact ? 12.w : 16.w),
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
              // Customer Avatar with Caching
              ClipRRect(
                borderRadius: BorderRadius.circular(avatarRadius),
                child: job.customer?['avatar_url'] != null
                    ? CachedNetworkImage(
                        imageUrl: job.customer!['avatar_url'],
                        width: avatarSize,
                        height: avatarSize,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Theme.of(context).primaryColor,
                          child: Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 24.s,
                          ),
                        ),
                      )
                    : CircleAvatar(
                        radius: avatarRadius,
                        backgroundColor: Theme.of(context).primaryColor,
                        child: Icon(
                          Icons.person,
                          color: Colors.white,
                          size: compact ? 20.s : 24.s,
                        ),
                      ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customerName,
                      style: TextStyle(
                        fontSize: compact ? 14.fz : 16.fz,
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
                              fontSize: compact ? 12.fz : 13.fz,
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
                  color: isUrgent
                      ? Colors.red.withValues(alpha: 0.12)
                      : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  isUrgent
                      ? 'عاجل'
                      : <String>{
                          JobStatus.pending,
                          JobStatus.searching,
                          JobStatus.noTechnicianFound,
                        }.contains(normalizedStatus)
                      ? 'جديد'
                      : 'قيد التنفيذ',
                  style: TextStyle(
                    color: isUrgent ? Colors.red : Colors.orange,
                    fontSize: 12.fz,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 12.h),

          // Description / Problem Summary
          if (!compact &&
              job.description != null &&
              job.description!.isNotEmpty) ...[
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
          if (compact)
            Row(
              children: [
                Icon(Icons.location_on, size: 18.s, color: Colors.blue),
                SizedBox(width: 6.w),
                Expanded(
                  child: Text(
                    addressText,
                    style: TextStyle(fontSize: 12.fz, color: Colors.blue[700]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            )
          else
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
                      style: TextStyle(
                        fontSize: 13.fz,
                        color: Colors.blue[700],
                      ),
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
                (job.initialPrice != null && job.initialPrice! > 0)
                    ? '${job.initialPrice!.toStringAsFixed(0)} د.ل'
                    : 'غير محدد',
                style: TextStyle(
                  fontSize: 15.fz,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Icon(Icons.schedule, size: 16.s, color: Colors.orange),
              SizedBox(width: 4.w),
              Text(
                waitLabel,
                style: TextStyle(
                  fontSize: 12.fz,
                  color: Colors.orange,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (distanceText != null) ...[
                Icon(Icons.route, size: 16.s, color: Colors.blue),
                SizedBox(width: 4.w),
                Text(
                  distanceText,
                  style: TextStyle(
                    fontSize: 12.fz,
                    color: Colors.blue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
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
                  onPressed: () => _openBidding(job.id),
                  icon: const Icon(Icons.local_offer_outlined),
                  label: Text(compact ? 'عرض' : 'تقديم عرض'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isUrgent ? Colors.red : Colors.green,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      vertical: compact ? 10.h : 12.h,
                    ),
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
                  icon: Icon(Icons.map_outlined, size: compact ? 18.s : 20.s),
                  label: Text(compact ? 'خريطة' : 'الموقع'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                    side: BorderSide(
                      color: hasCoordinates ? Colors.blue : Colors.grey,
                    ),
                    padding: EdgeInsets.symmetric(
                      vertical: compact ? 10.h : 12.h,
                    ),
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
        if (!mounted) return;
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
    } catch (e) {
      debugPrint('Error opening maps: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح تطبيق الخرائط على هذا الجهاز')),
      );
    }
  }
}
