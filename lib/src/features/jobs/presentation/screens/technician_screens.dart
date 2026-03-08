import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/widgets/kadmat_toast.dart';
import '../../../../core/utils/error_handler.dart';
import '../../data/job_repository.dart';
import '../../domain/job.dart';
import '../../domain/job_status.dart';
import '../widgets/job_widgets.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../controllers/job_polling_controller.dart'; // import job polling controller
import '../../../../core/navigation/app_routes.dart'; // Add import

class TechnicianAcceptedScreen extends ConsumerStatefulWidget {
  final String jobId;

  const TechnicianAcceptedScreen({super.key, required this.jobId});

  @override
  ConsumerState<TechnicianAcceptedScreen> createState() =>
      _TechnicianAcceptedScreenState();
}

class _TechnicianAcceptedScreenState
    extends ConsumerState<TechnicianAcceptedScreen> {
  Job? _job;

  @override
  void initState() {
    super.initState();
    _fetchJob();
  }

  Future<void> _fetchJob() async {
    try {
      final job = await ref
          .read(jobRepositoryProvider)
          .getJobById(widget.jobId);
      if (mounted) setState(() => _job = job);
    } catch (e) {
      // Ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('تم قبول الطلب'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _job == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(24.w),
              child: Column(
                children: [
                  // Success Badge
                  Container(
                    padding: EdgeInsets.all(24.w),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check, color: Colors.green, size: 60.s),
                  ),

                  SizedBox(height: 24.h),

                  Text(
                    'تم قبول الطلب بنجاح! ✅',
                    style: TextStyle(
                      fontSize: 22.fz,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  SizedBox(height: 8.h),

                  Text(
                    'قم بتحديد السعر للعميل',
                    style: TextStyle(fontSize: 16.fz, color: Colors.white60),
                  ),

                  SizedBox(height: 32.h),

                  // Timeline
                  JobTimeline(currentStatus: _job!.status),

                  SizedBox(height: 24.h),

                  // Customer Card
                  if (_job?.customer != null)
                    ProfileCard(
                      name: _job!.customer?['full_name'],
                      phone: _job!.customer?['phone'],
                      imageUrl: _job!.customer?['profile_image_url'],
                      rating: (_job!.customer?['rating'] as num?)?.toDouble(),
                      label: 'العميل',
                    ),

                  SizedBox(height: 24.h),

                  // Job Details
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: AppTheme.glassDecoration(radius: 16.r),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.home_repair_service,
                              color: AppTheme.primaryColor,
                              size: 24.s,
                            ),
                            SizedBox(width: 12.w),
                            Text(
                              _job?.service?['name'] ?? 'خدمة',
                              style: TextStyle(
                                fontSize: 18.fz,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12.h),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              color: Colors.white54,
                              size: 20.s,
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Text(
                                _job?.addressText ?? '',
                                style: TextStyle(
                                  fontSize: 14.fz,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_job?.description != null &&
                            _job!.description!.isNotEmpty) ...[
                          SizedBox(height: 12.h),
                          Text(
                            _job!.description!,
                            style: TextStyle(
                              fontSize: 14.fz,
                              color: Colors.white60,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  SizedBox(height: 32.h),

                  // Set Price Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => context.go(
                        AppRoutes.buildTechnicianSetPricePath(widget.jobId),
                      ),
                      icon: const Icon(Icons.attach_money),
                      label: Text(
                        'تحديد السعر',
                        style: TextStyle(
                          fontSize: 18.fz,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Technician Waiting Screen - Shows waiting state while customer reviews price
class TechnicianWaitingScreen extends ConsumerStatefulWidget {
  final String jobId;

  const TechnicianWaitingScreen({super.key, required this.jobId});

  @override
  ConsumerState<TechnicianWaitingScreen> createState() =>
      _TechnicianWaitingScreenState();
}

class _TechnicianWaitingScreenState
    extends ConsumerState<TechnicianWaitingScreen> {
  ProviderSubscription<AsyncValue<Job?>>? _jobStatusSubscription;

  @override
  void initState() {
    super.initState();
    _setupJobStatusListener();
  }

  @override
  void dispose() {
    _jobStatusSubscription?.close();
    super.dispose();
  }

  void _setupJobStatusListener() {
    _jobStatusSubscription = ref.listenManual<AsyncValue<Job?>>(
      jobStreamProvider(widget.jobId),
      (_, next) {
        final job = next.valueOrNull;
        if (job == null || !mounted) return;

        final normalized = JobStatus.normalize(job.status);
        if (normalized == JobStatus.onTheWay ||
            normalized == JobStatus.arrived ||
            normalized == JobStatus.inProgress) {
          debugPrint('🚀 Job ${job.id} is ready, navigating to work screen...');
          context.go(AppRoutes.buildTechnicianInProgressPath(widget.jobId));
          return;
        }

        if (job.status == 'cancelled') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إلغاء الطلب من العميل'),
              backgroundColor: Colors.red,
            ),
          );
          context.go(AppRoutes.home);
        }
      },
      fireImmediately: true,
    );
  }

  String _friendlyWaitingError(Object error) {
    final normalized = error.toString().toLowerCase();
    if (normalized.contains('socketexception') ||
        normalized.contains('failed host lookup')) {
      return 'لا يوجد اتصال بالإنترنت حالياً.';
    }
    if (normalized.contains('invalidjwttoken') ||
        normalized.contains('jwt') ||
        normalized.contains('expired')) {
      return 'انتهت الجلسة. يرجى تسجيل الدخول مرة أخرى.';
    }
    return 'تعذر تحديث حالة الطلب الآن. حاول التحديث بعد لحظات.';
  }

  @override
  Widget build(BuildContext context) {
    // Watch real-time job stream
    final jobAsync = ref.watch(jobStreamProvider(widget.jobId));

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('بانتظار موافقة العميل'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.technicianHome),
        ),
      ),
      body: jobAsync.when(
        data: (job) {
          if (job == null) {
            return const Center(child: Text('جاري تحميل بيانات الطلب...'));
          }
          return SingleChildScrollView(
            padding: EdgeInsets.all(24.w),
            child: Column(
              children: [
                // Waiting Animation
                Container(
                  padding: EdgeInsets.all(32.w),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.hourglass_top,
                    color: Colors.amber,
                    size: 60.s,
                  ),
                ),

                SizedBox(height: 24.h),

                Text(
                  'بانتظار موافقة العميل...',
                  style: TextStyle(
                    fontSize: 20.fz,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                SizedBox(height: 8.h),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'العميل يراجع السعر',
                      style: TextStyle(fontSize: 14.fz, color: Colors.white60),
                    ),
                    SizedBox(width: 4.w),
                    _buildAnimatedDots(),
                  ],
                ),

                SizedBox(height: 32.h),

                // Timeline
                JobTimeline(currentStatus: job.status),

                SizedBox(height: 24.h),

                // Price Card
                PriceCard(
                  proposedPrice: job.technicianPrice,
                  showBreakdown: true,
                ),

                SizedBox(height: 24.h),

                // Customer Card
                if (job.customer != null)
                  ProfileCard(
                    name: job.customer?['full_name'],
                    phone: job.customer?['phone'],
                    imageUrl: job.customer?['profile_image_url'],
                    rating: (job.customer?['rating'] as num?)?.toDouble(),
                    label: 'العميل',
                  ),

                SizedBox(height: 32.h),

                // Action Buttons
                OutlinedButton.icon(
                  onPressed: () => context.go(
                    AppRoutes.buildTechnicianSetPricePath(widget.jobId),
                  ),
                  icon: const Icon(Icons.edit),
                  label: const Text('تعديل السعر'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white54),
                    padding: EdgeInsets.symmetric(
                      vertical: 14.h,
                      horizontal: 24.w,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: EdgeInsets.all(20.w),
            child: Text(
              _friendlyWaitingError(error),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.fz, color: Colors.white70),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedDots() {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: 3),
      duration: const Duration(seconds: 1),
      builder: (context, value, child) {
        return Text(
          '.' * ((DateTime.now().second % 3) + 1),
          style: TextStyle(fontSize: 14.fz, color: Colors.white60),
        );
      },
    );
  }
}

/// Technician In Progress Screen - Shows job in progress with complete button
class TechnicianInProgressScreen extends ConsumerStatefulWidget {
  final String jobId;

  const TechnicianInProgressScreen({super.key, required this.jobId});

  @override
  ConsumerState<TechnicianInProgressScreen> createState() =>
      _TechnicianInProgressScreenState();
}

class _TechnicianInProgressScreenState
    extends ConsumerState<TechnicianInProgressScreen> {
  Job? _job;
  bool _isLoading = false;
  String? _errorMessage;
  List<String> _prePhotos = [];
  List<String> _postPhotos = [];
  final MapController _mapController = MapController();
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _fetchJob();
    _fetchPhotos();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_job?.priceConfirmedAt != null &&
          JobStatus.normalize(_job?.status ?? '') == JobStatus.inProgress) {
        setState(() {
          _elapsed = DateTime.now().difference(_job!.priceConfirmedAt!);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchJob() async {
    setState(() => _errorMessage = null);
    try {
      final job = await ref
          .read(jobRepositoryProvider)
          .getJobById(widget.jobId);
      if (mounted) {
        setState(() {
          _job = job;
          if (job != null && job.priceConfirmedAt != null) {
            _elapsed = DateTime.now().difference(job.priceConfirmedAt!);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'فشل تحميل تفاصيل الطلب');
      }
    }
  }

  Future<void> _updateProgress(
    String progress, {
    required String title,
    required String message,
  }) async {
    setState(() => _isLoading = true);
    try {
      await ref
          .read(jobRepositoryProvider)
          .updateTechnicianProgress(widget.jobId, progress: progress);

      await _fetchJob();

      if (!mounted) return;
      KadmatToast.showSuccess(context, title: title, message: message);
    } catch (e) {
      if (!mounted) return;
      KadmatToast.showError(
        context,
        title: 'خطأ',
        message: ErrorHandler.getMessage(e),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markArrived() {
    return _updateProgress(
      'arrived',
      title: 'تم تحديث الحالة',
      message: 'تم تسجيل وصولك إلى موقع العميل.',
    );
  }

  Future<void> _startWork() {
    return _updateProgress(
      'start_work',
      title: 'بدء العمل',
      message: 'تم بدء تنفيذ الخدمة.',
    );
  }

  Future<void> _fetchPhotos() async {
    try {
      final photos = await ref
          .read(jobRepositoryProvider)
          .getJobPhotos(widget.jobId);
      if (mounted) {
        setState(() {
          _prePhotos = photos['pre'] ?? [];
          _postPhotos = photos['post'] ?? [];
        });
      }
    } catch (e) {
      debugPrint('Error fetching photos: $e');
    }
  }

  Future<void> _completeJob() async {
    if (_postPhotos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى رفع صور بعد الخدمة أولاً'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Navigate to completion input screen
    context.push(AppRoutes.buildTechnicianCompleteWorkInputPath(widget.jobId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('تنفيذ الخدمة'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _fetchJob();
              _fetchPhotos();
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48.s, color: Colors.orange),
            SizedBox(height: 16.h),
            Text(
              _errorMessage!,
              style: TextStyle(color: Colors.white, fontSize: 16.fz),
            ),
            SizedBox(height: 24.h),
            ElevatedButton.icon(
              onPressed: () {
                _fetchJob();
                _fetchPhotos();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      );
    }

    if (_job == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }

    final normalizedStatus = JobStatus.normalize(_job!.status);

    return RefreshIndicator(
      onRefresh: () async {
        await _fetchJob();
        await _fetchPhotos();
      },
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Job Header with Map
            _buildJobMapHeader(),
            SizedBox(height: 16.h),

            if (normalizedStatus == JobStatus.onTheWay)
              Padding(
                padding: EdgeInsets.only(bottom: 16.h),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _markArrived,
                    icon: const Icon(Icons.place),
                    label: const Text('وصلت إلى موقع العميل'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                    ),
                  ),
                ),
              ),

            if (normalizedStatus == JobStatus.arrived)
              Padding(
                padding: EdgeInsets.only(bottom: 24.h),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _startWork,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('بدء العمل'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                    ),
                  ),
                ),
              ),

            // Timer Display
            if (normalizedStatus == JobStatus.inProgress)
              Container(
                width: double.infinity,
                margin: EdgeInsets.only(bottom: 24.h),
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Text(
                      'وقت العمل',
                      style: TextStyle(color: Colors.blue, fontSize: 14.fz),
                    ),
                    Text(
                      _formatDuration(_elapsed),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32.fz,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),

            // Step Header (retained logic)
            _buildJobHeader(),
            SizedBox(height: 24.h),

            // Steps
            _buildStep(
              step: 1,
              title: 'صور قبل الخدمة',
              isCompleted: _prePhotos.isNotEmpty,
              isActive: true,
              content: _buildPhotoSection(
                type: 'pre',
                photos: _prePhotos,
                onAdd: () async {
                  await context.push(
                    AppRoutes.buildTechnicianPrePhotosPath(widget.jobId),
                  );
                  _fetchPhotos();
                },
              ),
            ),
            _buildConnector(isCompleted: _prePhotos.isNotEmpty),

            _buildStep(
              step: 2,
              title: 'تنفيذ العمل',
              isCompleted: _postPhotos.isNotEmpty,
              isActive: _prePhotos.isNotEmpty,
              content: _prePhotos.isNotEmpty
                  ? Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: AppTheme.glassDecoration(radius: 12.r),
                      child: Row(
                        children: [
                          Icon(Icons.handyman, color: Colors.amber, size: 24.s),
                          SizedBox(width: 12.w),
                          Text(
                            'العمل جاري...',
                            style: TextStyle(
                              fontSize: 16.fz,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            _buildConnector(isCompleted: _postPhotos.isNotEmpty),

            _buildStep(
              step: 3,
              title: 'صور بعد الخدمة',
              isCompleted: _postPhotos.isNotEmpty,
              isActive: _prePhotos.isNotEmpty,
              content: _buildPhotoSection(
                type: 'post',
                photos: _postPhotos,
                onAdd: () async {
                  await context.push(
                    AppRoutes.buildTechnicianPostPhotosPath(widget.jobId),
                  );
                  _fetchPhotos();
                },
                isLocked: _prePhotos.isEmpty,
              ),
            ),

            SizedBox(height: 32.h),

            // Finish Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_isLoading || _postPhotos.isEmpty)
                    ? null
                    : _completeJob,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  disabledBackgroundColor: Colors.grey[800],
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : Text(
                        'إنهاء الخدمة وبدء الدفع',
                        style: TextStyle(
                          fontSize: 18.fz,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            SizedBox(height: 40.h),
          ],
        ),
      ),
    );
  }

  Widget _buildJobHeader() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: AppTheme.glassDecoration(radius: 16.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.build_circle,
                color: AppTheme.primaryColor,
                size: 28.s,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _job?.service?['name'] ?? 'تفاصيل الخدمة',
                      style: TextStyle(
                        fontSize: 18.fz,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'رقم الطلب #${_job?.id.substring(0, 5)}',
                      style: TextStyle(fontSize: 12.fz, color: Colors.white54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_job?.description != null) ...[
            Divider(color: Colors.white24, height: 24.h),
            Text(
              _job!.description!,
              style: TextStyle(fontSize: 14.fz, color: Colors.white70),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStep({
    required int step,
    required String title,
    required bool isCompleted,
    required bool isActive,
    required Widget content,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32.w,
              height: 32.w,
              decoration: BoxDecoration(
                color: isCompleted
                    ? Colors.green
                    : (isActive ? AppTheme.primaryColor : Colors.grey[800]),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive ? Colors.white : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Center(
                child: isCompleted
                    ? Icon(Icons.check, color: Colors.white, size: 18.s)
                    : Text(
                        '$step',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14.fz,
                        ),
                      ),
              ),
            ),
            SizedBox(width: 12.w),
            Text(
              title,
              style: TextStyle(
                fontSize: 16.fz,
                fontWeight: FontWeight.bold,
                color: isActive ? Colors.white : Colors.white38,
              ),
            ),
          ],
        ),
        if (isActive || isCompleted) ...[
          Container(
            margin: EdgeInsets.only(
              right: 15.w, // Center with the circle
              top: 8.h,
            ),
            padding: EdgeInsets.only(right: 24.w),
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: Colors.white24, width: 2.w),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.only(bottom: 16.h),
              child: content,
            ),
          ),
        ] else
          SizedBox(height: 16.h),
      ],
    );
  }

  Widget _buildConnector({required bool isCompleted}) {
    return Container(
      height: 20.h,
      margin: EdgeInsets.only(right: 15.w),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: isCompleted ? Colors.green : Colors.grey[800]!,
            width: 2.w,
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoSection({
    required String type,
    required List<String> photos,
    required VoidCallback onAdd,
    bool isLocked = false,
  }) {
    if (isLocked) {
      return Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          children: [
            Icon(Icons.lock, color: Colors.white38, size: 20.s),
            SizedBox(width: 8.w),
            Text(
              'أكمل الخطوة السابقة أولاً',
              style: TextStyle(color: Colors.white38, fontSize: 14.fz),
            ),
          ],
        ),
      );
    }

    if (photos.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 100.h,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length + 1,
              separatorBuilder: (_, __) => SizedBox(width: 8.w),
              itemBuilder: (context, index) {
                if (index == photos.length) {
                  return GestureDetector(
                    onTap: onAdd,
                    child: Container(
                      width: 80.w,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Icon(
                        Icons.add_a_photo,
                        color: Colors.white60,
                        size: 24.s,
                      ),
                    ),
                  );
                }
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8.r),
                  child: Image.network(
                    photos[index],
                    width: 100.w,
                    height: 100.h,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        width: 100.w,
                        height: 100.h,
                        color: Colors.grey[800],
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                : null,
                            strokeWidth: 2,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      debugPrint('❌ Error loading photo: $error');
                      debugPrint('📸 Photo URL: ${photos[index]}');
                      return Container(
                        width: 100.w,
                        height: 100.h,
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.broken_image,
                              color: Colors.grey[600],
                              size: 30.s,
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              'خطأ',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 10.fz,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            '${photos.length} صور تم رفعها',
            style: TextStyle(fontSize: 12.fz, color: Colors.green),
          ),
        ],
      );
    }

    return OutlinedButton.icon(
      onPressed: onAdd,
      icon: const Icon(Icons.camera_alt),
      label: Text(type == 'pre' ? 'إضافة صور وتفاصيل' : 'إضافة صور الإنجاز'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white54),
        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
      ),
    );
  }

  Widget _buildJobMapHeader() {
    if (_job == null) return const SizedBox.shrink();

    return Container(
      height: 200.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.r),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(_job!.lat, _job!.lng),
                initialZoom: 14.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.kadmat.app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(_job!.lat, _job!.lng),
                      width: 40.s,
                      height: 40.s,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black26, blurRadius: 4),
                          ],
                        ),
                        child: Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 24.s,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // Map Overlay Gradient
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 60.h,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black54, Colors.transparent],
                  ),
                ),
              ),
            ),
            // Navigate Button
            Positioned(
              bottom: 12.h,
              left: 12.w,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Open Google Maps
                },
                icon: const Icon(Icons.directions, size: 16),
                label: const Text('توجيه'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 8.h,
                  ),
                  textStyle: TextStyle(fontSize: 12.fz),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }
}

/// Technician Completed Screen - Shows earnings summary
class TechnicianCompletedScreen extends ConsumerStatefulWidget {
  final String jobId;

  const TechnicianCompletedScreen({super.key, required this.jobId});

  @override
  ConsumerState<TechnicianCompletedScreen> createState() =>
      _TechnicianCompletedScreenState();
}

class _TechnicianCompletedScreenState
    extends ConsumerState<TechnicianCompletedScreen> {
  Job? _job;

  @override
  void initState() {
    super.initState();
    _fetchJob();
  }

  Future<void> _fetchJob() async {
    try {
      final job = await ref
          .read(jobRepositoryProvider)
          .getJobById(widget.jobId);
      if (mounted) setState(() => _job = job);
    } catch (e) {
      // Ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    final price = _job?.finalPrice ?? _job?.technicianPrice ?? 0;
    final commission = price * 0.10;
    final earnings = price - commission;

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('تم الإنهاء'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _job == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(24.w),
              child: Column(
                children: [
                  // Success Badge
                  Container(
                    padding: EdgeInsets.all(24.w),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.green.withValues(alpha: 0.3),
                          Colors.teal.withValues(alpha: 0.3),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.celebration,
                      color: Colors.amber,
                      size: 60.s,
                    ),
                  ),

                  SizedBox(height: 24.h),

                  Text(
                    'ممتاز! أنهيت الخدمة 🎉',
                    style: TextStyle(
                      fontSize: 24.fz,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  SizedBox(height: 32.h),

                  // Earnings Card (Prominent)
                  Container(
                    padding: EdgeInsets.all(24.w),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.green.withValues(alpha: 0.2),
                          Colors.green.withValues(alpha: 0.1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'أرباحك من هذه الخدمة',
                          style: TextStyle(
                            fontSize: 14.fz,
                            color: Colors.white60,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          earnings.toStringAsFixed(0),
                          style: TextStyle(
                            fontSize: 56.fz,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        Text(
                          'ريال سعودي',
                          style: TextStyle(
                            fontSize: 18.fz,
                            color: Colors.green,
                          ),
                        ),
                        SizedBox(height: 16.h),
                        Divider(color: Colors.green.withValues(alpha: 0.3)),
                        SizedBox(height: 12.h),
                        _buildRow('سعر الخدمة', price),
                        SizedBox(height: 8.h),
                        _buildRow(
                          'عمولة المنصة (10%)',
                          commission,
                          isNegative: true,
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 24.h),

                  // Customer Card
                  if (_job?.customer != null)
                    ProfileCard(
                      name: _job!.customer?['full_name'],
                      phone: _job!.customer?['phone'],
                      imageUrl: _job!.customer?['profile_image_url'],
                      rating: (_job!.customer?['rating'] as num?)?.toDouble(),
                      label: 'العميل',
                      showContactButtons: false,
                    ),

                  SizedBox(height: 32.h),

                  // Action Buttons
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => context.go(AppRoutes.technicianHome),
                      icon: const Icon(Icons.work),
                      label: const Text('عرض المزيد من الطلبات'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 12.h),

                  OutlinedButton.icon(
                    onPressed: () => context.go(AppRoutes.home),
                    icon: const Icon(Icons.home),
                    label: const Text('العودة للرئيسية'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white54),
                      padding: EdgeInsets.symmetric(
                        vertical: 14.h,
                        horizontal: 24.w,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildRow(String label, double amount, {bool isNegative = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14.fz, color: Colors.white70),
        ),
        Text(
          '${isNegative ? "-" : ""}${amount.toStringAsFixed(0)} ر.س',
          style: TextStyle(
            fontSize: 14.fz,
            color: isNegative ? Colors.red : Colors.white,
          ),
        ),
      ],
    );
  }
}
