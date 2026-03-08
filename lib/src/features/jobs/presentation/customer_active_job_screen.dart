import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/app_theme.dart';
import '../../../core/design/kadmat_tokens.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/widgets/kadmat_toast.dart';
import '../../../core/utils/error_handler.dart';
import '../../../core/utils/service_name_formatter.dart';
import '../../../core/widgets/kadmat_components.dart';
import '../../../core/widgets/shimmer_skeletons.dart';
import '../data/job_repository.dart';
import '../domain/job.dart';
import '../domain/job_communication_policy.dart';
import '../domain/job_status.dart';

class CustomerActiveJobScreen extends ConsumerStatefulWidget {
  final String jobId;

  const CustomerActiveJobScreen({super.key, required this.jobId});

  @override
  ConsumerState<CustomerActiveJobScreen> createState() =>
      _CustomerActiveJobScreenState();
}

class _CustomerActiveJobScreenState
    extends ConsumerState<CustomerActiveJobScreen> {
  StreamSubscription? _jobSubscription;
  Job? _job;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    final jobRepo = ref.read(jobRepositoryProvider);
    _jobSubscription = jobRepo.watchJob(widget.jobId).listen((job) {
      if (mounted) {
        setState(() => _job = job);
        if (JobStatus.normalize(job.status) == JobStatus.completed &&
            job.customerRating == null) {
          context.push(AppRoutes.buildCustomerRatePath(widget.jobId));
        }
      }
    });
  }

  @override
  void dispose() {
    _jobSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_job == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF2F6F7),
        appBar: AppBar(title: const Text('طلبك')),
        body: const DetailSkeleton(),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF2F6F7),
      appBar: AppBar(
        title: Text(formatServiceDisplayName(_job!.service, fallback: 'طلبك')),
        centerTitle: true,
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    final status = JobStatus.normalize(_job!.status);

    switch (status) {
      case JobStatus.pending:
      case JobStatus.searching:
        return _buildSearchingState();
      case JobStatus.noTechnicianFound:
        // If technician was assigned after no_technician_found, show found state
        if (_job!.technicianId != null) {
          return _buildTechnicianFoundState();
        }
        return _buildNoTechnicianFoundState();
      case JobStatus.accepted:
      case JobStatus.pricePending:
        return _buildTechnicianFoundState();
      case JobStatus.inProgress:
        return _buildInProgressState();
      case JobStatus.pendingConfirm:
        return _buildPaymentPendingState();
      case JobStatus.completed:
        return _buildCompletedState();
      case JobStatus.cancelled:
        return _buildCancelledState();
      default:
        // Fallback: if technician is assigned, show found state
        if (_job!.technicianId != null) {
          return _buildTechnicianFoundState();
        }
        return Center(child: Text('حالة غير معروفة: $status'));
    }
  }

  Future<void> _callTechnician(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Widget _buildSearchingState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go(AppRoutes.buildCustomerSearchingPath(widget.jobId));
    });
    return _buildScrollablePage(
      children: [
        _buildHeroCard(
          icon: Icons.search_rounded,
          title: 'جارٍ البحث عن الفني المناسب',
          subtitle:
              'الطلب نشط الآن ويظهر للفنيين القريبين. لا تحتاج إلى أي إجراء في هذه اللحظة سوى المتابعة أو الإلغاء إذا غيرت رأيك.',
        ),
        SizedBox(height: 16.h),
        _buildFocusCard(
          icon: Icons.track_changes_outlined,
          title: 'الخطوة التالية',
          description:
              'اترك الطلب كما هو وسنحدّثك فور وصول عرض مناسب. يمكنك مغادرة الشاشة والعودة لاحقًا بدون فقدان الحالة.',
        ),
        SizedBox(height: 16.h),
        _buildSurface(
          child: Column(
            children: [
              SizedBox(
                width: 64.w,
                height: 64.w,
                child: CircularProgressIndicator(
                  strokeWidth: 5,
                  color: KadmatColors.brandPrimary,
                ),
              ),
              SizedBox(height: 18.h),
              Text(
                'سيتم إشعارك فور قبول فني للطلب',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.fz,
                  color: KadmatColors.lightTextSecondary,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 18.h),
        KadmatSecondaryButton(
          label: 'إلغاء الطلب',
          icon: Icons.close_rounded,
          onPressed: _cancelJob,
        ),
      ],
    );
  }

  Widget _buildTechnicianFoundState() {
    final status = JobStatus.normalize(_job!.status);
    final hasLockedOfferPrice =
        status == JobStatus.accepted && _job!.technicianPrice != null;

    final title = status == JobStatus.pricePending
        ? 'السعر جاهز للمراجعة'
        : hasLockedOfferPrice
        ? 'تم تثبيت السعر من العرض'
        : 'تم قبول الطلب';
    final subtitle = status == JobStatus.pricePending
        ? 'الفني أرسل السعر المقترح للخدمة. راجعه الآن ثم اتخذ قرارًا واحدًا واضحًا: قبول أو رفض.'
        : hasLockedOfferPrice
        ? 'العرض المقبول أصبح هو السعر المعتمد. يمكنك الآن متابعة التنفيذ دون الحاجة إلى إعادة النقاش.'
        : 'الفني ثبت نفسه على الطلب، والخطوة التالية الآن هي انتظار تحديد السعر قبل بدء التنفيذ.';

    return _buildScrollablePage(
      children: [
        _buildHeroCard(
          icon: status == JobStatus.pricePending
              ? Icons.receipt_long_rounded
              : hasLockedOfferPrice
              ? Icons.verified_rounded
              : Icons.person_pin_circle_rounded,
          title: title,
          subtitle: subtitle,
        ),
        SizedBox(height: 16.h),
        _buildFocusCard(
          icon: status == JobStatus.pricePending
              ? Icons.touch_app_rounded
              : hasLockedOfferPrice
              ? Icons.route_rounded
              : Icons.hourglass_top_rounded,
          title: 'الخطوة التالية',
          description: status == JobStatus.pricePending
              ? 'اقبل السعر إذا كان مناسبًا لك، أو ارفضه للبحث عن فني آخر. لا يوجد إجراء ثالث مطلوب في هذه المرحلة.'
              : hasLockedOfferPrice
              ? 'انتقل لمتابعة التنفيذ فقط. أدوات التواصل أصبحت متاحة لأن الفني صار مثبتًا على الطلب.'
              : 'انتظر السعر من الفني. لا تبدأ أي تنسيق خارجي قبل ظهور السعر واعتماده داخل التطبيق.',
        ),
        if (status == JobStatus.pricePending) ...[
          SizedBox(height: 16.h),
          _buildPriceCard(),
        ],
        SizedBox(height: 16.h),
        _buildTechnicianInfoCard(),
        if (status == JobStatus.accepted && !hasLockedOfferPrice) ...[
          SizedBox(height: 16.h),
          _buildSurface(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.hourglass_top_rounded,
                  color: KadmatColors.stateWarning,
                  size: 20.s,
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    'الفني لم يرسل السعر بعد. ستنتقل الشاشة تلقائيًا إلى مرحلة المراجعة بمجرد اعتماده.',
                    style: TextStyle(
                      fontSize: 13.fz,
                      color: KadmatColors.lightTextSecondary,
                      height: 1.55,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (hasLockedOfferPrice) ...[
          SizedBox(height: 18.h),
          KadmatPrimaryButton(
            label: 'متابعة التنفيذ',
            icon: Icons.arrow_forward_rounded,
            onPressed: () =>
                context.go(AppRoutes.buildCustomerInProgressPath(widget.jobId)),
          ),
        ],
        if (status == JobStatus.pricePending) ...[
          SizedBox(height: 18.h),
          _buildPriceActionButtons(),
        ],
      ],
    );
  }

  Widget _buildPriceCard() {
    return _buildSurface(
      child: Column(
        children: [
          Text(
            'السعر المقترح',
            style: TextStyle(
              fontSize: 13.fz,
              color: KadmatColors.lightTextSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            '${_job!.technicianPrice ?? 0}',
            style: TextStyle(
              fontSize: 48.fz,
              fontWeight: FontWeight.w800,
              color: KadmatColors.brandPrimary,
            ),
          ),
          Text(
            'دينار ليبي',
            style: TextStyle(
              fontSize: 15.fz,
              color: KadmatColors.lightTextSecondary,
            ),
          ),
          if (_job!.priceNotes != null && _job!.priceNotes!.isNotEmpty) ...[
            SizedBox(height: 14.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: KadmatColors.brandAccent,
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Text(
                _job!.priceNotes!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.8.fz,
                  color: KadmatColors.brandSecondary,
                  height: 1.55,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPriceActionButtons() {
    return Row(
      children: [
        Expanded(
          child: KadmatSecondaryButton(
            label: 'رفض السعر',
            icon: Icons.close_rounded,
            onPressed: _isLoading ? null : _rejectPrice,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: KadmatPrimaryButton(
            label: 'قبول السعر',
            icon: Icons.check_circle_outline_rounded,
            onPressed: _isLoading ? null : _acceptPrice,
            isLoading: _isLoading,
          ),
        ),
      ],
    );
  }

  Widget _buildTechnicianInfoCard() {
    if (_job?.technicianId == null) return const SizedBox.shrink();

    final tech = _job!.technician;
    final techName = tech?['full_name'] ?? 'فني محترف';
    final techPhone = tech?['phone'];
    final techRating = (tech?['rating'] as num?)?.toDouble() ?? 5.0;

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
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 32.r,
                backgroundColor: KadmatColors.brandPrimary,
                child: Icon(Icons.person, color: Colors.white, size: 32.s),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الفني المُختص',
                      style: TextStyle(
                        fontSize: 12.fz,
                        color: KadmatColors.lightTextSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      techName,
                      style: TextStyle(
                        fontSize: 18.fz,
                        fontWeight: FontWeight.bold,
                        color: KadmatColors.lightTextPrimary,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        ...List.generate(
                          5,
                          (i) => Icon(
                            i < techRating.toInt()
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.amber,
                            size: 14.s,
                          ),
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          techRating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 12.fz,
                            color: Colors.amber,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (techPhone != null) ...[
            SizedBox(height: 16.h),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        JobCommunicationPolicy.canUseJobCommunication(_job)
                        ? () => _callTechnician(techPhone)
                        : null,
                    icon: const Icon(Icons.phone),
                    label: const Text('اتصل'),
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
                                'otherUserId': _job!.technicianId,
                                'otherUserName': techName,
                                'otherUserImage':
                                    _job!.technician?['profile_image_url'],
                                'otherUserPhone': techPhone,
                              },
                            );
                          }
                        : null,
                    icon: const Icon(Icons.chat),
                    label: const Text('مراسلة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: KadmatColors.brandPrimary,
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
            SizedBox(height: 8.h),
            SizedBox(
              width: double.infinity,
              child: KadmatSecondaryButton(
                label: 'ملف الفني',
                icon: Icons.person_outline_rounded,
                onPressed: () {
                  debugPrint(
                    '👨‍💼 View technician profile: ${_job!.technicianId}',
                  );
                  final technicianId = _job!.technicianId;
                  if (technicianId == null || technicianId.isEmpty) return;
                  _openTechnicianProfile(technicianId);
                },
              ),
            ),
          ],
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

    try {
      context.push(AppRoutes.buildTechnicianProfilePath(normalizedId));
    } catch (_) {
      KadmatToast.showError(
        context,
        title: 'تعذر فتح الملف',
        message: 'فشل الانتقال إلى ملف الفني. حاول مجددًا.',
      );
    }
  }

  Widget _buildInProgressState() {
    return _buildScrollablePage(
      children: [
        _buildHeroCard(
          icon: Icons.route_rounded,
          title: 'الخدمة دخلت مرحلة التنفيذ',
          subtitle:
              'الفني في الطريق أو بدأ تنفيذ المهمة. أفضل إجراء الآن هو المتابعة فقط واستخدام الخريطة عند الحاجة.',
        ),
        SizedBox(height: 16.h),
        _buildFocusCard(
          icon: Icons.map_outlined,
          title: 'الخطوة التالية',
          description:
              'افتح شاشة التتبع إذا أردت رؤية حركة الفني أو تحديثات التنفيذ. لا تحتاج إلى تنسيق جانبي ما دام الطلب يسير داخل التطبيق.',
        ),
        SizedBox(height: 16.h),
        _buildTechnicianInfoCard(),
        SizedBox(height: 16.h),
        _buildSurface(
          child: Row(
            children: [
              Icon(
                Icons.payments_outlined,
                color: KadmatColors.stateSuccess,
                size: 20.s,
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  'السعر المعتمد: ${_job!.technicianPrice ?? 0} دينار ليبي',
                  style: TextStyle(
                    fontSize: 14.fz,
                    color: KadmatColors.stateSuccess,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 18.h),
        KadmatPrimaryButton(
          label: 'فتح التتبع',
          icon: Icons.map_rounded,
          onPressed: () {
            context.push(
              AppRoutes.buildCustomerInProgressPath(widget.jobId),
              extra: {
                'technicianId': _job!.technicianId,
                'lat': _job!.lat,
                'lng': _job!.lng,
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildCompletedState() {
    return _buildScrollablePage(
      children: [
        _buildHeroCard(
          icon: Icons.done_all_rounded,
          title: 'اكتملت الخدمة بنجاح',
          subtitle:
              'الطلب أُغلق وحُفظ داخل حسابك. إذا لم ترسل التقييم بعد فهذه هي الخطوة الوحيدة المتبقية.',
        ),
        SizedBox(height: 16.h),
        _buildFocusCard(
          icon: Icons.star_outline_rounded,
          title: 'الخطوة التالية',
          description: _job!.customerRating == null
              ? 'قيّم الخدمة الآن حتى يكتمل السجل وتظهر تجربتك ضمن تقييمات الفني.'
              : 'لا يوجد إجراء متبقٍ على هذا الطلب. يمكنك الرجوع إلى السجل أو بدء طلب جديد.',
        ),
        SizedBox(height: 18.h),
        if (_job!.customerRating == null)
          KadmatPrimaryButton(
            label: 'قيّم الخدمة',
            icon: Icons.star_rounded,
            onPressed: () =>
                context.push(AppRoutes.buildCustomerRatePath(widget.jobId)),
          )
        else
          _buildSurface(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                5,
                (i) => Icon(
                  i < (_job!.customerRating ?? 0)
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: Colors.amber,
                  size: 30.s,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCancelledState() {
    return _buildScrollablePage(
      children: [
        _buildHeroCard(
          icon: Icons.cancel_outlined,
          title: 'تم إلغاء الطلب',
          subtitle:
              'أُغلق هذا الطلب ولن يستمر التنفيذ عليه. يمكنك العودة إلى الرئيسية أو بدء طلب جديد عندما تحتاج الخدمة.',
        ),
        SizedBox(height: 16.h),
        _buildFocusCard(
          icon: Icons.home_outlined,
          title: 'الخطوة التالية',
          description:
              'ارجع إلى الصفحة الرئيسية إذا أردت إنشاء طلب جديد أو مراجعة الطلبات السابقة.',
        ),
        SizedBox(height: 18.h),
        KadmatPrimaryButton(
          label: 'العودة إلى الرئيسية',
          icon: Icons.home_rounded,
          onPressed: () => context.go(AppRoutes.home),
        ),
      ],
    );
  }

  Widget _buildNoTechnicianFoundState() {
    return _buildScrollablePage(
      children: [
        _buildHeroCard(
          icon: Icons.search_off_rounded,
          title: 'لم يُثبت فني على الطلب بعد',
          subtitle:
              'لم يظهر فني متاح حاليًا، لكن الطلب ما زال تحت المتابعة. يمكنك الانتظار أو إيقافه إذا لم تعد بحاجة للخدمة.',
        ),
        SizedBox(height: 16.h),
        _buildFocusCard(
          icon: Icons.hourglass_bottom_rounded,
          title: 'الخطوة التالية',
          description:
              'لا يلزم أي إجراء الآن إذا كنت تريد الاستمرار في الانتظار. ألغِ الطلب فقط إذا قررت التوقف عن البحث.',
        ),
        SizedBox(height: 16.h),
        _buildSurface(
          child: Column(
            children: [
              SizedBox(
                width: 56.w,
                height: 56.w,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  color: KadmatColors.stateWarning,
                ),
              ),
              SizedBox(height: 14.h),
              Text(
                'سنخبرك فور توفر فني مناسب',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5.fz,
                  color: KadmatColors.lightTextSecondary,
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 18.h),
        KadmatSecondaryButton(
          label: 'إلغاء الطلب',
          icon: Icons.close_rounded,
          onPressed: _cancelJob,
        ),
      ],
    );
  }

  Widget _buildPaymentPendingState() {
    return _buildScrollablePage(
      children: [
        _buildHeroCard(
          icon: Icons.fact_check_outlined,
          title: 'بانتظار تأكيدك لإكمال الخدمة',
          subtitle:
              'الفني أرسل طلب إغلاق الخدمة. راجع التنفيذ ثم أكد الإكمال داخل التطبيق حتى ينتقل الطلب إلى المرحلة النهائية.',
        ),
        SizedBox(height: 16.h),
        _buildFocusCard(
          icon: Icons.task_alt_rounded,
          title: 'الخطوة التالية',
          description:
              'القرار المطلوب الآن هو تأكيد الإكمال فقط إذا انتهت الخدمة كما اتفقتما. لا يتم إغلاق الطلب نهائيًا قبل هذه الخطوة.',
        ),
        SizedBox(height: 16.h),
        _buildTechnicianInfoCard(),
        SizedBox(height: 16.h),
        _buildSurface(
          child: Row(
            children: [
              Icon(
                Icons.payments_outlined,
                color: KadmatColors.stateSuccess,
                size: 20.s,
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  'السعر النهائي: ${_job!.technicianPrice ?? _job!.finalPrice ?? 0} دينار ليبي',
                  style: TextStyle(
                    fontSize: 14.fz,
                    color: KadmatColors.stateSuccess,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 18.h),
        KadmatPrimaryButton(
          label: 'تأكيد إكمال الخدمة',
          icon: Icons.check_circle_rounded,
          onPressed: () {
            context.push(
              AppRoutes.buildCustomerConfirmCompletionPath(widget.jobId),
            );
          },
        ),
      ],
    );
  }

  Widget _buildScrollablePage({required List<Widget> children}) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20.w),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
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
          Container(
            width: 56.w,
            height: 56.w,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(18.r),
            ),
            child: Icon(icon, color: Colors.white, size: 26.s),
          ),
          SizedBox(height: 16.h),
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
              color: Colors.white.withValues(alpha: 0.76),
              fontSize: 13.fz,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFocusCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return _buildSurface(
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
                    fontSize: 12.6.fz,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSurface({required Widget child}) {
    return Container(
      padding: EdgeInsets.all(18.w),
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
      child: child,
    );
  }

  Future<void> _acceptPrice() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(jobRepositoryProvider).confirmPrice(widget.jobId);
      if (mounted) {
        KadmatToast.showSuccess(
          context,
          title: 'تم قبول السعر',
          message: '✅ الفني في الطريق إليك!',
        );
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
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('رفض السعر', style: TextStyle(color: Colors.white)),
        content: const Text(
          'هل تريد البحث عن فني آخر؟',
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
            child: const Text('نعم، ابحث عن آخر'),
          ),
        ],
      ),
    );

    if (result == true) {
      setState(() => _isLoading = true);
      try {
        await ref
            .read(jobRepositoryProvider)
            .cancelJob(widget.jobId, reason: 'رفض السعر');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('جاري البحث عن فني آخر...'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ErrorHandler.handle(context, e);
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _cancelJob() async {
    final result = await showDialog<bool>(
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

    if (result == true) {
      try {
        await ref.read(jobRepositoryProvider).cancelJob(widget.jobId);
        if (mounted) {
          context.go(AppRoutes.home);
        }
      } catch (e) {
        if (mounted) {
          ErrorHandler.handle(context, e);
        }
      }
    }
  }
}
