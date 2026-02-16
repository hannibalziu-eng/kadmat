import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/widgets/kadmat_toast.dart';
import '../../../../core/widgets/shimmer_skeletons.dart';
import '../../../../core/services/location/location_service.dart';
import '../../../jobs/data/job_repository.dart';
import '../../../jobs/domain/job.dart';

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
      final job = await ref.read(jobRepositoryProvider).getJobById(widget.jobId);
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
        backgroundColor: AppTheme.backgroundDark,
        appBar: AppBar(title: const Text('تفاصيل الطلب')),
        body: const DetailSkeleton(),
      );
    }

    final currentLocation = ref.watch(locationStreamProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('تفاصيل الطلب'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Badge
            _buildStatusBadge(),
            SizedBox(height: 16.h),

            // Service Info
            _buildInfoCard(
              title: 'الخدمة المطلوبة',
              icon: Icons.build_circle,
              child: Text(
                _job!.service?['name'] ?? 'خدمة',
                style: TextStyle(
                  fontSize: 18.fz,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(height: 12.h),

            // Customer Info - Enhanced
            _buildCustomerInfoCard(),
            SizedBox(height: 12.h),

            // Location
            _buildInfoCard(
              title: 'الموقع',
              icon: Icons.location_on,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _job!.addressText ?? 'موقع العميل',
                    style: TextStyle(fontSize: 14.fz, color: Colors.white70),
                  ),
                  SizedBox(height: 8.h),
                  // Mini Map Placeholder
                  Container(
                    height: 120.h,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12.r),
                      image: const DecorationImage(
                        image: AssetImage(
                          'assets/images/map_placeholder.png',
                        ), // Ensure this exists or use color
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.map,
                        size: 40.s,
                        color: Theme.of(
                          context,
                        ).cardColor.withValues(alpha: 0.95),
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  // Open in Maps Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final url =
                            'https://www.google.com/maps/search/?api=1&query=${_job!.lat},${_job!.lng}';
                        if (await canLaunchUrl(Uri.parse(url))) {
                          await launchUrl(Uri.parse(url));
                        }
                      },
                      icon: const Icon(Icons.map),
                      label: const Text('فتح في خرائط Google'),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  // Distance/Time
                  Row(
                    children: [
                      Icon(
                        Icons.directions_car,
                        size: 16.s,
                        color: Colors.grey,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        _distanceAndEtaText(currentLocation),
                        style: TextStyle(
                          fontSize: 14.fz,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 12.h),

            // Description
            if (_job!.description != null && _job!.description!.isNotEmpty)
              _buildInfoCard(
                title: 'وصف المشكلة',
                icon: Icons.description,
                child: Text(
                  _job!.description!,
                  style: TextStyle(fontSize: 14.fz, color: Colors.white70),
                ),
              ),
            SizedBox(height: 12.h),

            // Job Images (Customer Problem Photos)
            if (_job?.images != null && _job!.images!.isNotEmpty)
              _buildInfoCard(
                title: 'صور المشكلة (من العميل)',
                icon: Icons.image,
                child: SizedBox(
                  height: 120.h,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _job!.images!.length,
                    separatorBuilder: (context, index) => SizedBox(width: 12.w),
                    itemBuilder: (context, index) {
                      final image = _job!.images![index];
                      return Container(
                        width: 120.w,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                          image: DecorationImage(
                            image: NetworkImage(image.imageUrl),
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            // Initial Price
            if (_job!.initialPrice != null && _job!.initialPrice! > 0)
              _buildInfoCard(
                title: 'السعر الابتدائي',
                icon: Icons.monetization_on,
                child: Text(
                  '${_job!.initialPrice} ريال',
                  style: TextStyle(
                    fontSize: 18.fz,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            // Price Summary Card
            _buildPriceSummaryCard(),
            SizedBox(height: 24.h),

            // Customer Photos Section Grid
            if (_job?.images != null && _job!.images!.isNotEmpty)
              _buildPhotoGrid(
                'صور المشكلة (من العميل)',
                _job!.images!.map((e) => e.imageUrl).toList(),
              ),

            // Technician Pre-Service Photos
            if (_prePhotos.isNotEmpty) ...[
              SizedBox(height: 24.h),
              _buildPhotoGrid('صور قبل العمل', _prePhotos),
            ],

            SizedBox(height: 24.h),

            // Technician Post-Service Photos
            if (_postPhotos.isNotEmpty)
              _buildPhotoGrid('صور بعد الإنجاز', _postPhotos),

            SizedBox(height: 24.h),

            // Action Buttons based on status
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  String _distanceAndEtaText(Position? currentLocation) {
    if (currentLocation == null || _job == null) {
      return 'المسافة غير متاحة حالياً';
    }

    final meters = Geolocator.distanceBetween(
      currentLocation.latitude,
      currentLocation.longitude,
      _job!.lat,
      _job!.lng,
    );

    final km = meters / 1000;
    // Conservative ETA estimate based on city speed (35 km/h)
    final etaMinutes = ((km / 35) * 60).ceil().clamp(1, 240);

    return 'المسافة التقريبية: ${km.toStringAsFixed(1)} كم (حوالي $etaMinutes دقيقة)';
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
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color),
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
              fontWeight: FontWeight.bold,
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
      decoration: AppTheme.glassDecoration(radius: 16.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primaryColor, size: 20.s),
              SizedBox(width: 8.w),
              Text(
                title,
                style: TextStyle(fontSize: 14.fz, color: Colors.white60),
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
      decoration: AppTheme.glassDecoration(radius: 16.r),
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
                style: TextStyle(fontSize: 14.fz, color: Colors.white60),
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
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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
                            color: Colors.white70,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Text('•', style: TextStyle(color: Colors.white70)),
                        SizedBox(width: 8.w),
                        Text(
                          '$customerOrdersCount طلبات',
                          style: TextStyle(
                            fontSize: 14.fz,
                            color: Colors.white70,
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
                    onPressed: () => _callCustomer(customerPhone),
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
                    onPressed: () {
                      context.push(
                        AppRoutes.buildJobChatPath(widget.jobId),
                        extra: {
                          'otherUserName': customerName,
                          'otherUserImage': customerPhoto,
                        },
                      );
                    },
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
          ],

          // Phone number display
          if (customerPhone.isNotEmpty) ...[
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.phone_android, size: 16.s, color: Colors.white60),
                  SizedBox(width: 8.w),
                  Text(
                    customerPhone,
                    style: TextStyle(fontSize: 14.fz, color: Colors.white70),
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
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
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
                  color: Colors.white,
                  fontSize: 16.fz,
                  fontWeight: FontWeight.bold,
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
      decoration: AppTheme.glassDecoration(radius: 16.r),
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
                style: TextStyle(fontSize: 14.fz, color: Colors.white60),
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
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${technicianPrice ?? initialPrice} ريال',
                    style: TextStyle(
                      fontSize: 18.fz,
                      fontWeight: FontWeight.bold,
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
                    'عمولة التطبيق: ${(technicianPrice * 0.15).toStringAsFixed(0)} ريال (15%)',
                    style: TextStyle(fontSize: 12.fz, color: Colors.amber),
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
          style: TextStyle(fontSize: 14.fz, color: Colors.white70),
        ),
        Text(
          '$price ريال',
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
        return _buildSubmitOfferButton();
      case 'accepted':
        return _buildPriceInput();
      case 'price_pending':
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
                hintText: 'السعر المقترح (ريال)',
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
                  hintText: 'أدخل السعر (ريال)',
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
        color: Colors.purple.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.purple),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(color: Colors.purple),
          SizedBox(height: 16.h),
          Text(
            'في انتظار موافقة العميل على السعر',
            style: TextStyle(fontSize: 16.fz, color: Colors.white),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8.h),
          Text(
            '${_job!.technicianPrice ?? 0} ريال',
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      ),
    );
  }

  Widget _buildCompleteButton() {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Row(
            children: [
              Icon(Icons.work, color: Colors.green, size: 32.s),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  'الخدمة قيد التنفيذ',
                  style: TextStyle(fontSize: 14.fz, color: Colors.white),
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
