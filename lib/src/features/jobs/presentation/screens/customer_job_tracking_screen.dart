import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/app_theme.dart';
import '../../../../core/design/kadmat_tokens.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/navigation/job_flow_redirects.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/utils/service_name_formatter.dart';
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

  @override
  Widget build(BuildContext context) {
    final jobAsync = ref.watch(watchJobProvider(widget.jobId));
    final title = jobAsync.maybeWhen(
      data: (job) =>
          formatServiceDisplayName(job.service, fallback: 'تتبع الطلب'),
      orElse: () => 'تتبع الطلب',
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              context.pop();
              return;
            }
            context.go(AppRoutes.home);
          },
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
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

    final serviceName = formatServiceDisplayName(
      job.service,
      fallback: 'الخدمة المطلوبة',
    );
    final hasMapLocation = job.lat != 0 && job.lng != 0;
    final jobLocation = LatLng(job.lat, job.lng);
    final address = (job.addressText?.trim().isNotEmpty ?? false)
        ? job.addressText!.trim()
        : 'سيتم تحديث العنوان فور تثبيت نقطة الطلب';
    final canUseCommunication =
        job.technicianId != null &&
        JobCommunicationPolicy.canUseJobCommunication(job);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(18.w, 8.h, 18.w, 14.h),
            child: _TrackingHeroCard(
              serviceName: serviceName,
              status: job.status,
              message: _getStatusMessage(job.status),
              address: address,
              communicationAvailable: canUseCommunication,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 18.w),
            child: _TrackingNextStepCard(
              title: _getNextStepTitle(job.status),
              description: _getNextStepDescription(job.status),
              icon: _getNextStepIcon(job.status),
            ),
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: 14.h)),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 18.w),
            child: _buildMapPanel(
              job: job,
              jobLocation: jobLocation,
              hasMapLocation: hasMapLocation,
              address: address,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(18.w, 16.h, 18.w, 0),
            child: Container(
              padding: EdgeInsets.all(18.w),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(28.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'مراحل الطلب الحالية',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.fz,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'يتم تحديث هذه المراحل تلقائيًا عند انتقال الفني إلى الحالة التالية.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12.5.fz,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: 14.h),
                  JobProgressStepper.forCustomer(
                    job.status,
                    isHorizontal: true,
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(18.w, 16.h, 18.w, 0),
            child: _TrackingDetailsCard(
              serviceName: serviceName,
              address: address,
              status: job.status,
              note: job.description,
            ),
          ),
        ),
        if (job.technician != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(18.w, 16.h, 18.w, 0),
              child: _TrackingTechnicianCard(
                technician: job.technician!,
                onOpenChat: canUseCommunication ? () => _openChat(job) : null,
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(18.w, 16.h, 18.w, 32.h),
            child: Column(
              children: [
                if (canUseCommunication)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _openChat(job),
                      icon: const Icon(Icons.chat_bubble_outline_rounded),
                      label: const Text('فتح المحادثة مع الفني'),
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22.r),
                      border: Border.all(color: KadmatColors.lightBorder),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: KadmatColors.stateInfo,
                          size: 20.s,
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Text(
                            'المحادثة والاتصال يظلان متاحين ضمن هذه المرحلة فقط عندما تكون بيانات الفني جاهزة للتواصل.',
                            style: TextStyle(
                              color: KadmatColors.lightTextSecondary,
                              fontSize: 12.5.fz,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMapPanel({
    required Job job,
    required LatLng jobLocation,
    required bool hasMapLocation,
    required String address,
  }) {
    return Container(
      height: 280.h,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30.r),
        border: Border.all(color: KadmatColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: hasMapLocation
          ? Stack(
              children: [
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
                        initialCenter: jobLocation,
                        initialZoom: 13.0,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.kadmat.app',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: jobLocation,
                              width: 46.s,
                              height: 46.s,
                              child: const _LocationMarker(
                                icon: Icons.home_rounded,
                                color: KadmatColors.stateInfo,
                              ),
                            ),
                            if (techLocation != null)
                              Marker(
                                point: techLocation,
                                width: 46.s,
                                height: 46.s,
                                child: const _LocationMarker(
                                  icon: Icons.directions_car_filled_rounded,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                PositionedDirectional(
                  top: 16.h,
                  start: 16.w,
                  child: _TrackingPill(
                    icon: Icons.location_searching_rounded,
                    label: 'تتبع حي للموقع',
                    color: KadmatColors.stateInfo,
                  ),
                ),
                PositionedDirectional(
                  start: 16.w,
                  end: 16.w,
                  bottom: 16.h,
                  child: Container(
                    padding: EdgeInsets.all(14.w),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(18.r),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.place_outlined,
                          color: AppTheme.primaryColor,
                          size: 18.s,
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.5.fz,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : _TrackingMapEmptyState(address: address),
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

  String _getNextStepTitle(String status) {
    final normalizedStatus = JobStatus.normalize(status);
    switch (normalizedStatus) {
      case JobStatus.accepted:
      case JobStatus.onTheWay:
        return 'الخطوة التالية: تابع وصول الفني';
      case JobStatus.arrived:
        return 'الخطوة التالية: استقبل الفني وابدأ التنسيق';
      case JobStatus.inProgress:
        return 'الخطوة التالية: راقب التنفيذ فقط';
      case JobStatus.pendingConfirm:
        return 'الخطوة التالية: راجع النتيجة وأكّد الإكمال';
      case JobStatus.completed:
        return 'الخطوة التالية: أكمل الدفع';
      case JobStatus.rated:
        return 'الطلب أُغلق بنجاح';
      default:
        return 'الخطوة التالية: تابع حالة الطلب';
    }
  }

  String _getNextStepDescription(String status) {
    final normalizedStatus = JobStatus.normalize(status);
    switch (normalizedStatus) {
      case JobStatus.accepted:
      case JobStatus.onTheWay:
        return 'الخريطة أدناه تساعدك على متابعة الطريق، وستتحدث الحالة تلقائيًا عندما يقترب الفني أو يصل.';
      case JobStatus.arrived:
        return 'الفني أصبح في موقعك. استخدم المحادثة فقط إذا احتجت تنسيقًا سريعًا قبل بدء العمل.';
      case JobStatus.inProgress:
        return 'العمل جارٍ الآن. لا تحتاج لإجراء جديد إلا إذا طلب الفني توضيحًا أو أردت إرسال رسالة.';
      case JobStatus.pendingConfirm:
        return 'افتح تفاصيل التنفيذ والصور، ثم أكّد اكتمال الخدمة عندما تتأكد أن كل شيء انتهى كما طلبت.';
      case JobStatus.completed:
        return 'راجع المبلغ النهائي وانتقل إلى خطوة الدفع لإغلاق الطلب، ثم ستتمكن من إضافة تقييمك.';
      case JobStatus.rated:
        return 'كل شيء مكتمل الآن. يمكنك مراجعة السجل أو مغادرة الصفحة دون الحاجة لأي إجراء إضافي.';
      default:
        return 'هذه الشاشة تعرض لك المرحلة الحالية، والموقع، وأقرب إجراء مطلوب منك في الوقت المناسب.';
    }
  }

  IconData _getNextStepIcon(String status) {
    final normalizedStatus = JobStatus.normalize(status);
    switch (normalizedStatus) {
      case JobStatus.accepted:
      case JobStatus.onTheWay:
        return Icons.route_rounded;
      case JobStatus.arrived:
        return Icons.handshake_outlined;
      case JobStatus.inProgress:
        return Icons.construction_rounded;
      case JobStatus.pendingConfirm:
        return Icons.fact_check_outlined;
      case JobStatus.completed:
        return Icons.payments_outlined;
      case JobStatus.rated:
        return Icons.verified_rounded;
      default:
        return Icons.navigation_outlined;
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

class _TrackingHeroCard extends StatelessWidget {
  const _TrackingHeroCard({
    required this.serviceName,
    required this.status,
    required this.message,
    required this.address,
    required this.communicationAvailable,
  });

  final String serviceName;
  final String status;
  final String message;
  final String address;
  final bool communicationAvailable;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(22.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30.r),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF17313B), Color(0xFF0D1E25)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52.w,
                height: 52.w,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(18.r),
                ),
                child: Icon(
                  Icons.route_rounded,
                  color: Colors.white,
                  size: 24.s,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'متابعة الطلب الحالية',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12.fz,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      serviceName,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 23.fz,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              JobStatusBadge(status: status),
            ],
          ),
          SizedBox(height: 16.h),
          Text(
            message,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.fz,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'هذه الشاشة تعطيك الحالة المباشرة، موقع الخدمة، وإمكانية التواصل عندما تصبح متاحة ضمن هذه المرحلة.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 12.5.fz,
              height: 1.55,
            ),
          ),
          SizedBox(height: 16.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              _TrackingPill(
                icon: Icons.place_outlined,
                label: address,
                color: Colors.white,
                isSoft: true,
              ),
              _TrackingPill(
                icon: communicationAvailable
                    ? Icons.chat_bubble_outline_rounded
                    : Icons.lock_outline_rounded,
                label: communicationAvailable
                    ? 'التواصل متاح'
                    : 'التواصل حسب المرحلة',
                color: communicationAvailable
                    ? KadmatColors.stateSuccess
                    : KadmatColors.stateWarning,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrackingNextStepCard extends StatelessWidget {
  const _TrackingNextStepCard({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: KadmatColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46.w,
            height: 46.w,
            decoration: BoxDecoration(
              color: KadmatColors.brandAccent,
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Icon(icon, size: 22.s, color: KadmatColors.brandSecondary),
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
}

class _TrackingPill extends StatelessWidget {
  const _TrackingPill({
    required this.icon,
    required this.label,
    required this.color,
    this.isSoft = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool isSoft;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: isSoft
            ? Colors.white.withValues(alpha: 0.1)
            : color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: isSoft
              ? Colors.white.withValues(alpha: 0.14)
              : color.withValues(alpha: 0.36),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15.s, color: isSoft ? Colors.white : color),
          SizedBox(width: 6.w),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 210.w),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isSoft ? Colors.white : color,
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

class _TrackingMapEmptyState extends StatelessWidget {
  const _TrackingMapEmptyState({required this.address});

  final String address;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF172A32), Color(0xFF0C1A21)],
        ),
      ),
      padding: EdgeInsets.all(24.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 76.w,
            height: 76.w,
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
            'بانتظار تثبيت الموقع بدقة',
            style: TextStyle(
              fontSize: 20.fz,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'لن نعرض خريطة أو نقطة افتراضية. سيظهر الموقع الحقيقي هنا عندما تتوفر الإحداثيات النهائية للطلب.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.fz,
              color: Colors.white70,
              height: 1.6,
            ),
          ),
          SizedBox(height: 14.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.place_outlined, color: Colors.white70),
                SizedBox(width: 8.w),
                Flexible(
                  child: Text(
                    address,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.5.fz,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackingDetailsCard extends StatelessWidget {
  const _TrackingDetailsCard({
    required this.serviceName,
    required this.address,
    required this.status,
    this.note,
  });

  final String serviceName;
  final String address;
  final String status;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: KadmatColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تفاصيل مفيدة الآن',
            style: TextStyle(
              color: KadmatColors.lightTextPrimary,
              fontSize: 18.fz,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 14.h),
          _TrackingDetailRow.text(label: 'الخدمة', text: serviceName),
          SizedBox(height: 10.h),
          _TrackingDetailRow.text(label: 'العنوان', text: address),
          SizedBox(height: 10.h),
          _TrackingDetailRow(
            label: 'الحالة الحالية',
            value: JobStatusBadge(status: status),
          ),
          if (note != null && note!.trim().isNotEmpty) ...[
            SizedBox(height: 14.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: KadmatColors.brandAccent,
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'وصف الطلب',
                    style: TextStyle(
                      color: KadmatColors.lightTextPrimary,
                      fontSize: 12.fz,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    note!.trim(),
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
    );
  }
}

class _TrackingDetailRow extends StatelessWidget {
  const _TrackingDetailRow({required this.label, required this.value});

  final String label;
  final Widget value;

  _TrackingDetailRow.text({required this.label, required String text})
    : value = Text(
        text,
        textAlign: TextAlign.end,
        style: TextStyle(
          color: KadmatColors.lightTextPrimary,
          fontSize: 14.fz,
          fontWeight: FontWeight.w700,
        ),
      );

  @override
  Widget build(BuildContext context) {
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
        Flexible(
          child: Align(alignment: Alignment.centerLeft, child: value),
        ),
      ],
    );
  }
}

class _TrackingTechnicianCard extends StatelessWidget {
  const _TrackingTechnicianCard({required this.technician, this.onOpenChat});

  final Map<String, dynamic> technician;
  final VoidCallback? onOpenChat;

  @override
  Widget build(BuildContext context) {
    final name = technician['full_name']?.toString().trim();
    final phone = technician['phone']?.toString().trim();
    final imageUrl = technician['profile_image_url']?.toString();
    final rating = (technician['rating'] as num?)?.toDouble();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: KadmatColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'الفني المتابع للطلب',
            style: TextStyle(
              color: KadmatColors.lightTextPrimary,
              fontSize: 18.fz,
              fontWeight: FontWeight.w800,
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
                          : 'سيظهر رقم التواصل عند توفره ضمن هذه المرحلة',
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
          if (onOpenChat != null) ...[
            SizedBox(height: 14.h),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onOpenChat,
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: const Text('التواصل مع الفني'),
              ),
            ),
          ],
        ],
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
