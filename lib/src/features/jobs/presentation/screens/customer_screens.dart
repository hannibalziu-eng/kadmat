import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/navigation/job_flow_redirects.dart';
import '../../../../core/widgets/kadmat_toast.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/utils/service_name_formatter.dart';
import '../../../../core/utils/technician_summary.dart';
import '../../data/job_repository.dart';
import '../../domain/job.dart';
import '../../domain/job_status.dart';
import '../widgets/job_widgets.dart';
import '../widgets/technician_offer_identity.dart';

/// Customer Searching Screen - Shows animated search while finding technician
class CustomerSearchingScreen extends ConsumerStatefulWidget {
  final String jobId;

  const CustomerSearchingScreen({super.key, required this.jobId});

  @override
  ConsumerState<CustomerSearchingScreen> createState() =>
      _CustomerSearchingScreenState();
}

class _CustomerSearchingScreenState
    extends ConsumerState<CustomerSearchingScreen>
    with TickerProviderStateMixin {
  static const String _statusUpdatedRedirectMessage =
      'تم تحديث حالة الطلب، يتم نقلك للحالة الحالية';

  late AnimationController _pulseController;
  Timer? _pollTimer;
  Job? _job;
  StreamSubscription? _offersSubscription;
  List<Map<String, dynamic>> _offers = const [];
  String? _acceptingOfferId;
  bool _isCancelling = false;

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  bool _isValidUuid(String value) => _uuidRegex.hasMatch(value.trim());

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _startPolling();
    _startOffersListening();
  }

  void _startPolling() {
    _fetchJob();
    _pollTimer = Timer.periodic(const Duration(seconds: 6), (_) => _fetchJob());
  }

  void _startOffersListening() {
    _offersSubscription?.cancel();
    _offersSubscription = ref
        .read(jobRepositoryProvider)
        .watchJobOffers(widget.jobId)
        .listen((offers) {
          if (!mounted) return;
          offers.sort((a, b) {
            final aPrice = (a['price'] as num?)?.toDouble() ?? 0;
            final bPrice = (b['price'] as num?)?.toDouble() ?? 0;
            return aPrice.compareTo(bPrice);
          });
          setState(() {
            _offers = offers;
          });
        }, onError: (_) {});
  }

  Future<void> _fetchJob() async {
    try {
      final job = await ref
          .read(jobRepositoryProvider)
          .getJobById(widget.jobId);
      if (!mounted) return;

      setState(() {
        _job = job;
      });

      // Auto-navigate when the job leaves searching stage.
      final route = job == null
          ? null
          : customerRouteForJobStatus(status: job.status, jobId: widget.jobId);
      if (route != null) {
        _pollTimer?.cancel();
        context.go(route);
        return;
      }

      final normalizedStatus = job == null
          ? ''
          : JobStatus.normalize(job.status);
      if (normalizedStatus == JobStatus.cancelled) {
        _pollTimer?.cancel();
        context.go(AppRoutes.home);
      }
    } catch (e) {
      // Keep searching state visible; transient errors should not break flow.
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _pollTimer?.cancel();
    _offersSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final job = _job;
    if (job == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        appBar: AppBar(
          title: const Text('جاري البحث'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final lat = job.lat;
    final lng = job.lng;
    final searchRadius = (job.searchRadius ?? 3000).toDouble();
    final serviceName = formatServiceDisplayName(job.service);
    final rawExpectedPrice = job.initialPrice ?? job.customerOffer;
    final expectedPrice = (rawExpectedPrice != null && rawExpectedPrice > 0)
        ? rawExpectedPrice
        : null;
    final mediaCount = job.images?.length ?? 0;

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: Text(serviceName),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          Padding(
            padding: EdgeInsetsDirectional.only(end: 14.w),
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.55),
                  ),
                ),
                child: Text(
                  '${_offers.length} عرض',
                  style: TextStyle(
                    fontSize: 12.fz,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(14.w, 8.h, 14.w, 0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22.r),
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: LatLng(lat, lng),
                          initialZoom: _zoomForRadius(searchRadius),
                          interactionOptions: const InteractionOptions(
                            flags:
                                InteractiveFlag.drag |
                                InteractiveFlag.pinchZoom,
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                            subdomains: const ['a', 'b', 'c', 'd'],
                            retinaMode: true,
                            userAgentPackageName: 'com.kadmat.app',
                          ),
                          CircleLayer(
                            circles: [
                              CircleMarker(
                                point: LatLng(lat, lng),
                                radius: searchRadius,
                                useRadiusInMeter: true,
                                color: AppTheme.primaryColor.withValues(
                                  alpha: 0.12,
                                ),
                                borderColor: AppTheme.primaryColor.withValues(
                                  alpha: 0.65,
                                ),
                                borderStrokeWidth: 2,
                              ),
                            ],
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(lat, lng),
                                width: 60.w,
                                height: 60.h,
                                child: AnimatedBuilder(
                                  animation: _pulseController,
                                  builder: (context, child) {
                                    final scale =
                                        1 + (_pulseController.value * 0.15);
                                    return Transform.scale(
                                      scale: scale,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppTheme.primaryColor
                                              .withValues(alpha: 0.22),
                                        ),
                                        child: Icon(
                                          Icons.home_repair_service,
                                          color: Colors.white,
                                          size: 30.s,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    top: 20.h,
                    start: 28.w,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 8.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.55),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.radar,
                            size: 16.s,
                            color: AppTheme.primaryColor,
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            'بحث ضمن ${(searchRadius / 1000).toStringAsFixed(0)} كم',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.fz,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    start: 28.w,
                    end: 28.w,
                    bottom: 18.h,
                    child: _buildSearchSummaryCard(
                      address: job.addressText ?? 'الموقع الحالي',
                      expectedPrice: expectedPrice,
                      mediaCount: mediaCount,
                    ),
                  ),
                ],
              ),
            ),
            _buildOffersPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSummaryCard({
    required String address,
    required double? expectedPrice,
    required int mediaCount,
  }) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(Icons.location_on, color: AppTheme.primaryColor, size: 18.s),
          SizedBox(width: 6.w),
          Expanded(
            child: Text(
              address,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white, fontSize: 12.fz),
            ),
          ),
          if (expectedPrice != null) ...[
            SizedBox(width: 8.w),
            _buildInfoChip('متوقع ${expectedPrice.toStringAsFixed(0)} ر.س'),
          ],
          if (mediaCount > 0) ...[
            SizedBox(width: 8.w),
            _buildInfoChip('مرفقات $mediaCount'),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoChip(String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: AppTheme.primaryColor,
          fontSize: 11.fz,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildOffersPanel() {
    return Container(
      height: 300.h,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24.r),
          topRight: Radius.circular(24.r),
        ),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(16.w, 12.h, 16.w, 8.h),
            child: Row(
              children: [
                Text(
                  _offers.isEmpty ? 'جاري وصول العروض...' : 'عروض الفنيين',
                  style: TextStyle(
                    fontSize: 17.fz,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _cancelJob,
                  icon: const Icon(Icons.close, color: Colors.red),
                  label: Text(
                    'إلغاء الطلب',
                    style: TextStyle(color: Colors.red, fontSize: 13.fz),
                  ),
                ),
              ],
            ),
          ),
          if (_offers.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  'بانتظار عروض الفنيين القريبين',
                  style: TextStyle(color: Colors.white60, fontSize: 14.fz),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: EdgeInsetsDirectional.fromSTEB(16.w, 0, 16.w, 16.h),
                scrollDirection: Axis.horizontal,
                itemCount: _offers.length,
                separatorBuilder: (_, __) => SizedBox(width: 10.w),
                itemBuilder: (context, index) =>
                    _buildOfferCard(_offers[index], index),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOfferCard(Map<String, dynamic> offer, int index) {
    final tech = (offer['technician'] as Map<String, dynamic>?) ?? const {};
    final technician = TechnicianSummary.fromMap(tech);
    final technicianId = ((offer['technician_id'] ?? tech['id']) ?? '')
        .toString()
        .trim();
    final offerId = (offer['id'] ?? '').toString().trim();
    final price = (offer['price'] as num?)?.toDouble() ?? 0;
    final isBestPrice = index == 0;
    final isLoading = _acceptingOfferId == offerId;
    final isOfferIdValid = _isValidUuid(offerId);

    return Container(
      width: 320.w,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isBestPrice
              ? AppTheme.primaryColor.withValues(alpha: 0.8)
              : Colors.white.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22.r,
                backgroundColor: Colors.white10,
                backgroundImage: technician.profileImageUrl != null
                    ? NetworkImage(technician.profileImageUrl!)
                    : null,
                child: technician.profileImageUrl == null
                    ? Icon(Icons.person, color: Colors.white, size: 20.s)
                    : null,
              ),
              SizedBox(width: 10.w),
              Expanded(child: TechnicianOfferIdentity(technician: technician)),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  '${price.toStringAsFixed(0)} ر.س',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 15.fz,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          if (isBestPrice)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Text(
                'أفضل سعر حالياً',
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 11.fz,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: (technicianId.isEmpty || technicianId == 'null')
                      ? null
                      : () => _openTechnicianProfile(technicianId),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.28),
                    ),
                  ),
                  child: const Text('ملف الفني'),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: ElevatedButton(
                  onPressed: (isLoading || !isOfferIdValid)
                      ? null
                      : () => _acceptOffer(offerId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: isLoading
                      ? SizedBox(
                          width: 16.w,
                          height: 16.w,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(isOfferIdValid ? 'قبول العرض' : 'عرض غير صالح'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openTechnicianProfile(String technicianId) {
    final normalizedId = technicianId.trim();
    if (normalizedId.isEmpty || normalizedId == 'null') {
      KadmatToast.showWarning(
        context,
        title: 'تعذر فتح الملف',
        message: 'معرّف الفني غير صالح',
      );
      return;
    }

    final path = AppRoutes.buildTechnicianProfilePath(normalizedId);
    try {
      context.push(path);
    } catch (e) {
      KadmatToast.showError(
        context,
        title: 'تعذر فتح الملف',
        message: 'فشل الانتقال إلى ملف الفني. حاول مجددًا.',
      );
    }
  }

  Future<void> _cancelJob() async {
    if (_isCancelling) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('إلغاء الطلب', style: TextStyle(color: Colors.white)),
        content: const Text(
          'هل أنت متأكد من إلغاء الطلب؟',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('لا'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('نعم، إلغاء'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isCancelling = true);
      try {
        await ref.read(jobRepositoryProvider).cancelJob(widget.jobId);
        if (mounted) context.go(AppRoutes.home);
      } catch (e) {
        if (mounted) {
          ErrorHandler.handle(context, e);
        }
      } finally {
        if (mounted) setState(() => _isCancelling = false);
      }
    }
  }

  Future<void> _acceptOffer(String offerId) async {
    final normalizedOfferId = offerId.trim();
    if (_acceptingOfferId != null) return;
    if (!_isValidUuid(normalizedOfferId)) {
      KadmatToast.showWarning(
        context,
        title: 'تنبيه',
        message: 'معرّف العرض غير صالح، حدّث الصفحة وحاول مجددًا',
      );
      return;
    }

    setState(() => _acceptingOfferId = normalizedOfferId);
    try {
      final updatedJob = await ref
          .read(jobRepositoryProvider)
          .acceptOffer(widget.jobId, normalizedOfferId);
      if (!mounted) return;
      KadmatToast.showSuccess(
        context,
        title: 'تم قبول العرض',
        message: 'جاري الانتقال لمرحلة الفني المختار',
      );
      final route = customerRouteForJobStatus(
        status: updatedJob.status,
        jobId: widget.jobId,
      );
      context.go(route ?? AppRoutes.buildCustomerInProgressPath(widget.jobId));
    } on InvalidStatusException catch (e) {
      if (!mounted) return;
      final redirected = await _redirectToLatestCustomerJobState(
        hintedStatus: e.currentStatus,
      );
      if (redirected || !mounted) return;
      ErrorHandler.handle(context, e);
    } catch (e) {
      if (mounted) {
        final redirected = await _redirectToLatestCustomerJobState();
        if (redirected || !mounted) return;
        ErrorHandler.handle(context, e);
      }
    } finally {
      if (mounted) setState(() => _acceptingOfferId = null);
    }
  }

  Future<bool> _redirectToLatestCustomerJobState({String? hintedStatus}) async {
    final hintedRoute = hintedStatus == null
        ? null
        : customerRouteForJobStatus(status: hintedStatus, jobId: widget.jobId);
    if (hintedRoute != null) {
      _showStatusUpdatedNotice();
      context.go(hintedRoute);
      return true;
    }

    try {
      final latestJob = await ref
          .read(jobRepositoryProvider)
          .getJobById(widget.jobId);
      if (!mounted || latestJob == null) return false;

      final latestRoute = customerRouteForJobStatus(
        status: latestJob.status,
        jobId: widget.jobId,
      );
      if (latestRoute != null) {
        _showStatusUpdatedNotice();
        context.go(latestRoute);
        return true;
      }

      if (JobStatus.normalize(latestJob.status) == JobStatus.cancelled) {
        context.go(AppRoutes.home);
        return true;
      }
    } catch (_) {
      return false;
    }

    return false;
  }

  void _showStatusUpdatedNotice() {
    if (!mounted) return;
    KadmatToast.showInfo(
      context,
      title: 'تحديث الحالة',
      message: _statusUpdatedRedirectMessage,
    );
  }

  double _zoomForRadius(double radiusMeters) {
    if (radiusMeters <= 2000) return 14.5;
    if (radiusMeters <= 5000) return 13.0;
    if (radiusMeters <= 10000) return 12.2;
    return 11.5;
  }
}

/// Customer Technician Found Screen - Shows technician details after acceptance
class CustomerTechnicianFoundScreen extends ConsumerStatefulWidget {
  final String jobId;

  const CustomerTechnicianFoundScreen({super.key, required this.jobId});

  @override
  ConsumerState<CustomerTechnicianFoundScreen> createState() =>
      _CustomerTechnicianFoundScreenState();
}

class _CustomerTechnicianFoundScreenState
    extends ConsumerState<CustomerTechnicianFoundScreen> {
  Timer? _pollTimer;
  Job? _job;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    _fetchJob();
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) => _fetchJob());
  }

  Future<void> _fetchJob() async {
    try {
      final job = await ref
          .read(jobRepositoryProvider)
          .getJobById(widget.jobId);
      if (!mounted) return;

      setState(() => _job = job);

      // Auto-navigate when price is set
      if (job != null && job.status == 'price_pending') {
        _pollTimer?.cancel();
        context.go(AppRoutes.buildCustomerPriceOfferPath(widget.jobId));
      }
    } catch (e) {
      // Ignore errors
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('تم العثور على فني'),
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
                    'تم قبول طلبك! ✨',
                    style: TextStyle(
                      fontSize: 24.fz,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  SizedBox(height: 8.h),

                  Text(
                    'الفني يقوم بتحديد السعر...',
                    style: TextStyle(fontSize: 16.fz, color: Colors.white60),
                  ),

                  SizedBox(height: 32.h),

                  // Timeline
                  JobTimeline(currentStatus: _job!.status),

                  SizedBox(height: 24.h),

                  // Technician Card
                  if (_job?.technician != null)
                    ProfileCard(
                      name: _job!.technician?['full_name'],
                      phone: _job!.technician?['phone'],
                      imageUrl: _job!.technician?['profile_image_url'],
                      rating: (_job!.technician?['rating'] as num?)?.toDouble(),
                      label: 'الفني',
                    ),

                  SizedBox(height: 24.h),

                  // Job Status Badge
                  JobStatusBadge(status: _job!.status),
                ],
              ),
            ),
    );
  }
}

/// Customer Price Offer Screen - Shows technician's price for confirmation
class CustomerPriceOfferScreen extends ConsumerStatefulWidget {
  final String jobId;

  const CustomerPriceOfferScreen({super.key, required this.jobId});

  @override
  ConsumerState<CustomerPriceOfferScreen> createState() =>
      _CustomerPriceOfferScreenState();
}

class _CustomerPriceOfferScreenState
    extends ConsumerState<CustomerPriceOfferScreen> {
  Job? _job;
  bool _isLoading = false;

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

  Future<void> _confirmPrice() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(jobRepositoryProvider).confirmPrice(widget.jobId);
      if (mounted) {
        KadmatToast.showSuccess(
          context,
          title: 'تم قبول السعر',
          message: '✅ الفني في الطريق إليك!',
        );
        context.go(AppRoutes.buildCustomerInProgressPath(widget.jobId));
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.handle(context, e);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _rejectPrice() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('رفض السعر', style: TextStyle(color: Colors.white)),
        content: const Text(
          'هل تريد إلغاء الطلب والبحث عن فني آخر؟',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('نعم، ارفض'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref
          .read(jobRepositoryProvider)
          .cancelJob(widget.jobId, reason: 'رفض السعر');
      if (mounted) context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('عرض السعر'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _job == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(24.w),
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long,
                    color: AppTheme.primaryColor,
                    size: 60.s,
                  ),

                  SizedBox(height: 24.h),

                  Text(
                    'عرض سعر من الفني',
                    style: TextStyle(
                      fontSize: 22.fz,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  SizedBox(height: 32.h),

                  // Price Card
                  PriceCard(
                    initialPrice: _job!.initialPrice,
                    proposedPrice: _job!.technicianPrice,
                    showBreakdown: false,
                  ),

                  SizedBox(height: 16.h),

                  // Price comparison
                  if (_job!.initialPrice != null &&
                      _job!.initialPrice! > 0 &&
                      _job!.technicianPrice != null)
                    Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: _job!.technicianPrice! <= _job!.initialPrice!
                            ? Colors.green.withValues(alpha: 0.2)
                            : Colors.orange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _job!.technicianPrice! <= _job!.initialPrice!
                                ? Icons.thumb_up
                                : Icons.info,
                            color: _job!.technicianPrice! <= _job!.initialPrice!
                                ? Colors.green
                                : Colors.orange,
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            _job!.technicianPrice! <= _job!.initialPrice!
                                ? 'السعر أقل أو يساوي السعر الابتدائي للخدمة'
                                : 'السعر أعلى من السعر الابتدائي للخدمة',
                            style: TextStyle(
                              color:
                                  _job!.technicianPrice! <= _job!.initialPrice!
                                  ? Colors.green
                                  : Colors.orange,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                  SizedBox(height: 24.h),

                  // Technician Card
                  if (_job?.technician != null)
                    ProfileCard(
                      name: _job!.technician?['full_name'],
                      phone: _job!.technician?['phone'],
                      imageUrl: _job!.technician?['profile_image_url'],
                      rating: (_job!.technician?['rating'] as num?)?.toDouble(),
                      label: 'الفني',
                    ),

                  SizedBox(height: 32.h),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : _rejectPrice,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: EdgeInsets.symmetric(vertical: 16.h),
                          ),
                          child: const Text('رفض'),
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _confirmPrice,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: EdgeInsets.symmetric(vertical: 16.h),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('قبول السعر'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

/// Customer In Progress Screen - Shows job in progress with timer
class CustomerInProgressScreen extends ConsumerStatefulWidget {
  final String jobId;

  const CustomerInProgressScreen({super.key, required this.jobId});

  @override
  ConsumerState<CustomerInProgressScreen> createState() =>
      _CustomerInProgressScreenState();
}

class _CustomerInProgressScreenState
    extends ConsumerState<CustomerInProgressScreen> {
  Timer? _pollTimer;
  Job? _job;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    _fetchJob();
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) => _fetchJob());
  }

  Future<void> _fetchJob() async {
    try {
      final job = await ref
          .read(jobRepositoryProvider)
          .getJobById(widget.jobId);
      if (!mounted) return;

      setState(() => _job = job);

      // Auto-navigate when job leaves in-progress stage.
      if (job != null) {
        final route = customerRouteForJobStatus(
          status: job.status,
          jobId: widget.jobId,
        );
        final inProgressRoute = AppRoutes.buildCustomerInProgressPath(
          widget.jobId,
        );
        if (route != null && route != inProgressRoute) {
          _pollTimer?.cancel();
          context.go(route);
        }
      }
    } catch (e) {
      // Ignore
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('جاري التنفيذ'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _job == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(24.w),
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(32.w),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.engineering,
                      color: Colors.blue,
                      size: 60.s,
                    ),
                  ),
                  SizedBox(height: 24.h),
                  Text(
                    'الفني يعمل على طلبك! 🔧',
                    style: TextStyle(
                      fontSize: 22.fz,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  if (_job?.priceConfirmedAt != null)
                    ElapsedTimer(startTime: _job!.priceConfirmedAt!),
                  SizedBox(height: 24.h),
                  JobTimeline(currentStatus: _job!.status),
                  SizedBox(height: 24.h),
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.attach_money, color: Colors.green),
                        SizedBox(width: 8.w),
                        Text(
                          'السعر المتفق عليه: ${_job!.finalPrice ?? _job!.technicianPrice ?? 0} ريال',
                          style: TextStyle(
                            fontSize: 16.fz,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24.h),
                  if (_job?.technician != null)
                    ProfileCard(
                      name: _job!.technician?['full_name'],
                      phone: _job!.technician?['phone'],
                      imageUrl: _job!.technician?['profile_image_url'],
                      rating: (_job!.technician?['rating'] as num?)?.toDouble(),
                      label: 'الفني',
                    ),
                ],
              ),
            ),
    );
  }
}

/// Customer Rate Screen - Allows customer to rate technician
class CustomerRateScreen extends ConsumerStatefulWidget {
  final String jobId;

  const CustomerRateScreen({super.key, required this.jobId});

  @override
  ConsumerState<CustomerRateScreen> createState() => _CustomerRateScreenState();
}

class _CustomerRateScreenState extends ConsumerState<CustomerRateScreen> {
  int _rating = 0;
  final _reviewController = TextEditingController();
  final List<String> _availableTags = [
    'محترف',
    'سريع',
    'نطيف',
    'تعامل راقي',
    'سعر ممتاز',
    'دقيق في المواعيد',
  ];
  final Set<String> _selectedTags = {};
  bool _isLoading = false;

  String? _buildReviewText() {
    String review = _reviewController.text;
    if (_selectedTags.isNotEmpty) {
      final tagsString = _selectedTags.map((t) => '#$t').join(' ');
      if (review.isNotEmpty) {
        review += '\n\n$tagsString';
      } else {
        review = tagsString;
      }
    }
    return review.isNotEmpty ? review : null;
  }

  Future<void> _submitRating() async {
    if (_rating == 0) {
      KadmatToast.showWarning(
        context,
        title: 'تنبيه',
        message: 'يرجى اختيار تقييم',
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref
          .read(jobRepositoryProvider)
          .rateJob(widget.jobId, _rating, review: _buildReviewText());
      if (mounted) {
        KadmatToast.showSuccess(
          context,
          title: 'شكراً على تقييمك!',
          message: '⭐ تم إرسال التقييم بنجاح',
        );
        context.go(AppRoutes.buildCustomerCompletedPath(widget.jobId));
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.handle(context, e);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('تقييم الخدمة'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24.w),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.done_all, color: Colors.teal, size: 60.s),
            ),
            SizedBox(height: 24.h),
            Text(
              'تم إنهاء الخدمة بنجاح! 🎉',
              style: TextStyle(
                fontSize: 22.fz,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'كيف كانت تجربتك مع الفني؟',
              style: TextStyle(fontSize: 16.fz, color: Colors.white60),
            ),
            SizedBox(height: 32.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return GestureDetector(
                  onTap: () => setState(() => _rating = index + 1),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.w),
                    child: Icon(
                      index < _rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 48.s,
                    ),
                  ),
                );
              }),
            ),
            SizedBox(height: 24.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              alignment: WrapAlignment.center,
              children: _availableTags.map((tag) {
                final isSelected = _selectedTags.contains(tag);
                return FilterChip(
                  label: Text(tag),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedTags.add(tag);
                      } else {
                        _selectedTags.remove(tag);
                      }
                    });
                  },
                  backgroundColor: Colors.white10,
                  selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                  checkmarkColor: AppTheme.primaryColor,
                  labelStyle: TextStyle(
                    color: isSelected ? AppTheme.primaryColor : Colors.white70,
                    fontSize: 12.fz,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.r),
                    side: BorderSide(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : Colors.white10,
                    ),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 32.h),
            Container(
              decoration: AppTheme.glassDecoration(radius: 12.r),
              child: TextField(
                controller: _reviewController,
                maxLines: 4,
                maxLength: 250,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'اكتب تعليقك هنا (اختياري)...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16.w),
                  counterStyle: const TextStyle(color: Colors.white38),
                ),
              ),
            ),
            SizedBox(height: 32.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitRating,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'إرسال التقييم',
                        style: TextStyle(
                          fontSize: 18.fz,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            SizedBox(height: 16.h),
            TextButton(
              onPressed: () => context.go(AppRoutes.home),
              child: Text(
                'تخطي',
                style: TextStyle(color: Colors.white60, fontSize: 16.fz),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Customer Completed Screen - Shows job summary
class CustomerCompletedScreen extends ConsumerStatefulWidget {
  final String jobId;

  const CustomerCompletedScreen({super.key, required this.jobId});

  @override
  ConsumerState<CustomerCompletedScreen> createState() =>
      _CustomerCompletedScreenState();
}

class _CustomerCompletedScreenState
    extends ConsumerState<CustomerCompletedScreen> {
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
        title: const Text('ملخص الطلب'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _job == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(24.w),
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(24.w),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryColor.withValues(alpha: 0.3),
                          Colors.teal.withValues(alpha: 0.3),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.verified,
                      color: Colors.white,
                      size: 60.s,
                    ),
                  ),
                  SizedBox(height: 24.h),
                  Text(
                    'تم الإنهاء بنجاح! 🎉',
                    style: TextStyle(
                      fontSize: 24.fz,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 32.h),
                  Container(
                    padding: EdgeInsets.all(20.w),
                    decoration: AppTheme.glassDecoration(radius: 16.r),
                    child: Column(
                      children: [
                        _buildRow(
                          'الخدمة',
                          formatServiceDisplayName(
                            _job!.service,
                            fallback: '-',
                          ),
                        ),
                        Divider(color: Colors.white24, height: 24.h),
                        _buildRow(
                          'السعر النهائي',
                          '${_job!.finalPrice ?? _job!.technicianPrice ?? 0} ريال',
                          valueColor: Colors.green,
                        ),
                        if (_job!.customerRating != null) ...[
                          Divider(color: Colors.white24, height: 24.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'تقييمك',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14.fz,
                                ),
                              ),
                              Row(
                                children: List.generate(
                                  5,
                                  (i) => Icon(
                                    i < (_job!.customerRating ?? 0)
                                        ? Icons.star
                                        : Icons.star_border,
                                    color: Colors.amber,
                                    size: 20.s,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: 24.h),
                  if (_job?.technician != null)
                    ProfileCard(
                      name: _job!.technician?['full_name'],
                      phone: _job!.technician?['phone'],
                      imageUrl: _job!.technician?['profile_image_url'],
                      rating: (_job!.technician?['rating'] as num?)?.toDouble(),
                      label: 'الفني',
                      showContactButtons: false,
                    ),
                  SizedBox(height: 32.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => context.go(AppRoutes.home),
                      icon: const Icon(Icons.home),
                      label: const Text('العودة للرئيسية'),
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

  Widget _buildRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white70, fontSize: 14.fz),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 16.fz,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
