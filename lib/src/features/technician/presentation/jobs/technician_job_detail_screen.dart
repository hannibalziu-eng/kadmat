import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/design/kadmat_tokens.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/services/location/location_service.dart';
import '../../../../core/utils/job_location_formatter.dart';
import '../../../../core/widgets/kadmat_toast.dart';
import '../../../../core/widgets/shimmer_skeletons.dart';
import '../../../jobs/data/job_repository.dart';
import '../../../jobs/domain/job.dart';
import '../../../jobs/domain/job_communication_policy.dart';
import '../widgets/technician_flow_widgets.dart';

class TechnicianJobDetailScreen extends ConsumerStatefulWidget {
  final String jobId;

  const TechnicianJobDetailScreen({super.key, required this.jobId});

  @override
  ConsumerState<TechnicianJobDetailScreen> createState() =>
      _TechnicianJobDetailScreenState();
}

class _TechnicianJobDetailScreenState
    extends ConsumerState<TechnicianJobDetailScreen> {
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isLoading = false;
  StreamSubscription? _jobSubscription;
  Job? _job;
  List<String> _prePhotos = [];
  List<String> _postPhotos = [];

  @override
  void initState() {
    super.initState();
    _startListening();
    _fetchJob();
    _fetchPhotos();
  }

  Future<void> _fetchJob() async {
    try {
      final job = await ref
          .read(jobRepositoryProvider)
          .getJobById(widget.jobId);
      if (!mounted || job == null) return;
      setState(() => _job = job);
    } catch (_) {
      // Realtime stream keeps state eventually; ignore one-shot fetch failures.
    }
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
      debugPrint('Error fetching job photos: $e');
    }
  }

  void _startListening() {
    final jobRepo = ref.read(jobRepositoryProvider);
    _jobSubscription = jobRepo.watchJob(widget.jobId).listen((job) {
      if (mounted) {
        setState(() => _job = job);
      }
    });
  }

  @override
  void dispose() {
    _priceController.dispose();
    _notesController.dispose();
    _jobSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_job == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF2F6F7),
        appBar: AppBar(title: const Text('تفاصيل الطلب')),
        body: const DetailSkeleton(),
      );
    }

    final currentLocation = ref.watch(locationStreamProvider).valueOrNull;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F6F7),
      appBar: AppBar(
        title: const Text('تفاصيل الطلب'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 980.w),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TechnicianFlowHero(
                    icon: _detailHeroIcon(),
                    eyebrow: 'تفاصيل الطلب الحالية',
                    title: _detailHeroTitle(),
                    subtitle: _detailHeroSubtitle(),
                    bottom: Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      children: [
                        TechnicianFlowPill(
                          icon: _detailHeroIcon(),
                          label: _detailStatusLabel(),
                        ),
                        if ((_job!.service?['name'] ?? '')
                            .toString()
                            .isNotEmpty)
                          TechnicianFlowPill(
                            icon: Icons.build_circle_outlined,
                            label: (_job!.service?['name'] ?? 'الخدمة')
                                .toString(),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),
                  TechnicianFlowSurface(
                    child: TechnicianFlowNextStepCard(
                      icon: _detailNextStepIcon(),
                      title: _detailNextStepTitle(),
                      description: _detailNextStepDescription(),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  _buildStatusBadge(),
                  SizedBox(height: 12.h),
                  _buildInfoCard(
                    title: 'الخدمة المطلوبة',
                    icon: Icons.build_circle_outlined,
                    child: Text(
                      _job!.service?['name'] ?? 'خدمة',
                      style: TextStyle(
                        fontSize: 18.fz,
                        fontWeight: FontWeight.w800,
                        color: KadmatColors.lightTextPrimary,
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  _buildCustomerInfoCard(),
                  SizedBox(height: 12.h),
                  _buildInfoCard(
                    title: 'الموقع',
                    icon: Icons.location_on_outlined,
                    child: _buildLocationSection(currentLocation),
                  ),
                  if (_job!.description != null &&
                      _job!.description!.isNotEmpty) ...[
                    SizedBox(height: 12.h),
                    _buildInfoCard(
                      title: 'وصف المشكلة',
                      icon: Icons.description_outlined,
                      child: Text(
                        _job!.description!,
                        style: TextStyle(
                          fontSize: 14.fz,
                          color: KadmatColors.lightTextSecondary,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                  SizedBox(height: 12.h),
                  _buildPriceSummaryCard(),
                  if (_job?.images != null && _job!.images!.isNotEmpty) ...[
                    SizedBox(height: 18.h),
                    _buildPhotoGrid(
                      'صور المشكلة (من العميل)',
                      _job!.images!.map((e) => e.imageUrl).toList(),
                    ),
                  ],
                  if (_prePhotos.isNotEmpty) ...[
                    SizedBox(height: 18.h),
                    _buildPhotoGrid('صور قبل العمل', _prePhotos),
                  ],
                  if (_postPhotos.isNotEmpty) ...[
                    SizedBox(height: 18.h),
                    _buildPhotoGrid('صور بعد الإنجاز', _postPhotos),
                  ],
                  SizedBox(height: 18.h),
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationSection(Position? currentLocation) {
    final coordinateText = JobLocationFormatter.formatCoordinates(
      _job!.lat,
      _job!.lng,
    );
    final distanceLabel = JobLocationFormatter.compactDistanceLabel(
      currentLat: currentLocation?.latitude,
      currentLng: currentLocation?.longitude,
      jobLat: _job!.lat,
      jobLng: _job!.lng,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _job!.addressText?.trim().isNotEmpty == true
              ? _job!.addressText!
              : 'تم تثبيت موقع العميل على الخريطة',
          style: TextStyle(
            fontSize: 14.fz,
            color: KadmatColors.lightTextSecondary,
          ),
        ),
        SizedBox(height: 10.h),
        Container(
          height: 178.h,
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: KadmatColors.lightBorder),
          ),
          child: Stack(
            children: [
              FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(_job!.lat, _job!.lng),
                  initialZoom: 15,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
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
                        point: LatLng(_job!.lat, _job!.lng),
                        radius: 80,
                        useRadiusInMeter: true,
                        color: AppTheme.primaryColor.withValues(alpha: 0.12),
                        borderColor: AppTheme.primaryColor.withValues(
                          alpha: 0.45,
                        ),
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(_job!.lat, _job!.lng),
                        width: 56.w,
                        height: 56.h,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.95),
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.primaryColor),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x14000000),
                                blurRadius: 16,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.location_on,
                            color: AppTheme.primaryColor,
                            size: 28.s,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              PositionedDirectional(
                top: 12.h,
                start: 12.w,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(999.r),
                    border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.place_outlined,
                        size: 16.s,
                        color: AppTheme.primaryColor,
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        'موقع العميل',
                        style: TextStyle(
                          fontSize: 12.fz,
                          fontWeight: FontWeight.w700,
                          color: KadmatColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(12.w, 28.h, 12.w, 12.h),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.95),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Text(
                    JobLocationFormatter.distanceAndEtaText(
                      currentLat: currentLocation?.latitude,
                      currentLng: currentLocation?.longitude,
                      jobLat: _job!.lat,
                      jobLng: _job!.lng,
                    ),
                    style: TextStyle(
                      fontSize: 13.fz,
                      fontWeight: FontWeight.w600,
                      color: KadmatColors.lightTextPrimary,
                    ),
                  ),
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
            _buildLocationMetaChip(Icons.pin_drop_outlined, coordinateText),
            _buildLocationMetaChip(
              currentLocation == null ? Icons.gps_off : Icons.route,
              distanceLabel ?? 'فعّل الموقع لحساب المسافة',
            ),
          ],
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _openLocationInMaps,
                icon: const Icon(Icons.map_outlined),
                label: const Text('فتح في الخرائط'),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: TextButton.icon(
                onPressed: _copyCoordinates,
                icon: const Icon(Icons.content_copy_outlined),
                label: const Text('نسخ الإحداثيات'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLocationMetaChip(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: KadmatColors.brandAccent,
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: KadmatColors.lightBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15.s, color: AppTheme.primaryColor),
          SizedBox(width: 6.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.fz,
              color: KadmatColors.lightTextSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyCoordinates() async {
    if (_job == null) return;

    final coordinateText = JobLocationFormatter.formatCoordinates(
      _job!.lat,
      _job!.lng,
      decimals: 6,
    );
    await Clipboard.setData(ClipboardData(text: coordinateText));
    if (!mounted) return;
    KadmatToast.showSuccess(
      context,
      title: 'تم النسخ',
      message: 'تم نسخ إحداثيات موقع العميل',
    );
  }

  Future<void> _openLocationInMaps() async {
    if (_job == null) return;
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${_job!.lat},${_job!.lng}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    if (!mounted) return;
    KadmatToast.showError(
      context,
      title: 'تعذر الفتح',
      message: 'لا يمكن فتح تطبيق الخرائط على هذا الجهاز حالياً',
    );
  }

  Widget _buildStatusBadge() {
    final status = _job!.status;
    Color color;
    String text;
    IconData icon;

    switch (status) {
      case 'pending':
        color = Colors.orange;
        text = 'في انتظار القبول';
        icon = Icons.hourglass_empty;
        break;
      case 'searching':
      case 'no_technician_found':
        color = Colors.orange;
        text = 'متاح لتقديم عرض';
        icon = Icons.local_offer_outlined;
        break;
      case 'accepted':
        color = Colors.blue;
        text = 'مقبول - أدخل السعر';
        icon = Icons.check_circle;
        break;
      case 'price_pending':
        color = Colors.purple;
        text = 'انتظار موافقة العميل';
        icon = Icons.pending;
        break;
      case 'on_the_way':
        color = Colors.blueAccent;
        text = 'في الطريق إلى العميل';
        icon = Icons.directions_car;
        break;
      case 'arrived':
        color = Colors.teal;
        text = 'وصلت إلى الموقع';
        icon = Icons.place;
        break;
      case 'in_progress':
        color = Colors.green;
        text = 'قيد التنفيذ';
        icon = Icons.work;
        break;
      case 'completed':
        color = Colors.teal;
        text = 'مكتمل';
        icon = Icons.done_all;
        break;
      default:
        color = Colors.grey;
        text = status;
        icon = Icons.info;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color),
          SizedBox(width: 8.w),
          Text(
            text,
            style: TextStyle(
              fontSize: 16.fz,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: KadmatColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primaryColor, size: 20.s),
              SizedBox(width: 8.w),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14.fz,
                  color: KadmatColors.lightTextSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          child,
        ],
      ),
    );
  }

  Widget _buildCustomerInfoCard() {
    final customerName = _job!.customer?['full_name'] ?? 'العميل';
    final customerPhone = _job!.customer?['phone'] ?? '';
    final customerRating = _job!.customer?['rating']?.toString() ?? '5.0';
    final customerPhoto = _job!.customer?['avatar_url'];
    final customerOrdersCount = _job!.customer?['orders_count'] ?? 0;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: KadmatColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.person, color: AppTheme.primaryColor, size: 20.s),
              SizedBox(width: 8.w),
              Text(
                'العميل',
                style: TextStyle(
                  fontSize: 14.fz,
                  color: KadmatColors.lightTextSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),

          // Customer Info Row
          Row(
            children: [
              // Photo
              CircleAvatar(
                radius: 30.r,
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.3),
                backgroundImage: customerPhoto != null
                    ? NetworkImage(customerPhoto)
                    : null,
                child: customerPhoto == null
                    ? Icon(Icons.person, size: 30.s, color: Colors.white70)
                    : null,
              ),
              SizedBox(width: 12.w),

              // Name & Rating & Orders Count
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customerName,
                      style: TextStyle(
                        fontSize: 18.fz,
                        fontWeight: FontWeight.w800,
                        color: KadmatColors.lightTextPrimary,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        Icon(Icons.star, color: Colors.amber, size: 16.s),
                        SizedBox(width: 4.w),
                        Text(
                          customerRating,
                          style: TextStyle(
                            fontSize: 14.fz,
                            color: KadmatColors.lightTextSecondary,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          '•',
                          style: TextStyle(
                            color: KadmatColors.lightTextSecondary,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          '$customerOrdersCount طلبات',
                          style: TextStyle(
                            fontSize: 14.fz,
                            color: KadmatColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Phone and Chat Buttons
          if (customerPhone.isNotEmpty) ...[
            SizedBox(height: 16.h),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        JobCommunicationPolicy.canUseJobCommunication(_job)
                        ? () => _callCustomer(customerPhone)
                        : null,
                    icon: const Icon(Icons.phone),
                    label: const Text('اتصال'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        JobCommunicationPolicy.canUseJobCommunication(_job)
                        ? () {
                            context.push(
                              AppRoutes.buildJobChatPath(widget.jobId),
                              extra: {
                                'otherUserName': customerName,
                                'otherUserImage': customerPhoto,
                                'otherUserPhone': customerPhone,
                              },
                            );
                          }
                        : null,
                    icon: const Icon(Icons.chat),
                    label: const Text('مراسلة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (!JobCommunicationPolicy.canUseJobCommunication(_job)) ...[
              SizedBox(height: 8.h),
              Text(
                JobCommunicationPolicy.unavailableMessage,
                style: TextStyle(
                  fontSize: 12.fz,
                  color: KadmatColors.lightTextSecondary,
                ),
              ),
            ],
          ],

          // Phone number display
          if (customerPhone.isNotEmpty) ...[
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: KadmatColors.brandAccent,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.phone_android, size: 16.s, color: Colors.white60),

                  SizedBox(width: 8.w),
                  Text(
                    customerPhone,
                    style: TextStyle(
                      fontSize: 14.fz,
                      color: KadmatColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _callCustomer(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        KadmatToast.showError(
          context,
          title: 'خطأ',
          message: 'لا يمكن الاتصال بـ $phone',
        );
      }
    }
  }

  Widget _buildPhotoGrid(String title, List<String> photos) {
    if (photos.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: KadmatColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.photo_library,
                color: AppTheme.primaryColor,
                size: 20.w,
              ),
              SizedBox(width: 8.w),
              Text(
                title,
                style: TextStyle(
                  color: KadmatColors.lightTextPrimary,
                  fontSize: 16.fz,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8.w,
              mainAxisSpacing: 8.h,
              childAspectRatio: 1.0,
            ),
            itemCount: photos.length,
            itemBuilder: (context, index) {
              final photoUrl = photos[index];
              return GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => Dialog(
                      backgroundColor: Colors.transparent,
                      insetPadding: EdgeInsets.zero,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(color: Colors.black87),
                          ),
                          Center(
                            child: InteractiveViewer(
                              child: CachedNetworkImage(
                                imageUrl: photoUrl,
                                placeholder: (context, url) =>
                                    const CircularProgressIndicator(),
                                errorWidget: (context, url, error) =>
                                    const Icon(Icons.error, color: Colors.red),
                              ),
                            ),
                          ),
                          PositionedDirectional(
                            top: 40.h,
                            start: 16.w,
                            child: IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12.r),
                  child: CachedNetworkImage(
                    imageUrl: photoUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.white10,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.white10,
                      child: const Center(
                        child: Icon(Icons.broken_image, color: Colors.white38),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Price Summary Card showing all price information
  Widget _buildPriceSummaryCard() {
    if (_job!.isCatalogFixed) {
      final catalogItems = _job!.effectiveJobCatalogItems;
      final subtotal =
          _job!.effectiveCatalogSubtotal ?? _job!.effectiveRuntimePrice;

      return Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(color: KadmatColors.lightBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.sell_outlined,
                  color: AppTheme.primaryColor,
                  size: 20.s,
                ),
                SizedBox(width: 8.w),
                Text(
                  'ملخص السعر الثابت',
                  style: TextStyle(
                    fontSize: 14.fz,
                    color: KadmatColors.lightTextSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            _buildPriceRow('الإجمالي', subtotal, AppTheme.primaryColor),
            SizedBox(height: 12.h),
            _buildPriceRow(
              'عدد العناصر',
              _job!.effectiveCatalogItemCount.toDouble(),
              KadmatColors.stateInfo,
            ),
            if (catalogItems.isNotEmpty) ...[
              SizedBox(height: 16.h),
              ...catalogItems.map((item) {
                final title =
                    (item['item_name'] ??
                            item['name_ar'] ??
                            item['name'] ??
                            item['title'] ??
                            'عنصر خدمة')
                        .toString();
                final quantity = ((item['quantity'] as num?)?.toInt() ?? 1)
                    .clamp(1, 999);
                final total =
                    (item['line_total'] as num?)?.toDouble() ??
                    (item['price'] as num?)?.toDouble() ??
                    (item['unit_price'] as num?)?.toDouble();

                return Padding(
                  padding: EdgeInsets.only(bottom: 10.h),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          quantity > 1 ? '$title × $quantity' : title,
                          style: TextStyle(
                            fontSize: 13.fz,
                            fontWeight: FontWeight.w700,
                            color: KadmatColors.lightTextPrimary,
                          ),
                        ),
                      ),
                      if (total != null)
                        Text(
                          '${total.toStringAsFixed(0)} د.ل',
                          style: TextStyle(
                            fontSize: 13.fz,
                            fontWeight: FontWeight.w700,
                            color: KadmatColors.lightTextSecondary,
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      );
    }

    final initialPriceRaw = _job!.initialPrice;
    final initialPrice = (initialPriceRaw != null && initialPriceRaw > 0)
        ? initialPriceRaw
        : null;
    final technicianPrice = _job!.technicianPrice;
    final status = _job!.status;

    // Only show if there's any price info
    if (initialPrice == null && technicianPrice == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: KadmatColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.monetization_on,
                color: AppTheme.primaryColor,
                size: 20.s,
              ),
              SizedBox(width: 8.w),
              Text(
                'ملخص الأسعار',
                style: TextStyle(
                  fontSize: 14.fz,
                  color: KadmatColors.lightTextSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          // Initial/Budget Price
          if (initialPrice != null)
            _buildPriceRow('السعر الابتدائي', initialPrice, Colors.grey),

          // Technician's Proposed Price
          if (technicianPrice != null) ...[
            SizedBox(height: 12.h),
            _buildPriceRow(
              'السعر المقترح',
              technicianPrice,
              AppTheme.primaryColor,
            ),
          ],

          // Final Price (if approved)
          if (status == 'on_the_way' ||
              status == 'arrived' ||
              status == 'in_progress' ||
              status == 'completed' ||
              status == 'pending_confirm' ||
              status == 'pending_confirmation') ...[
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 20.s),
                      SizedBox(width: 8.w),
                      Text(
                        'السعر النهائي (موافق عليه)',
                        style: TextStyle(
                          fontSize: 14.fz,
                          fontWeight: FontWeight.w800,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${technicianPrice ?? initialPrice} د.ل',
                    style: TextStyle(
                      fontSize: 18.fz,
                      fontWeight: FontWeight.w800,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Commission Notice (for technician)
          if (technicianPrice != null) ...[
            SizedBox(height: 16.h),
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16.s, color: Colors.amber),
                  SizedBox(width: 8.w),
                  Text(
                    'عمولة التطبيق: ${(technicianPrice * 0.15).toStringAsFixed(0)} د.ل (15%)',
                    style: TextStyle(
                      fontSize: 12.fz,
                      color: const Color(0xFF946200),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, double price, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14.fz,
            color: KadmatColors.lightTextSecondary,
          ),
        ),
        Text(
          '$price د.ل',
          style: TextStyle(
            fontSize: 16.fz,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    final status = _job!.status;

    switch (status) {
      case 'pending':
      case 'searching':
      case 'no_technician_found':
        if (_job!.isCatalogFixed) {
          return _job!.canAcceptDirectly
              ? _buildDirectAcceptButton()
              : const SizedBox.shrink();
        }
        return _buildSubmitOfferButton();
      case 'accepted':
        if (_job!.isCatalogFixed) {
          return _job!.canStartTravel
              ? _buildStartTravelButton()
              : _buildFixedPriceAcceptedNotice();
        }
        return _buildPriceInput();
      case 'price_pending':
        if (_job!.isCatalogFixed) {
          return _buildFixedPriceAcceptedNotice();
        }
        return _buildWaitingForCustomer();
      case 'on_the_way':
        return _buildArrivedButton();
      case 'arrived':
        return _buildStartWorkButton();
      case 'in_progress':
        return _buildCompleteButton();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildDirectAcceptButton() {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : _acceptFixedPriceJob,
      icon: const Icon(Icons.check_circle_outline_rounded),
      label: Text(
        'قبول الطلب الثابت',
        style: TextStyle(fontSize: 16.fz, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 16.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
      ),
    );
  }

  Widget _buildStartTravelButton() {
    return ElevatedButton.icon(
      onPressed: _isLoading
          ? null
          : () => _updateTechnicianProgress('on_the_way'),
      icon: const Icon(Icons.navigation_outlined),
      label: Text(
        'بدء التوجّه',
        style: TextStyle(fontSize: 16.fz, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 16.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
      ),
    );
  }

  Widget _buildFixedPriceAcceptedNotice() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: KadmatColors.brandAccent,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: KadmatColors.lightBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.sell_outlined, color: AppTheme.primaryColor, size: 22.s),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              'الطلب ثابت السعر بالفعل. لا توجد خطوة تسعير في هذه المرحلة.',
              style: TextStyle(
                fontSize: 13.fz,
                fontWeight: FontWeight.w700,
                color: KadmatColors.lightTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitOfferButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : () => _showSubmitOfferDialog(),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 16.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
        elevation: 4,
      ),
      child: _isLoading
          ? const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(color: Colors.white),
            )
          : Text(
              'تقديم عرض سعر',
              style: TextStyle(fontSize: 16.fz, fontWeight: FontWeight.bold),
            ),
    );
  }

  void _showSubmitOfferDialog() {
    _priceController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: Text('تقديم عرض', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'السعر المقترح (د.ل)',
                hintStyle: TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.black12,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _submitOffer();
            },
            child: Text('إرسال'),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceInput() {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: AppTheme.glassDecoration(radius: 16.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'تحديد السعر',
                style: TextStyle(
                  fontSize: 16.fz,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'أدخل السعر (د.ل)',
                  hintStyle: TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(
                    Icons.attach_money,
                    color: AppTheme.primaryColor,
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: _notesController,
                maxLines: 2,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'ملاحظات (اختياري)',
                  hintStyle: TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16.h),
        ElevatedButton(
          onPressed: _isLoading ? null : _setPrice,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            padding: EdgeInsets.symmetric(vertical: 16.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
          child: _isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.send),
                    SizedBox(width: 8.w),
                    Text(
                      'إرسال السعر للعميل',
                      style: TextStyle(
                        fontSize: 16.fz,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildWaitingForCustomer() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: KadmatColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(color: Colors.purple),
          SizedBox(height: 16.h),
          Text(
            'في انتظار موافقة العميل على السعر',
            style: TextStyle(
              fontSize: 16.fz,
              color: KadmatColors.lightTextPrimary,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8.h),
          Text(
            'لا تبدأ التنفيذ الآن. يمكنك تعديل السعر فقط إذا احتجت إلى ذلك.',
            style: TextStyle(
              fontSize: 12.5.fz,
              color: KadmatColors.lightTextSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8.h),
          Text(
            '${_job!.technicianPrice ?? 0} د.ل',
            style: TextStyle(
              fontSize: 24.fz,
              fontWeight: FontWeight.bold,
              color: Colors.purple,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArrivedButton() {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : () => _updateTechnicianProgress('arrived'),
      icon: const Icon(Icons.place),
      label: Text(
        'تأكيد الوصول',
        style: TextStyle(fontSize: 16.fz, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 16.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
      ),
    );
  }

  Widget _buildStartWorkButton() {
    return ElevatedButton.icon(
      onPressed: _isLoading
          ? null
          : () => _updateTechnicianProgress('start_work'),
      icon: const Icon(Icons.play_arrow),
      label: Text(
        'بدء العمل',
        style: TextStyle(fontSize: 16.fz, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 16.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
      ),
    );
  }

  Widget _buildCompleteButton() {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: KadmatColors.brandAccent,
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(color: KadmatColors.lightBorder),
          ),
          child: Row(
            children: [
              Icon(Icons.work, color: Colors.green, size: 32.s),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  'الخدمة قيد التنفيذ',
                  style: TextStyle(
                    fontSize: 14.fz,
                    color: KadmatColors.lightTextPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16.h),
        ElevatedButton(
          onPressed: () =>
              context.go(AppRoutes.buildTechnicianInProgressPath(widget.jobId)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            padding: EdgeInsets.symmetric(vertical: 16.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.play_arrow),
              SizedBox(width: 8.w),
              Text(
                'متابعة التنفيذ',
                style: TextStyle(fontSize: 18.fz, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _detailHeroIcon() {
    if (_job!.isCatalogFixed) {
      switch (_job!.status) {
        case 'accepted':
          return Icons.navigation_outlined;
        case 'price_pending':
          return Icons.sell_outlined;
      }
    }
    switch (_job!.status) {
      case 'accepted':
        return Icons.sell_outlined;
      case 'price_pending':
        return Icons.hourglass_top_outlined;
      case 'on_the_way':
        return Icons.route_outlined;
      case 'arrived':
        return Icons.place_outlined;
      case 'in_progress':
        return Icons.handyman_outlined;
      case 'completed':
      case 'pending_confirm':
      case 'pending_confirmation':
        return Icons.task_alt_outlined;
      default:
        return Icons.assignment_outlined;
    }
  }

  String _detailStatusLabel() {
    if (_job!.isCatalogFixed) {
      switch (_job!.status) {
        case 'pending':
        case 'searching':
        case 'no_technician_found':
          return 'طلب ثابت متاح';
        case 'accepted':
          return 'تم تثبيت الطلب';
        case 'price_pending':
          return 'سعر ثابت جاهز';
      }
    }
    switch (_job!.status) {
      case 'pending':
      case 'searching':
      case 'no_technician_found':
        return 'طلب متاح للمعاينة';
      case 'accepted':
        return 'بقي تحديد السعر';
      case 'price_pending':
        return 'بانتظار موافقة العميل';
      case 'on_the_way':
        return 'في الطريق';
      case 'arrived':
        return 'تم الوصول';
      case 'in_progress':
        return 'قيد التنفيذ';
      case 'completed':
      case 'pending_confirm':
      case 'pending_confirmation':
        return 'تم إرسال الإكمال';
      default:
        return 'تفاصيل الطلب';
    }
  }

  String _detailHeroTitle() {
    if (_job!.isCatalogFixed) {
      switch (_job!.status) {
        case 'pending':
        case 'searching':
        case 'no_technician_found':
          return 'راجع الطلب الثابت قبل القبول';
        case 'accepted':
          return 'حان وقت بدء التوجّه';
        case 'price_pending':
          return 'السعر ثابت ولا ينتظر مراجعة';
      }
    }
    switch (_job!.status) {
      case 'pending':
      case 'searching':
      case 'no_technician_found':
        return 'راجع الطلب قبل تقديم العرض';
      case 'accepted':
        return 'حان وقت تحديد السعر';
      case 'price_pending':
        return 'انتظر قرار العميل';
      case 'on_the_way':
        return 'اتجه إلى موقع العميل';
      case 'arrived':
        return 'أنت على بُعد خطوة من بدء العمل';
      case 'in_progress':
        return 'ركّز على تنفيذ الخدمة';
      case 'completed':
      case 'pending_confirm':
      case 'pending_confirmation':
        return 'الطلب في مرحلة الإغلاق';
      default:
        return 'تفاصيل الطلب';
    }
  }

  String _detailHeroSubtitle() {
    if (_job!.isCatalogFixed) {
      switch (_job!.status) {
        case 'pending':
        case 'searching':
        case 'no_technician_found':
          return 'هذا الطلب لا يحتاج عرضًا أو تفاوضًا. راجع العناصر والسعر الثابت ثم اقبل الطلب إذا كان مناسبًا لك.';
        case 'accepted':
          return 'السعر مثبت مسبقًا لهذا الطلب. لا ترسل سعرًا جديدًا، فقط راجع الموقع وابدأ التوجّه عندما تكون جاهزًا.';
        case 'price_pending':
          return 'هذه شاشة توافق قديمة بالنسبة للطلب الثابت. افتح تفاصيل الطلب أو واصل إلى التنفيذ عند ظهور الخطوة التالية.';
      }
    }
    switch (_job!.status) {
      case 'pending':
      case 'searching':
      case 'no_technician_found':
        return 'تأكد من وصف المشكلة والموقع والسعر المتوقع قبل أن ترسل عرضك حتى تختصر المراسلات لاحقًا.';
      case 'accepted':
        return 'العميل اختارك بالفعل. المطلوب الآن إرسال سعر واضح وملاحظات مختصرة إذا كانت هناك تفاصيل إضافية.';
      case 'price_pending':
        return 'لا تبدأ التنفيذ قبل موافقة العميل على السعر. راجع السعر المقترح وانتظر الرد أو عدّله إذا لزم.';
      case 'on_the_way':
        return 'استخدم الموقع والخرائط للوصول بسرعة، ثم أكّد الوصول من هذه الشاشة فورًا.';
      case 'arrived':
        return 'بعد التأكد من مكان العميل أبلغ التطبيق ببدء العمل حتى ينتقل الفلو إلى التنفيذ.';
      case 'in_progress':
        return 'راجع الصور والمعلومات فقط عند الحاجة، والإجراء التالي الأساسي هو متابعة التنفيذ ثم الانتقال لطلب الإنهاء.';
      case 'completed':
      case 'pending_confirm':
      case 'pending_confirmation':
        return 'تم تسجيل نهاية العمل. انتظر تأكيد العميل وأبقِ هذه الشاشة مرجعًا سريعًا للصور والسعر.';
      default:
        return 'كل ما تحتاجه عن الطلب في مكان واحد، مع خطوة تالية واضحة حسب حالته الحالية.';
    }
  }

  IconData _detailNextStepIcon() {
    if (_job!.isCatalogFixed) {
      switch (_job!.status) {
        case 'accepted':
          return Icons.navigation_outlined;
        case 'price_pending':
          return Icons.info_outline_rounded;
      }
    }
    switch (_job!.status) {
      case 'pending':
      case 'searching':
      case 'no_technician_found':
        return Icons.local_offer_outlined;
      case 'accepted':
        return Icons.price_change_outlined;
      case 'price_pending':
        return Icons.pause_circle_outline;
      case 'on_the_way':
        return Icons.navigation_outlined;
      case 'arrived':
        return Icons.play_circle_outline;
      case 'in_progress':
        return Icons.checklist_outlined;
      case 'completed':
      case 'pending_confirm':
      case 'pending_confirmation':
        return Icons.hourglass_bottom_outlined;
      default:
        return Icons.track_changes_outlined;
    }
  }

  String _detailNextStepTitle() {
    if (_job!.isCatalogFixed) {
      switch (_job!.status) {
        case 'pending':
        case 'searching':
        case 'no_technician_found':
          return 'القرار التالي: اقبل الطلب أو تجاوزه';
        case 'accepted':
          return 'القرار التالي: ابدأ التوجّه';
        case 'price_pending':
          return 'لا توجد خطوة تسعير هنا';
      }
    }
    switch (_job!.status) {
      case 'pending':
      case 'searching':
      case 'no_technician_found':
        return 'القرار التالي: قدّم عرضًا واحدًا واضحًا';
      case 'accepted':
        return 'القرار التالي: أرسل السعر الآن';
      case 'price_pending':
        return 'القرار التالي: انتظر ولا تبدأ التنفيذ';
      case 'on_the_way':
        return 'القرار التالي: افتح الخرائط وأكّد الوصول';
      case 'arrived':
        return 'القرار التالي: ابدأ العمل من التطبيق';
      case 'in_progress':
        return 'القرار التالي: أكمل التنفيذ ثم اطلب الإنهاء';
      case 'completed':
      case 'pending_confirm':
      case 'pending_confirmation':
        return 'لا يوجد إجراء إضافي عاجل الآن';
      default:
        return 'راجع الطلب ثم نفّذ الإجراء المناسب';
    }
  }

  String _detailNextStepDescription() {
    if (_job!.isCatalogFixed) {
      switch (_job!.status) {
        case 'pending':
        case 'searching':
        case 'no_technician_found':
          return 'لا تستخدم منطق العروض هنا. راجع الموقع والعناصر والسعر الثابت، ثم اقبل الطلب إذا كان مناسبًا لك.';
        case 'accepted':
          return 'الطلب مثبت على الفني بالفعل. استخدم نفس الشاشة كمرجع سريع ثم انتقل إلى التوجّه بدل فتح شاشة تسعير.';
        case 'price_pending':
          return 'السعر مثبت مسبقًا لهذا الطلب، لذلك لا تحتاج إلى انتظار موافقة عميل على تسعير جديد.';
      }
    }
    switch (_job!.status) {
      case 'pending':
      case 'searching':
      case 'no_technician_found':
        return 'لا تشتت نفسك في تفاصيل ثانوية. راجع الموقع والوصف ثم قدّم عرضًا مناسبًا إذا كان الطلب يلائمك.';
      case 'accepted':
        return 'إذا كان السعر الابتدائي مناسبًا عدّل عليه أو أكّده، ثم أرسل السعر مع ملاحظة قصيرة عند الحاجة فقط.';
      case 'price_pending':
        return 'هذه المرحلة لا تتطلب منك سوى المتابعة. إذا تغيّرت المعطيات افتح تعديل السعر بدل بدء العمل مبكرًا.';
      case 'on_the_way':
        return 'زر الخرائط وبيانات المسافة في هذه الصفحة يكفيان للوصول. بعد الوصول استخدم زر تأكيد الوصول مباشرة.';
      case 'arrived':
        return 'أبلغ التطبيق ببدء العمل حتى ينتقل الطلب إلى التنفيذ وتُفتح لك الخطوات التالية بشكل صحيح.';
      case 'in_progress':
        return 'حافظ على تركيزك على العمل نفسه. إذا احتجت مرجعًا سريعًا فصور العميل والموقع والسعر كلها هنا في صفحة واحدة.';
      case 'completed':
      case 'pending_confirm':
      case 'pending_confirmation':
        return 'يمكنك الاكتفاء بمتابعة تأكيد العميل. هذه الشاشة تحتفظ بالسعر والصور وبيانات العميل للرجوع السريع.';
      default:
        return 'استخدم هذه الصفحة كمرجع سريع للطلب، مع التركيز على الإجراء التالي فقط.';
    }
  }

  Future<void> _submitOffer() async {
    final price = double.tryParse(_priceController.text);
    if (price == null || price <= 0) {
      KadmatToast.showWarning(
        context,
        title: 'خطأ',
        message: 'يرجى إدخال سعر صحيح',
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(jobRepositoryProvider).submitOffer(widget.jobId, price);

      if (mounted) {
        KadmatToast.showSuccess(
          context,
          title: 'تم إرسال العرض',
          message: '✅ تم إرسال عرضك بنجاح. سنشعرك عند قبول العميل.',
        );
        Navigator.pop(context); // Go back to jobs list
      }
    } catch (e) {
      if (mounted) {
        KadmatToast.showError(
          context,
          title: 'فشل إرسال العرض',
          message: _friendlyActionError(e),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _acceptFixedPriceJob() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(jobRepositoryProvider).acceptJob(widget.jobId);
      await _fetchJob();
      if (!mounted) return;
      KadmatToast.showSuccess(
        context,
        title: 'تم قبول الطلب',
        message: '✅ تم تثبيت الطلب الثابت على حسابك بنجاح.',
      );
    } catch (e) {
      if (!mounted) return;
      KadmatToast.showError(
        context,
        title: 'تعذر قبول الطلب',
        message: _friendlyActionError(e),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _setPrice() async {
    final price = double.tryParse(_priceController.text);
    if (price == null || price <= 0) {
      KadmatToast.showWarning(
        context,
        title: 'تنبيه',
        message: 'أدخل سعر صحيح',
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref
          .read(jobRepositoryProvider)
          .setPrice(widget.jobId, price, notes: _notesController.text);
      if (mounted) {
        KadmatToast.showSuccess(
          context,
          title: 'تم تحديد السعر',
          message: '💰 تم تحديد السعر، بانتظار موافقة العميل…',
        );
      }
    } catch (e) {
      if (mounted) {
        KadmatToast.showError(
          context,
          title: 'فشل إرسال السعر',
          message: _friendlyActionError(e),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateTechnicianProgress(String progress) async {
    setState(() => _isLoading = true);
    try {
      await ref
          .read(jobRepositoryProvider)
          .updateTechnicianProgress(widget.jobId, progress: progress);
      await _fetchJob();

      if (!mounted) return;
      final successMessage = progress == 'arrived'
          ? 'تم تسجيل وصولك إلى موقع العميل.'
          : 'تم تحديث الحالة إلى: بدء التنفيذ.';
      KadmatToast.showSuccess(
        context,
        title: 'تم تحديث الحالة',
        message: successMessage,
      );
    } catch (e) {
      if (!mounted) return;
      KadmatToast.showError(
        context,
        title: 'تعذر تحديث الحالة',
        message: _friendlyActionError(e),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlyActionError(Object error) {
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
    if (normalized.contains('invalid status') ||
        normalized.contains('invalid_status_transition')) {
      return 'تعذر تنفيذ الإجراء بسبب حالة الطلب الحالية.';
    }
    if (normalized.contains('no longer available') ||
        normalized.contains('لم يعد') ||
        normalized.contains('غير متاح')) {
      return 'هذا الطلب لم يعد متاحاً الآن. حدّث القائمة واختر طلباً آخر.';
    }
    if (normalized.contains('already submitted') ||
        normalized.contains('قدمت عرض')) {
      return 'تم تحديث عرضك مسبقاً لهذا الطلب.';
    }
    return 'تعذر إرسال البيانات الآن. يرجى المحاولة مرة أخرى.';
  }
}
