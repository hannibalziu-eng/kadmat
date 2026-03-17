import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/design/kadmat_tokens.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/navigation/job_flow_redirects.dart';
import '../../../../core/widgets/kadmat_toast.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/utils/service_name_formatter.dart';
import '../../../../core/utils/technician_summary.dart';
import '../../../messages/presentation/chat_screen.dart';
import '../../data/job_repository.dart';
import '../../domain/job.dart';
import '../../domain/job_communication_policy.dart';
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
    final hasMapLocation = lat != 0 && lng != 0;
    final hasOffers = _offers.isNotEmpty;
    final isCatalogFixed = job.isCatalogFixed;
    final catalogSubtotal = job.effectiveCatalogSubtotal;
    final catalogItemCount = job.effectiveCatalogItemCount;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
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
                  color: KadmatColors.brandAccent,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: KadmatColors.brandPrimary.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  isCatalogFixed ? 'سعر ثابت' : '${_offers.length} عرض',
                  style: TextStyle(
                    fontSize: 12.fz,
                    fontWeight: FontWeight.w700,
                    color: KadmatColors.brandSecondary,
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
            Padding(
              padding: EdgeInsets.fromLTRB(18.w, 10.h, 18.w, 10.h),
              child: _buildSearchingHero(
                serviceName: serviceName,
                expectedPrice: expectedPrice,
                mediaCount: mediaCount,
                hasOffers: hasOffers,
                isCatalogFixed: isCatalogFixed,
                catalogSubtotal: catalogSubtotal,
                catalogItemCount: catalogItemCount,
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(18.w, 4.h, 18.w, 0),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: hasMapLocation
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(30.r),
                              child: FlutterMap(
                                options: MapOptions(
                                  initialCenter: LatLng(lat, lng),
                                  initialZoom: _zoomForRadius(searchRadius),
                                  interactionOptions: const InteractionOptions(
                                    flags:
                                        InteractiveFlag.drag |
                                        InteractiveFlag.pinchZoom |
                                        InteractiveFlag.doubleTapZoom,
                                  ),
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate:
                                        'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
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
                                          alpha: 0.08,
                                        ),
                                        borderColor: AppTheme.primaryColor
                                            .withValues(alpha: 0.32),
                                        borderStrokeWidth: 2,
                                      ),
                                    ],
                                  ),
                                  MarkerLayer(
                                    markers: [
                                      Marker(
                                        point: LatLng(lat, lng),
                                        width: 84.w,
                                        height: 84.h,
                                        child: AnimatedBuilder(
                                          animation: _pulseController,
                                          builder: (context, child) {
                                            final scale =
                                                1 +
                                                (_pulseController.value * 0.14);
                                            return Transform.scale(
                                              scale: scale,
                                              child: Center(
                                                child: Container(
                                                  width: 62.w,
                                                  height: 62.w,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    gradient:
                                                        const LinearGradient(
                                                          begin: Alignment
                                                              .topCenter,
                                                          end: Alignment
                                                              .bottomCenter,
                                                          colors: [
                                                            Color(0xFF2CC5F1),
                                                            Color(0xFF1299C5),
                                                          ],
                                                        ),
                                                    border: Border.all(
                                                      color: Colors.white,
                                                      width: 3,
                                                    ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: AppTheme
                                                            .primaryColor
                                                            .withValues(
                                                              alpha: 0.28,
                                                            ),
                                                        blurRadius: 18,
                                                        offset: const Offset(
                                                          0,
                                                          8,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  child: Icon(
                                                    Icons.home_repair_service,
                                                    color: Colors.white,
                                                    size: 26.s,
                                                  ),
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
                            )
                          : _buildPendingLocationCard(),
                    ),
                    PositionedDirectional(
                      top: 18.h,
                      start: 18.w,
                      child: _buildMapOverlayChip(
                        icon: Icons.radar,
                        label:
                            'بحث ضمن ${(searchRadius / 1000).toStringAsFixed(0)} كم',
                      ),
                    ),
                    PositionedDirectional(
                      top: 18.h,
                      end: 18.w,
                      child: _buildMapOverlayChip(
                        icon: isCatalogFixed
                            ? Icons.sell_outlined
                            : Icons.place_outlined,
                        label: isCatalogFixed
                            ? 'سعر ثابت'
                            : hasOffers
                            ? 'العروض وصلت'
                            : 'الخريطة نشطة',
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: IgnorePointer(
                        child: Container(
                          height: 132.h,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.vertical(
                              bottom: Radius.circular(30.r),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.white.withValues(alpha: 0.92),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildOffersPanel(
              job: job,
              address:
                  job.addressText ??
                  'سيتم تحديث موقع الطلب بعد تثبيت نقطة الخدمة',
              expectedPrice: expectedPrice,
              mediaCount: mediaCount,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchingHero({
    required String serviceName,
    required double? expectedPrice,
    required int mediaCount,
    required bool hasOffers,
    required bool isCatalogFixed,
    required double? catalogSubtotal,
    required int catalogItemCount,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 16.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24.r),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFEFF8FC), Color(0xFFDFF1F8)],
        ),
        border: Border.all(color: const Color(0xFFD5E7EE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46.w,
                height: 46.w,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: Icon(
                  Icons.radar_rounded,
                  size: 22.s,
                  color: AppTheme.primaryColor,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCatalogFixed
                          ? 'جاري إسناد الطلب الثابت'
                          : 'جاري البحث عن فني مناسب',
                      style: TextStyle(
                        color: KadmatColors.lightTextPrimary,
                        fontSize: 19.fz,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      isCatalogFixed
                          ? 'نبحث الآن عن فني مناسب لطلب $serviceName بالسعر الثابت المحدد. ستبقى الخريطة واضحة وسنحدّثك عند تثبيت الفني مباشرة.'
                          : hasOffers
                          ? 'وصلت عروض على طلب $serviceName. راجع الخريطة أولًا ثم اختر العرض الأنسب للمتابعة.'
                          : 'نبحث الآن عن أقرب الفنيين المناسبين لطلب $serviceName، وستظهر العروض هنا فور وصولها.',
                      style: TextStyle(
                        color: KadmatColors.lightTextSecondary,
                        fontSize: 12.2.fz,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              _buildInfoChip(
                isCatalogFixed
                    ? (catalogItemCount > 0
                          ? '$catalogItemCount عناصر مختارة'
                          : 'طلب ثابت')
                    : hasOffers
                    ? '${_offers.length} عروض وصلت'
                    : 'بانتظار أول عرض',
              ),
              if (isCatalogFixed && catalogSubtotal != null)
                _buildInfoChip(
                  'الإجمالي ${catalogSubtotal.toStringAsFixed(0)} د.ل',
                ),
              if (expectedPrice != null)
                _buildInfoChip(
                  'السعر المتوقع ${expectedPrice.toStringAsFixed(0)} د.ل',
                ),
              if (mediaCount > 0) _buildInfoChip('مرفقات $mediaCount'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMapOverlayChip({required IconData icon, required String label}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.14),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16.s, color: AppTheme.primaryColor),
          SizedBox(width: 6.w),
          Text(
            label,
            style: TextStyle(
              color: KadmatColors.lightTextPrimary,
              fontSize: 12.fz,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingLocationCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24.r),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFEAF5FA), Color(0xFFDCEFF7)],
        ),
        border: Border.all(color: const Color(0xFFD5E7EE)),
      ),
      padding: EdgeInsets.all(24.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72.w,
            height: 72.w,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.my_location_rounded,
              color: AppTheme.primaryColor,
              size: 34.s,
            ),
          ),
          SizedBox(height: 18.h),
          Text(
            'جار تثبيت نقطة البحث',
            style: TextStyle(
              fontSize: 20.fz,
              fontWeight: FontWeight.bold,
              color: KadmatColors.lightTextPrimary,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'سيتم تحديث الخريطة تلقائياً بمجرد وصول موقع الطلب الحقيقي. لن نعرض موقعاً افتراضياً.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.fz,
              color: KadmatColors.lightTextSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSummaryCard({
    required String address,
    required double? expectedPrice,
    required int mediaCount,
  }) {
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
          decoration: BoxDecoration(
            color: const Color(0xFFF7FAFD),
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: const Color(0xFFE0E8EC)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_on, color: AppTheme.primaryColor, size: 16.s),
              SizedBox(width: 5.w),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 210.w),
                child: Text(
                  address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: KadmatColors.lightTextPrimary,
                    fontSize: 11.8.fz,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (expectedPrice != null)
          _buildInfoChip('متوقع ${expectedPrice.toStringAsFixed(0)} د.ل'),
        if (mediaCount > 0) _buildInfoChip('مرفقات $mediaCount'),
      ],
    );
  }

  Widget _buildInfoChip(String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: KadmatColors.brandAccent,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.16),
        ),
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

  Widget _buildOffersPanel({
    required Job job,
    required String address,
    required double? expectedPrice,
    required int mediaCount,
  }) {
    if (job.isCatalogFixed) {
      final catalogSubtotal = job.effectiveCatalogSubtotal;
      final catalogItemCount = job.effectiveCatalogItemCount;
      return AnimatedContainer(
        duration: KadmatMotion.medium,
        curve: Curves.easeOutCubic,
        height: 196.h,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24.r),
            topRight: Radius.circular(24.r),
          ),
          border: Border(top: BorderSide(color: KadmatColors.lightBorder)),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 18.h),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FBFD),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: const Color(0xFFE0E8EC)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ننسق الطلب الثابت من أجلك',
                                style: TextStyle(
                                  fontSize: 15.5.fz,
                                  fontWeight: FontWeight.w800,
                                  color: KadmatColors.lightTextPrimary,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                'لا توجد عروض في هذا النوع من الطلبات. سنثبت الفني مباشرة ثم نأخذك تلقائيًا إلى المرحلة التالية.',
                                style: TextStyle(
                                  color: KadmatColors.lightTextSecondary,
                                  fontSize: 11.8.fz,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _cancelJob,
                          icon: const Icon(Icons.close, color: Colors.red),
                          label: Text(
                            'إلغاء الطلب',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 13.fz,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      children: [
                        _buildSearchSummaryCard(
                          address: address,
                          expectedPrice: expectedPrice,
                          mediaCount: mediaCount,
                        ),
                        if (catalogItemCount > 0)
                          _buildInfoChip('$catalogItemCount عناصر'),
                        if (catalogSubtotal != null)
                          _buildInfoChip(
                            'الإجمالي ${catalogSubtotal.toStringAsFixed(0)} د.ل',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final hasOffers = _offers.isNotEmpty;
    final panelHeight = hasOffers ? 308.h : 146.h;

    return AnimatedContainer(
      duration: KadmatMotion.medium,
      curve: Curves.easeOutCubic,
      height: panelHeight,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24.r),
          topRight: Radius.circular(24.r),
        ),
        border: Border(top: BorderSide(color: KadmatColors.lightBorder)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(16.w, 12.h, 16.w, 8.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasOffers
                                ? 'وصلت عروض جديدة'
                                : 'نراقب العروض من أجلك',
                            style: TextStyle(
                              fontSize: 15.5.fz,
                              fontWeight: FontWeight.w800,
                              color: KadmatColors.lightTextPrimary,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            hasOffers
                                ? 'اختر فنيًا واحدًا فقط. أبقينا الخريطة واضحة حتى تراجع الموقع أثناء المقارنة.'
                                : 'ستبقى الخريطة أمامك، وسنضيف أول عرض هنا فور وصوله بدون أن نغطيها.',
                            style: TextStyle(
                              color: KadmatColors.lightTextSecondary,
                              fontSize: 11.8.fz,
                              height: 1.45,
                            ),
                          ),
                          if (hasOffers) ...[
                            SizedBox(height: 10.h),
                            _buildSearchSummaryCard(
                              address: address,
                              expectedPrice: expectedPrice,
                              mediaCount: mediaCount,
                            ),
                          ],
                        ],
                      ),
                    ),
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
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FBFD),
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(color: const Color(0xFFE0E8EC)),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 14.h,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSearchSummaryCard(
                            address: address,
                            expectedPrice: expectedPrice,
                            mediaCount: mediaCount,
                          ),
                          SizedBox(height: 12.h),
                          Row(
                            children: [
                              Icon(
                                Icons.local_offer_outlined,
                                color: KadmatColors.lightTextSecondary,
                                size: 20.s,
                              ),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: Text(
                                  'بانتظار أول عرض من الفنيين القريبين.',
                                  style: TextStyle(
                                    color: KadmatColors.lightTextPrimary,
                                    fontSize: 13.fz,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (_offers.length == 1)
                Expanded(
                  child: Center(
                    child: SizedBox(
                      width: 360.w,
                      child: Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(
                          16.w,
                          0,
                          16.w,
                          16.h,
                        ),
                        child: _buildOfferCard(_offers.first, 0),
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsetsDirectional.fromSTEB(
                      16.w,
                      0,
                      16.w,
                      16.h,
                    ),
                    scrollDirection: Axis.horizontal,
                    itemCount: _offers.length,
                    separatorBuilder: (_, __) => SizedBox(width: 10.w),
                    itemBuilder: (context, index) =>
                        _buildOfferCard(_offers[index], index),
                  ),
                ),
            ],
          ),
        ),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isBestPrice
              ? AppTheme.primaryColor.withValues(alpha: 0.6)
              : const Color(0xFFDDE7EC),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22.r,
                backgroundColor: KadmatColors.brandAccent,
                backgroundImage: technician.profileImageUrl != null
                    ? NetworkImage(technician.profileImageUrl!)
                    : null,
                child: technician.profileImageUrl == null
                    ? Icon(
                        Icons.person,
                        color: KadmatColors.brandSecondary,
                        size: 20.s,
                      )
                    : null,
              ),
              SizedBox(width: 10.w),
              Expanded(child: TechnicianOfferIdentity(technician: technician)),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: KadmatColors.brandAccent,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  '${price.toStringAsFixed(0)} د.ل',
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
                  color: const Color(0xFF157A48),
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
                    side: const BorderSide(color: Color(0xFFD5E1E8)),
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
        backgroundColor: Colors.white,
        title: const Text(
          'إلغاء الطلب',
          style: TextStyle(color: Color(0xFF0C171C)),
        ),
        content: const Text(
          'هل أنت متأكد من إلغاء الطلب؟',
          style: TextStyle(color: Color(0xFF58727D)),
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

      // Auto-navigate when price is set for quote-based jobs only.
      if (job != null && !job.isCatalogFixed && job.status == 'price_pending') {
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
    final job = _job;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('تم العثور على فني'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: job == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 28.h),
              child: Column(
                children: [
                  _CustomerFlowHero(
                    icon: Icons.verified_rounded,
                    eyebrow: 'تم تثبيت الفني',
                    title: job.isCatalogFixed
                        ? 'تم تثبيت الفني على الطلب الثابت'
                        : 'تم العثور على فني مناسب',
                    subtitle: job.isCatalogFixed
                        ? 'تم تثبيت الفني على طلبك بالسعر الثابت المحدد مسبقًا. سننقلك تلقائيًا عندما يبدأ التوجّه أو ينتقل الطلب إلى المرحلة التالية.'
                        : 'لا تحتاج إلى إجراء الآن. ننتظر من الفني تحديد السعر أو الانتقال إلى المرحلة التالية، وسيتم نقلك تلقائيًا.',
                    bottom: Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      children: [
                        const _CustomerFlowPill(
                          icon: Icons.verified_user_outlined,
                          label: 'تم تثبيت الفني',
                        ),
                        _CustomerFlowPill(
                          icon: job.isCatalogFixed
                              ? Icons.sell_outlined
                              : Icons.receipt_long_outlined,
                          label: job.isCatalogFixed
                              ? '${job.effectiveRuntimePrice.toStringAsFixed(0)} د.ل ثابتة'
                              : 'بانتظار السعر',
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 18.h),
                  _CustomerFlowSurface(
                    child: _CustomerFlowNextStepCard(
                      icon: Icons.pause_circle_outline_rounded,
                      title: job.isCatalogFixed
                          ? 'الخطوة التالية: انتظر بدء التنفيذ'
                          : 'الخطوة التالية: انتظر السعر فقط',
                      description: job.isCatalogFixed
                          ? 'السعر ثابت ومثبت بالفعل. لا توجد عروض أو مراجعة سعر في هذه المرحلة، وسننقلك تلقائيًا بمجرد أن يبدأ الفني التوجّه أو التنفيذ.'
                          : 'الطلب مثبت الآن على فني واحد. سننقلك تلقائيًا إلى شاشة مراجعة السعر عند وصوله، لذلك لا تحتاج إلى التنقل بين الشاشات.',
                    ),
                  ),
                  SizedBox(height: 16.h),
                  _CustomerFlowSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ما الذي يحدث الآن؟',
                          style: TextStyle(
                            color: KadmatColors.lightTextPrimary,
                            fontSize: 18.fz,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          job.isCatalogFixed
                              ? 'سنتابع انتقال الطلب تلقائيًا عندما يبدأ الفني التوجّه أو التنفيذ، مع إبقاء السعر الثابت وملخص العناصر واضحين لك.'
                              : 'سنتابع نقل الطلب تلقائيًا بمجرد أن يحدد الفني السعر أو ينتقل إلى المرحلة التالية.',
                          style: TextStyle(
                            color: KadmatColors.lightTextSecondary,
                            fontSize: 12.5.fz,
                            height: 1.45,
                          ),
                        ),
                        SizedBox(height: 14.h),
                        JobTimeline(currentStatus: job.status),
                        if (job.isCatalogFixed) ...[
                          SizedBox(height: 14.h),
                          Wrap(
                            spacing: 8.w,
                            runSpacing: 8.h,
                            children: [
                              _CustomerFlowPill(
                                icon: Icons.shopping_bag_outlined,
                                label: '${job.effectiveCatalogItemCount} عناصر',
                              ),
                              _CustomerFlowPill(
                                icon: Icons.payments_outlined,
                                label:
                                    '${job.effectiveRuntimePrice.toStringAsFixed(0)} د.ل',
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (job.technician != null) ...[
                    SizedBox(height: 16.h),
                    _CustomerFlowSurface(
                      child: _CustomerFlowTechnicianCard(
                        heading: 'الفني المختار',
                        helperText:
                            'يمكنك مراجعة بيانات الفني الآن، وسيظهر التواصل والتنفيذ العملي في الخطوة التالية من الفلو.',
                        technician: job.technician!,
                      ),
                    ),
                  ],
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
        backgroundColor: Colors.white,
        title: Text(
          'رفض السعر',
          style: TextStyle(
            color: KadmatColors.lightTextPrimary,
            fontSize: 18.fz,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          'سيتم إلغاء هذا الطلب الحالي. استخدم هذا الخيار فقط إذا كان السعر غير مناسب لك.',
          style: TextStyle(
            color: KadmatColors.lightTextSecondary,
            fontSize: 13.fz,
            height: 1.5,
          ),
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
      try {
        await ref
            .read(jobRepositoryProvider)
            .cancelJob(widget.jobId, reason: 'رفض السعر');
        if (mounted) context.go(AppRoutes.home);
      } catch (e) {
        if (mounted) {
          ErrorHandler.handle(context, e);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = _job;
    final serviceName = formatServiceDisplayName(
      job?.service,
      fallback: 'الخدمة المطلوبة',
    );
    final proposedPrice = job?.effectiveRuntimePrice ?? 0;
    final referencePrice = job?.initialPrice ?? job?.customerOffer;
    final hasReferencePrice = referencePrice != null && referencePrice > 0;
    final comparisonDelta = hasReferencePrice
        ? proposedPrice - referencePrice
        : null;
    final isWithinReference = comparisonDelta != null && comparisonDelta <= 0;
    final isCatalogFixed = job?.isCatalogFixed ?? false;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('مراجعة السعر'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: job == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 28.h),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CustomerFlowHero(
                        icon: isCatalogFixed
                            ? Icons.sell_outlined
                            : Icons.receipt_long_rounded,
                        eyebrow: isCatalogFixed ? 'سعر ثابت' : 'قرار العميل',
                        title: isCatalogFixed
                            ? 'تفاصيل السعر الثابت'
                            : 'السعر جاهز للمراجعة',
                        subtitle: isCatalogFixed
                            ? 'هذا الطلب ثابت السعر، لذلك لا توجد خطوة قبول عرض أو رفضه. راجع الملخص فقط ثم تابع حالة التنفيذ من نفس الفلو.'
                            : 'أرسل الفني السعر النهائي بعد مراجعة حالة الخدمة في الموقع. راجع التفاصيل ثم قرر المتابعة أو الإلغاء.',
                        bottom: Wrap(
                          spacing: 8.w,
                          runSpacing: 8.h,
                          children: [
                            _CustomerFlowPill(
                              icon: Icons.work_outline_rounded,
                              label: serviceName,
                            ),
                            _CustomerFlowPill(
                              icon: Icons.attach_money_rounded,
                              label: '${proposedPrice.toStringAsFixed(0)} د.ل',
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16.h),
                      _CustomerFlowSurface(
                        child: _CustomerFlowNextStepCard(
                          icon: isCatalogFixed
                              ? Icons.visibility_outlined
                              : Icons.rule_folder_outlined,
                          title: isCatalogFixed
                              ? 'الخطوة التالية: تابع التنفيذ'
                              : 'القرار المطلوب الآن',
                          description: isCatalogFixed
                              ? 'لا يوجد قرار تسعير في هذا المسار. استخدم هذه الشاشة لمراجعة الملخص الثابت فقط، ثم تابع انتقال الطلب إلى التنفيذ.'
                              : 'اقبل السعر إذا كان مناسبًا لك وابدأ التنفيذ، أو ارفض فقط إذا كنت مستعدًا لإلغاء الطلب الحالي بالكامل.',
                        ),
                      ),
                      SizedBox(height: 16.h),
                      _CustomerFlowSurface(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isCatalogFixed
                                  ? 'تفاصيل السعر الثابت'
                                  : 'تفاصيل العرض',
                              style: TextStyle(
                                color: KadmatColors.lightTextPrimary,
                                fontSize: 18.fz,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 6.h),
                            Text(
                              isCatalogFixed
                                  ? 'هذا هو الملخص المثبت مع الطلب. لا توجد مقارنة عروض أو تفاوض في هذا المسار.'
                                  : 'كل ما تحتاجه للمقارنة واتخاذ قرار سريع بدون مفاجآت.',
                              style: TextStyle(
                                color: KadmatColors.lightTextSecondary,
                                fontSize: 12.5.fz,
                                height: 1.45,
                              ),
                            ),
                            SizedBox(height: 16.h),
                            Row(
                              children: [
                                Expanded(
                                  child: _CustomerFlowMetricTile(
                                    label: isCatalogFixed
                                        ? 'السعر الثابت'
                                        : 'السعر المرسل',
                                    value:
                                        '${proposedPrice.toStringAsFixed(0)} د.ل',
                                    tone: AppTheme.primaryColor,
                                  ),
                                ),
                                SizedBox(width: 10.w),
                                Expanded(
                                  child: _CustomerFlowMetricTile(
                                    label: isCatalogFixed
                                        ? 'عدد العناصر'
                                        : hasReferencePrice
                                        ? 'السعر المرجعي'
                                        : 'مرجع التسعير',
                                    value: isCatalogFixed
                                        ? '${job.effectiveCatalogItemCount}'
                                        : hasReferencePrice
                                        ? '${referencePrice.toStringAsFixed(0)} د.ل'
                                        : 'غير متوفر',
                                    tone: KadmatColors.stateInfo,
                                  ),
                                ),
                              ],
                            ),
                            if (!isCatalogFixed && comparisonDelta != null) ...[
                              SizedBox(height: 14.h),
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(14.w),
                                decoration: BoxDecoration(
                                  color:
                                      (isWithinReference
                                              ? KadmatColors.stateSuccess
                                              : KadmatColors.stateWarning)
                                          .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(18.r),
                                  border: Border.all(
                                    color:
                                        (isWithinReference
                                                ? KadmatColors.stateSuccess
                                                : KadmatColors.stateWarning)
                                            .withValues(alpha: 0.28),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isWithinReference
                                          ? Icons.thumb_up_alt_outlined
                                          : Icons.info_outline_rounded,
                                      color: isWithinReference
                                          ? KadmatColors.stateSuccess
                                          : KadmatColors.stateWarning,
                                      size: 20.s,
                                    ),
                                    SizedBox(width: 10.w),
                                    Expanded(
                                      child: Text(
                                        isWithinReference
                                            ? 'السعر ضمن أو أقل من السعر المرجعي المتوقع للخدمة.'
                                            : 'السعر أعلى من المرجع بمقدار ${comparisonDelta.toStringAsFixed(0)} د.ل، راجع التفاصيل قبل القبول.',
                                        style: TextStyle(
                                          color: isWithinReference
                                              ? const Color(0xFF1E7551)
                                              : const Color(0xFF935C1B),
                                          fontSize: 12.5.fz,
                                          fontWeight: FontWeight.w700,
                                          height: 1.45,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (!isCatalogFixed &&
                                job.priceNotes != null &&
                                job.priceNotes!.trim().isNotEmpty) ...[
                              SizedBox(height: 14.h),
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(14.w),
                                decoration: BoxDecoration(
                                  color: KadmatColors.brandAccent,
                                  borderRadius: BorderRadius.circular(18.r),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'ملاحظات الفني',
                                      style: TextStyle(
                                        color: KadmatColors.lightTextPrimary,
                                        fontSize: 12.fz,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(height: 6.h),
                                    Text(
                                      job.priceNotes!.trim(),
                                      style: TextStyle(
                                        color: KadmatColors.lightTextSecondary,
                                        fontSize: 12.5.fz,
                                        height: 1.55,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(height: 16.h),
                      if (job.technician != null)
                        _CustomerFlowSurface(
                          child: _CustomerFlowTechnicianCard(
                            heading: isCatalogFixed
                                ? 'الفني المثبت على الطلب'
                                : 'الفني الذي أرسل العرض',
                            helperText: isCatalogFixed
                                ? 'بمجرد أن يبدأ الفني التوجّه أو التنفيذ ستنتقل المتابعة الحية تلقائيًا من نفس الفلو.'
                                : 'سيبدأ التنفيذ والمتابعة الحية مباشرة بعد موافقتك على السعر.',
                            technician: job.technician!,
                          ),
                        ),
                      SizedBox(height: 16.h),
                      _CustomerFlowSurface(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isCatalogFixed ? 'قبل أن تتابع' : 'قبل أن تقرر',
                              style: TextStyle(
                                color: KadmatColors.lightTextPrimary,
                                fontSize: 18.fz,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 12.h),
                            if (isCatalogFixed) ...[
                              const _CustomerFlowBullet(
                                text:
                                    'هذا الطلب ثابت السعر، لذلك لا توجد عروض أو قبول سعر في هذه المرحلة.',
                              ),
                              SizedBox(height: 10.h),
                              const _CustomerFlowBullet(
                                text:
                                    'يمكنك استخدام هذه الشاشة كمرجع سريع للسعر الثابت وعدد العناصر فقط.',
                              ),
                              SizedBox(height: 10.h),
                              const _CustomerFlowBullet(
                                text:
                                    'ستنتقل المتابعة تلقائيًا عندما يبدأ الفني التوجّه أو التنفيذ.',
                              ),
                            ] else ...[
                              const _CustomerFlowBullet(
                                text:
                                    'قبول السعر ينقلك مباشرة إلى مرحلة تنفيذ الطلب والتتبع.',
                              ),
                              SizedBox(height: 10.h),
                              const _CustomerFlowBullet(
                                text:
                                    'رفض السعر يلغي هذا الطلب الحالي، وليس مجرد تجاهل العرض.',
                              ),
                              SizedBox(height: 10.h),
                              const _CustomerFlowBullet(
                                text:
                                    'إذا كانت لديك ملاحظة على التسعير، راجع ملاحظات الفني أولاً ثم قرر.',
                              ),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(height: 22.h),
                      if (isCatalogFixed)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => context.go(
                              AppRoutes.buildCustomerInProgressPath(
                                widget.jobId,
                              ),
                            ),
                            child: const Text('متابعة الطلب'),
                          ),
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isLoading ? null : _rejectPrice,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: KadmatColors.stateError,
                                  side: const BorderSide(
                                    color: KadmatColors.stateError,
                                  ),
                                  padding: EdgeInsets.symmetric(vertical: 16.h),
                                ),
                                child: const Text('رفض وإلغاء الطلب'),
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
                                    : const Text('قبول السعر والمتابعة'),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
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
    final job = _job;
    final serviceName = formatServiceDisplayName(
      job?.service,
      fallback: 'الخدمة المطلوبة',
    );
    final agreedPrice = job?.effectiveRuntimePrice ?? 0;
    final canUseCommunication =
        job?.technicianId != null &&
        job != null &&
        JobCommunicationPolicy.canUseJobCommunication(job);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('جاري التنفيذ'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: job == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 28.h),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CustomerFlowHero(
                        icon: Icons.engineering_rounded,
                        eyebrow: 'مرحلة التنفيذ',
                        title: 'الخدمة قيد التنفيذ الآن',
                        subtitle:
                            'يعمل الفني على طلبك حاليًا. ستنتقل هذه الشاشة تلقائيًا عندما يطلب الفني تأكيد الإكمال أو ينجز العمل.',
                        bottom: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (job.priceConfirmedAt != null)
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 14.w,
                                  vertical: 10.h,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(18.r),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.timer_outlined,
                                      color: Colors.white,
                                      size: 18.s,
                                    ),
                                    SizedBox(width: 8.w),
                                    ElapsedTimer(
                                      startTime: job.priceConfirmedAt!,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16.fz,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            SizedBox(height: 12.h),
                            Wrap(
                              spacing: 8.w,
                              runSpacing: 8.h,
                              children: [
                                _CustomerFlowPill(
                                  icon: Icons.work_outline_rounded,
                                  label: serviceName,
                                ),
                                _CustomerFlowPill(
                                  icon: Icons.attach_money_rounded,
                                  label:
                                      '${agreedPrice.toStringAsFixed(0)} د.ل متفق عليها',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16.h),
                      _CustomerFlowSurface(
                        child: _CustomerFlowNextStepCard(
                          icon: canUseCommunication
                              ? Icons.chat_bubble_outline_rounded
                              : Icons.visibility_outlined,
                          title: 'الخطوة التالية: راقب التنفيذ فقط',
                          description: canUseCommunication
                              ? 'لا تحتاج إلى قرار جديد الآن. راقب التقدم من هذه الشاشة واستخدم المحادثة فقط إذا احتجت توضيحًا سريعًا.'
                              : 'لا تحتاج إلى قرار جديد الآن. راقب التقدم من هذه الشاشة وسننقلك تلقائيًا عندما ينتقل الطلب للخطوة التالية.',
                        ),
                      ),
                      SizedBox(height: 16.h),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(18.w),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(26.r),
                          border: Border.all(color: KadmatColors.lightBorder),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'تقدم التنفيذ',
                              style: TextStyle(
                                color: KadmatColors.lightTextPrimary,
                                fontSize: 18.fz,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 6.h),
                            Text(
                              'هذا الشريط يلخص المرحلة الحالية ويبيّن ما هي الخطوة التالية المتوقعة.',
                              style: TextStyle(
                                color: KadmatColors.lightTextSecondary,
                                fontSize: 12.5.fz,
                                height: 1.45,
                              ),
                            ),
                            SizedBox(height: 14.h),
                            JobTimeline(currentStatus: job.status),
                          ],
                        ),
                      ),
                      SizedBox(height: 16.h),
                      _CustomerFlowSurface(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ملخص التنفيذ',
                              style: TextStyle(
                                color: KadmatColors.lightTextPrimary,
                                fontSize: 18.fz,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 14.h),
                            _CustomerFlowSummaryRow(
                              label: 'الخدمة',
                              value: serviceName,
                            ),
                            SizedBox(height: 10.h),
                            _CustomerFlowSummaryRow(
                              label: 'السعر المتفق عليه',
                              value: '${agreedPrice.toStringAsFixed(0)} د.ل',
                              valueColor: const Color(0xFF13795B),
                            ),
                            SizedBox(height: 10.h),
                            _CustomerFlowSummaryRow(
                              label: 'المرحلة الحالية',
                              valueWidget: JobStatusBadge(status: job.status),
                            ),
                            if (job.workNotes != null &&
                                job.workNotes!.trim().isNotEmpty) ...[
                              SizedBox(height: 14.h),
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(14.w),
                                decoration: BoxDecoration(
                                  color: KadmatColors.brandAccent,
                                  borderRadius: BorderRadius.circular(18.r),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'ملاحظات التنفيذ',
                                      style: TextStyle(
                                        color: KadmatColors.lightTextPrimary,
                                        fontSize: 12.fz,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(height: 6.h),
                                    Text(
                                      job.workNotes!.trim(),
                                      style: TextStyle(
                                        color: KadmatColors.lightTextSecondary,
                                        fontSize: 12.5.fz,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (job.technician != null) ...[
                        SizedBox(height: 16.h),
                        _CustomerFlowSurface(
                          child: _CustomerFlowTechnicianCard(
                            heading: 'الفني المنفذ للخدمة',
                            helperText:
                                'يمكنك الرجوع إلى المحادثة أثناء التنفيذ إذا احتجت توضيحًا سريعًا.',
                            technician: job.technician!,
                            actionLabel: canUseCommunication
                                ? 'فتح المحادثة'
                                : null,
                            onActionPressed: canUseCommunication
                                ? () => _openChat(job)
                                : null,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  void _openChat(Job job) {
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
    'نظيف',
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('تقييم الخدمة'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 28.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CustomerFlowHero(
              icon: Icons.star_rate_rounded,
              eyebrow: 'آخر خطوة',
              title: 'كيف كانت تجربتك؟',
              subtitle:
                  'قيّم جودة الخدمة حتى نحافظ على فنيين موثوقين ونحسن تجربة العميل في الطلبات القادمة.',
              bottom: _rating == 0
                  ? null
                  : _CustomerFlowPill(
                      icon: Icons.auto_awesome_rounded,
                      label: _ratingLabel(_rating),
                    ),
            ),
            SizedBox(height: 16.h),
            _CustomerFlowSurface(
              child: _CustomerFlowNextStepCard(
                icon: _rating == 0
                    ? Icons.touch_app_rounded
                    : Icons.send_outlined,
                title: _rating == 0
                    ? 'الخطوة التالية: اختر تقييمك'
                    : 'الخطوة التالية: أرسل التقييم',
                description: _rating == 0
                    ? 'ابدأ بالنجوم أولًا. لا تحتاج إلى كتابة ملاحظة إلا إذا كان لديك شيء مفيد تريد إضافته.'
                    : 'النجوم جاهزة الآن. يمكنك الإرسال مباشرة أو إضافة ملاحظة قصيرة قبل إنهاء الطلب.',
              ),
            ),
            SizedBox(height: 16.h),
            _CustomerFlowSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'اختر التقييم',
                    style: TextStyle(
                      color: KadmatColors.lightTextPrimary,
                      fontSize: 18.fz,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'اضغط على النجوم بحسب تقييمك للتجربة الكاملة، وليس فقط النتيجة النهائية.',
                    style: TextStyle(
                      color: KadmatColors.lightTextSecondary,
                      fontSize: 12.5.fz,
                      height: 1.45,
                    ),
                  ),
                  SizedBox(height: 18.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final isSelected = index < _rating;
                      return GestureDetector(
                        onTap: () => setState(() => _rating = index + 1),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.w),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: EdgeInsets.all(8.w),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.amber.withValues(alpha: 0.14)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                            child: Icon(
                              isSelected
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: Colors.amber,
                              size: 42.s,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),
            _CustomerFlowSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'وسم سريع للتجربة',
                    style: TextStyle(
                      color: KadmatColors.lightTextPrimary,
                      fontSize: 18.fz,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Wrap(
                    spacing: 8.w,
                    runSpacing: 8.h,
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
                        backgroundColor: Colors.white,
                        selectedColor: AppTheme.primaryColor.withValues(
                          alpha: 0.12,
                        ),
                        checkmarkColor: AppTheme.primaryColor,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? AppTheme.primaryColor
                              : KadmatColors.lightTextSecondary,
                          fontSize: 12.fz,
                          fontWeight: FontWeight.w700,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.r),
                          side: BorderSide(
                            color: isSelected
                                ? AppTheme.primaryColor
                                : KadmatColors.lightBorder,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),
            _CustomerFlowSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'أضف ملاحظة اختيارية',
                    style: TextStyle(
                      color: KadmatColors.lightTextPrimary,
                      fontSize: 18.fz,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'اكتب ما يفيدك فعلاً: الجودة، السرعة، الالتزام، أو أي نقطة تريد أن تظهر في التقييم.',
                    style: TextStyle(
                      color: KadmatColors.lightTextSecondary,
                      fontSize: 12.5.fz,
                      height: 1.45,
                    ),
                  ),
                  SizedBox(height: 14.h),
                  TextField(
                    controller: _reviewController,
                    maxLines: 4,
                    maxLength: 250,
                    decoration: const InputDecoration(
                      hintText: 'مثال: وصل الفني في الموعد وأنجز العمل بدقة.',
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 22.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitRating,
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
            Center(
              child: TextButton(
                onPressed: () => context.go(AppRoutes.home),
                child: Text(
                  'تخطي والعودة للرئيسية',
                  style: TextStyle(
                    color: KadmatColors.lightTextSecondary,
                    fontSize: 15.fz,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _ratingLabel(int rating) {
    switch (rating) {
      case 5:
        return 'تجربة ممتازة';
      case 4:
        return 'تجربة جيدة جدًا';
      case 3:
        return 'تجربة جيدة';
      case 2:
        return 'تجربة تحتاج تحسين';
      case 1:
        return 'تجربة غير مرضية';
      default:
        return 'بدون تقييم';
    }
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
    final job = _job;
    final serviceName = formatServiceDisplayName(
      job?.service,
      fallback: 'الخدمة المطلوبة',
    );
    final finalPrice = job?.effectiveRuntimePrice ?? 0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('ملخص الطلب'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: job == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 28.h),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CustomerFlowHero(
                        icon: Icons.verified_rounded,
                        eyebrow: 'تم الإغلاق بنجاح',
                        title: 'اكتمل الطلب',
                        subtitle:
                            'تم إغلاق الخدمة بنجاح وحفظ ملخصها داخل حسابك. يمكنك الرجوع لاحقًا لمراجعة النتائج أو بدء طلب جديد.',
                        bottom: Wrap(
                          spacing: 8.w,
                          runSpacing: 8.h,
                          children: [
                            _CustomerFlowPill(
                              icon: Icons.work_outline_rounded,
                              label: serviceName,
                            ),
                            _CustomerFlowPill(
                              icon: Icons.payments_outlined,
                              label: '${finalPrice.toStringAsFixed(0)} د.ل',
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16.h),
                      _CustomerFlowSurface(
                        child: const _CustomerFlowNextStepCard(
                          icon: Icons.home_outlined,
                          title: 'لا يوجد إجراء متبقٍ',
                          description:
                              'الطلب أُغلق بالكامل. راجع الملخص إذا أردت، ثم عد للرئيسية أو ابدأ طلبًا جديدًا عند الحاجة.',
                        ),
                      ),
                      SizedBox(height: 16.h),
                      _CustomerFlowSurface(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ملخص الخدمة',
                              style: TextStyle(
                                color: KadmatColors.lightTextPrimary,
                                fontSize: 18.fz,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 14.h),
                            _CustomerFlowSummaryRow(
                              label: 'الخدمة',
                              value: serviceName,
                            ),
                            SizedBox(height: 10.h),
                            _CustomerFlowSummaryRow(
                              label: 'السعر النهائي',
                              value: '${finalPrice.toStringAsFixed(0)} د.ل',
                              valueColor: const Color(0xFF13795B),
                            ),
                            if (job.paymentMethod != null &&
                                job.paymentMethod!.trim().isNotEmpty) ...[
                              SizedBox(height: 10.h),
                              _CustomerFlowSummaryRow(
                                label: 'طريقة الدفع',
                                value: job.paymentMethod!,
                              ),
                            ],
                            if (job.customerRating != null) ...[
                              SizedBox(height: 10.h),
                              _CustomerFlowSummaryRow(
                                label: 'تقييمك',
                                valueWidget: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: List.generate(
                                    5,
                                    (i) => Icon(
                                      i < job.customerRating!.round()
                                          ? Icons.star_rounded
                                          : Icons.star_border_rounded,
                                      color: Colors.amber,
                                      size: 18.s,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (job.customerReview != null &&
                          job.customerReview!.trim().isNotEmpty) ...[
                        SizedBox(height: 16.h),
                        _CustomerFlowSurface(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ملاحظتك على الخدمة',
                                style: TextStyle(
                                  color: KadmatColors.lightTextPrimary,
                                  fontSize: 18.fz,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 10.h),
                              Text(
                                job.customerReview!.trim(),
                                style: TextStyle(
                                  color: KadmatColors.lightTextSecondary,
                                  fontSize: 13.fz,
                                  height: 1.55,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (job.technician != null) ...[
                        SizedBox(height: 16.h),
                        _CustomerFlowSurface(
                          child: _CustomerFlowTechnicianCard(
                            heading: 'الفني الذي نفذ الخدمة',
                            helperText:
                                'البيانات تبقى محفوظة ضمن السجل حتى يسهل الرجوع إليها لاحقًا.',
                            technician: job.technician!,
                          ),
                        ),
                      ],
                      SizedBox(height: 22.h),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => context.go(AppRoutes.home),
                          icon: const Icon(Icons.home),
                          label: const Text('العودة للرئيسية'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _CustomerFlowHero extends StatelessWidget {
  const _CustomerFlowHero({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.bottom,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30.r),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [KadmatColors.heroPrimaryStart, KadmatColors.heroPrimaryEnd],
        ),
        boxShadow: [
          BoxShadow(
            color: KadmatColors.brandPrimary.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46.w,
            height: 46.w,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(18.r),
            ),
            child: Icon(icon, color: Colors.white, size: 22.s),
          ),
          SizedBox(height: 14.h),
          Text(
            eyebrow,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 12.fz,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24.fz,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.86),
              fontSize: 12.8.fz,
              height: 1.55,
            ),
          ),
          if (bottom != null) ...[SizedBox(height: 14.h), bottom!],
        ],
      ),
    );
  }
}

class _CustomerFlowPill extends StatelessWidget {
  const _CustomerFlowPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15.s),
          SizedBox(width: 6.w),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 220.w),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 11.5.fz,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerFlowSurface extends StatelessWidget {
  const _CustomerFlowSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: KadmatColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CustomerFlowMetricTile extends StatelessWidget {
  const _CustomerFlowMetricTile({
    required this.label,
    required this.value,
    required this.tone,
  });

  final String label;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: tone.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: KadmatColors.lightTextSecondary,
              fontSize: 11.5.fz,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            value,
            style: TextStyle(
              color: tone,
              fontSize: 19.fz,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerFlowNextStepCard extends StatelessWidget {
  const _CustomerFlowNextStepCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46.w,
          height: 46.w,
          decoration: BoxDecoration(
            color: KadmatColors.brandAccent,
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Icon(icon, color: KadmatColors.brandSecondary, size: 22.s),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: KadmatColors.lightTextPrimary,
                  fontSize: 15.fz,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                description,
                style: TextStyle(
                  color: KadmatColors.lightTextSecondary,
                  fontSize: 12.5.fz,
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CustomerFlowSummaryRow extends StatelessWidget {
  const _CustomerFlowSummaryRow({
    required this.label,
    this.value,
    this.valueWidget,
    this.valueColor,
  });

  final String label;
  final String? value;
  final Widget? valueWidget;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final trailing =
        valueWidget ??
        Text(
          value ?? '-',
          textAlign: TextAlign.end,
          style: TextStyle(
            color: valueColor ?? KadmatColors.lightTextPrimary,
            fontSize: 14.fz,
            fontWeight: FontWeight.w800,
          ),
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: KadmatColors.lightTextSecondary,
              fontSize: 12.5.fz,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(width: 16.w),
        Flexible(child: trailing),
      ],
    );
  }
}

class _CustomerFlowBullet extends StatelessWidget {
  const _CustomerFlowBullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8.w,
          height: 8.w,
          margin: EdgeInsets.only(top: 6.h),
          decoration: const BoxDecoration(
            color: AppTheme.primaryColor,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: KadmatColors.lightTextSecondary,
              fontSize: 12.8.fz,
              height: 1.55,
            ),
          ),
        ),
      ],
    );
  }
}

class _CustomerFlowTechnicianCard extends StatelessWidget {
  const _CustomerFlowTechnicianCard({
    required this.heading,
    required this.helperText,
    required this.technician,
    this.actionLabel,
    this.onActionPressed,
  });

  final String heading;
  final String helperText;
  final Map<String, dynamic> technician;
  final String? actionLabel;
  final VoidCallback? onActionPressed;

  @override
  Widget build(BuildContext context) {
    final name = technician['full_name']?.toString().trim();
    final phone = technician['phone']?.toString().trim();
    final imageUrl = technician['profile_image_url']?.toString();
    final rating = (technician['rating'] as num?)?.toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading,
          style: TextStyle(
            color: KadmatColors.lightTextPrimary,
            fontSize: 18.fz,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 6.h),
        Text(
          helperText,
          style: TextStyle(
            color: KadmatColors.lightTextSecondary,
            fontSize: 12.5.fz,
            height: 1.45,
          ),
        ),
        SizedBox(height: 14.h),
        Row(
          children: [
            CircleAvatar(
              radius: 28.r,
              backgroundColor: KadmatColors.brandAccent,
              backgroundImage: (imageUrl != null && imageUrl.isNotEmpty)
                  ? NetworkImage(imageUrl)
                  : null,
              child: (imageUrl == null || imageUrl.isEmpty)
                  ? Icon(
                      Icons.person_rounded,
                      color: KadmatColors.brandSecondary,
                      size: 28.s,
                    )
                  : null,
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (name?.isNotEmpty ?? false) ? name! : 'الفني',
                    style: TextStyle(
                      color: KadmatColors.lightTextPrimary,
                      fontSize: 16.fz,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    (phone?.isNotEmpty ?? false)
                        ? phone!
                        : 'بيانات التواصل ستظهر عند توفرها',
                    style: TextStyle(
                      color: KadmatColors.lightTextSecondary,
                      fontSize: 12.5.fz,
                    ),
                  ),
                  if (rating != null) ...[
                    SizedBox(height: 6.h),
                    Row(
                      children: [
                        Icon(
                          Icons.star_rounded,
                          color: Colors.amber,
                          size: 16.s,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          rating.toStringAsFixed(1),
                          style: TextStyle(
                            color: KadmatColors.lightTextPrimary,
                            fontSize: 12.5.fz,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (actionLabel != null && onActionPressed != null) ...[
          SizedBox(height: 14.h),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onActionPressed,
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              label: Text(actionLabel!),
            ),
          ),
        ],
      ],
    );
  }
}
