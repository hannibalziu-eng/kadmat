import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/kadmat_tokens.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/navigation/job_flow_redirects.dart';
import '../../../core/utils/error_handler.dart';
import '../../../core/utils/service_name_formatter.dart';
import '../../../core/widgets/kadmat_components.dart';
import '../../jobs/data/job_repository.dart';
import '../../jobs/domain/job.dart';
import '../../jobs/domain/job_communication_policy.dart';
import '../../jobs/domain/job_status.dart';
import '../../jobs/presentation/job_controller.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  String _selectedFilter = 'الكل';

  static const List<String> _filters = [
    'الكل',
    'قيد المتابعة',
    'مكتملة',
    'ملغاة',
  ];

  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(watchMyJobsRealtimeProvider);
    final jobs = jobsAsync.valueOrNull ?? const <Job>[];
    final activeCount = jobs
        .where(
          (job) => {
            JobStatus.pending,
            JobStatus.searching,
            JobStatus.accepted,
            JobStatus.pricePending,
            JobStatus.onTheWay,
            JobStatus.arrived,
            JobStatus.inProgress,
            JobStatus.pendingConfirm,
            JobStatus.noTechnicianFound,
          }.contains(JobStatus.normalize(job.status)),
        )
        .length;
    final completedCount = jobs
        .where(
          (job) => {
            JobStatus.completed,
            JobStatus.rated,
          }.contains(JobStatus.normalize(job.status)),
        )
        .length;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 0),
              child: Column(
                children: [
                  _buildHeader(
                    context,
                    activeCount: activeCount,
                    completedCount: completedCount,
                  ),
                  SizedBox(height: 18.h),
                  _buildFilterStrip(context),
                ],
              ),
            ),
            Expanded(
              child: jobsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator.adaptive()),
                error: (error, _) => _OrdersErrorState(
                  message: ErrorHandler.getMessage(error),
                  onRetry: () => ref.invalidate(watchMyJobsRealtimeProvider),
                ),
                data: (jobs) {
                  final filteredJobs = _applyFilter(jobs);
                  if (filteredJobs.isEmpty) {
                    return _OrdersEmptyState(filter: _selectedFilter);
                  }

                  return RefreshIndicator.adaptive(
                    onRefresh: () async {
                      ref.invalidate(watchMyJobsRealtimeProvider);
                      await Future<void>.delayed(
                        const Duration(milliseconds: 300),
                      );
                    },
                    child: ListView.separated(
                      padding: EdgeInsets.fromLTRB(18.w, 8.h, 18.w, 28.h),
                      itemCount: filteredJobs.length,
                      separatorBuilder: (_, _) => SizedBox(height: 14.h),
                      itemBuilder: (context, index) {
                        final job = filteredJobs[index];
                        return _OrderCard(
                          job: job,
                          onOpen: () => _openJob(job),
                          onChat:
                              JobCommunicationPolicy.canUseJobCommunication(job)
                              ? () => _openChat(job)
                              : null,
                          onProfile:
                              job.technicianId != null &&
                                  job.technicianId!.trim().isNotEmpty
                              ? () => context.push(
                                  AppRoutes.buildTechnicianProfilePath(
                                    job.technicianId!,
                                  ),
                                )
                              : null,
                          onRate: _canRate(job)
                              ? () => context.push(
                                  AppRoutes.buildCustomerRatePath(job.id),
                                )
                              : null,
                          onCancel: _canCancel(job)
                              ? () => _cancelJob(job)
                              : null,
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context, {
    required int activeCount,
    required int completedCount,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28.r),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF18323C), Color(0xFF102129)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'طلباتك في مكان واحد',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24.fz,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'تابع حالة كل طلب بسرعة، وافتح الشات أو التقييم من نفس الشاشة بدون تنقل مشتت.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.74),
                        fontSize: 13.fz,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 10.w),
              IconButton.filledTonal(
                onPressed: () => ref.invalidate(watchMyJobsRealtimeProvider),
                icon: const Icon(Icons.refresh_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.14),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18.r),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 18.h),
          Row(
            children: [
              Expanded(
                child: _HeaderMetricCard(
                  label: 'قيد المتابعة',
                  value: '$activeCount',
                  icon: Icons.route_rounded,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _HeaderMetricCard(
                  label: 'مكتملة',
                  value: '$completedCount',
                  icon: Icons.verified_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterStrip(BuildContext context) {
    return SizedBox(
      height: 44.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, _) => SizedBox(width: 8.w),
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = _selectedFilter == filter;
          return AnimatedContainer(
            duration: KadmatMotion.medium,
            decoration: BoxDecoration(
              color: isSelected ? KadmatColors.brandPrimary : Colors.white,
              borderRadius: BorderRadius.circular(999.r),
              border: Border.all(
                color: isSelected
                    ? KadmatColors.brandPrimary
                    : KadmatColors.lightBorder,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(999.r),
              onTap: () => setState(() => _selectedFilter = filter),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                child: Text(
                  filter,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : KadmatColors.lightTextPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.fz,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Job> _applyFilter(List<Job> jobs) {
    return jobs.where((job) {
      final status = JobStatus.normalize(job.status);
      switch (_selectedFilter) {
        case 'قيد المتابعة':
          return {
            JobStatus.pending,
            JobStatus.searching,
            JobStatus.accepted,
            JobStatus.pricePending,
            JobStatus.onTheWay,
            JobStatus.arrived,
            JobStatus.inProgress,
            JobStatus.pendingConfirm,
            JobStatus.noTechnicianFound,
          }.contains(status);
        case 'مكتملة':
          return status == JobStatus.completed || status == JobStatus.rated;
        case 'ملغاة':
          return status == JobStatus.cancelled;
        default:
          return true;
      }
    }).toList();
  }

  bool _canCancel(Job job) {
    final status = JobStatus.normalize(job.status);
    return {
      JobStatus.pending,
      JobStatus.searching,
      JobStatus.accepted,
      JobStatus.pricePending,
      JobStatus.onTheWay,
      JobStatus.noTechnicianFound,
    }.contains(status);
  }

  bool _canRate(Job job) {
    final status = JobStatus.normalize(job.status);
    return status == JobStatus.completed && job.customerRating == null;
  }

  void _openJob(Job job) {
    final normalizedStatus = JobStatus.normalize(job.status);
    final route = customerRouteForJobStatus(status: job.status, jobId: job.id);

    if (route != null) {
      context.push(route);
      return;
    }

    if (normalizedStatus == JobStatus.pending ||
        normalizedStatus == JobStatus.searching ||
        normalizedStatus == JobStatus.noTechnicianFound) {
      context.push(AppRoutes.buildCustomerSearchingPath(job.id));
    }
  }

  void _openChat(Job job) {
    context.push(
      AppRoutes.buildJobChatPath(job.id),
      extra: {
        'otherUserName': job.technician?['full_name']?.toString() ?? 'الفني',
        'otherUserImage': job.technician?['profile_image_url']?.toString(),
        'otherUserPhone': job.technician?['phone']?.toString(),
      },
    );
  }

  Future<void> _cancelJob(Job job) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إلغاء الطلب'),
        content: const Text('هل تريد إلغاء هذا الطلب؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('تراجع'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('إلغاء الطلب'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) {
      return;
    }

    try {
      await ref.read(jobRepositoryProvider).cancelJob(job.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم إلغاء الطلب')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ErrorHandler.getMessage(error))));
    }
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.job,
    required this.onOpen,
    this.onChat,
    this.onProfile,
    this.onRate,
    this.onCancel,
  });

  final Job job;
  final VoidCallback onOpen;
  final VoidCallback? onChat;
  final VoidCallback? onProfile;
  final VoidCallback? onRate;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final status = JobStatus.normalize(job.status);
    final serviceName = formatServiceDisplayName(job.service);
    final technicianName = job.technician?['full_name']?.toString();
    final hasAssignedTechnician =
        job.technicianId != null && job.technicianId!.trim().isNotEmpty;
    final statusColor = _statusColor(status);
    final totalPrice =
        job.finalPrice ?? job.technicianPrice ?? job.initialPrice ?? 0.0;
    final createdLabel = '${job.createdAt.day}/${job.createdAt.month}';
    final primaryActionLabel = onRate != null ? 'تقييم الآن' : 'متابعة';
    final primaryActionIcon = onRate != null
        ? Icons.star_outline_rounded
        : Icons.arrow_outward_rounded;
    final primaryAction = onRate ?? onOpen;

    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: KadmatColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
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
                width: 48.w,
                height: 48.w,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      KadmatColors.brandAccent,
                      KadmatColors.brandAccent.withValues(alpha: 0.55),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: Icon(
                  Icons.build_circle_outlined,
                  color: KadmatColors.brandSecondary,
                  size: 22.s,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      serviceName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      technicianName == null || technicianName.trim().isEmpty
                          ? hasAssignedTechnician
                                ? 'تم تعيين فني'
                                : 'بانتظار تعيين الفني'
                          : 'الفني: $technicianName',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999.r),
                ),
                child: Text(
                  _statusLabel(status),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.fz,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              _MetaChip(
                icon: Icons.receipt_long_outlined,
                label:
                    'رقم الطلب: ${job.id.substring(0, job.id.length > 8 ? 8 : job.id.length)}',
              ),
              _MetaChip(
                icon: Icons.event_note_outlined,
                label: 'تاريخ الإنشاء: $createdLabel',
              ),
              _MetaChip(
                icon: Icons.payments_outlined,
                label: '${totalPrice.toStringAsFixed(2)} ر.س',
              ),
            ],
          ),
          if (!JobCommunicationPolicy.canUseJobCommunication(job)) ...[
            SizedBox(height: 14.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E6),
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: KadmatColors.stateWarning,
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      JobCommunicationPolicy.unavailableMessage,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF8A5A15),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: 14.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(18.r),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.flag_outlined,
                  size: 18.s,
                  color: KadmatColors.lightTextSecondary,
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    _nextStepText(status),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: KadmatColors.lightTextSecondary,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: KadmatPrimaryButton(
                  label: primaryActionLabel,
                  icon: primaryActionIcon,
                  onPressed: primaryAction,
                  backgroundColor: onRate != null
                      ? KadmatColors.stateSuccess
                      : null,
                  foregroundColor: onRate != null ? Colors.white : null,
                ),
              ),
              if (onChat != null ||
                  onProfile != null ||
                  onRate != null ||
                  onCancel != null) ...[
                SizedBox(width: 10.w),
                _OrderOverflowMenu(
                  onOpen: onOpen,
                  onChat: onChat,
                  onProfile: onProfile,
                  onRate: onRate,
                  onCancel: onCancel,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static Color _statusColor(String status) {
    switch (status) {
      case JobStatus.completed:
      case JobStatus.rated:
        return KadmatColors.stateSuccess;
      case JobStatus.pendingConfirm:
        return KadmatColors.stateWarning;
      case JobStatus.cancelled:
        return KadmatColors.stateError;
      case JobStatus.onTheWay:
      case JobStatus.arrived:
      case JobStatus.inProgress:
        return KadmatColors.stateInfo;
      default:
        return KadmatColors.lightTextSecondary;
    }
  }

  static String _statusLabel(String status) {
    switch (status) {
      case JobStatus.pending:
        return 'معلق';
      case JobStatus.searching:
        return 'جاري البحث';
      case JobStatus.accepted:
        return 'تم القبول';
      case JobStatus.pricePending:
        return 'بانتظار السعر';
      case JobStatus.onTheWay:
        return 'في الطريق';
      case JobStatus.arrived:
        return 'وصل الفني';
      case JobStatus.inProgress:
        return 'قيد التنفيذ';
      case JobStatus.pendingConfirm:
        return 'بانتظار التأكيد';
      case JobStatus.completed:
        return 'مكتمل';
      case JobStatus.rated:
        return 'مقَيَّم';
      case JobStatus.cancelled:
        return 'ملغي';
      case JobStatus.noTechnicianFound:
        return 'لم يتم العثور على فني';
      default:
        return status;
    }
  }

  static String _nextStepText(String status) {
    switch (status) {
      case JobStatus.searching:
      case JobStatus.pending:
        return 'الخطوة التالية: انتظر العروض المناسبة أو افتح الطلب لمراجعة حالته الحالية.';
      case JobStatus.accepted:
      case JobStatus.pricePending:
        return 'الخطوة التالية: راجع السعر أو تفاصيل التنفيذ ثم أكمل القرار من داخل الطلب.';
      case JobStatus.onTheWay:
      case JobStatus.arrived:
      case JobStatus.inProgress:
        return 'الخطوة التالية: افتح الطلب لمتابعة الفني، ثم استخدم المحادثة عند الحاجة.';
      case JobStatus.pendingConfirm:
        return 'الخطوة التالية: راجع النتيجة داخل الطلب ثم أكّد اكتمال الخدمة.';
      case JobStatus.completed:
        return 'الخطوة التالية: ابدأ التقييم الآن لإغلاق التجربة بشكل كامل.';
      case JobStatus.rated:
        return 'تم إغلاق الطلب. يمكنك فتح التفاصيل للاطلاع على السجل النهائي.';
      case JobStatus.cancelled:
        return 'الطلب ملغي. افتح التفاصيل إذا احتجت مراجعة ما حدث.';
      case JobStatus.noTechnicianFound:
        return 'لم يصل فني مناسب بعد. افتح الطلب إذا أردت المراجعة أو الإلغاء.';
      default:
        return 'الخطوة التالية: افتح الطلب لمتابعة الحالة واتخاذ القرار المناسب.';
    }
  }
}

enum _OrderAction { open, chat, profile, rate, cancel }

class _OrderOverflowMenu extends StatelessWidget {
  const _OrderOverflowMenu({
    required this.onOpen,
    this.onChat,
    this.onProfile,
    this.onRate,
    this.onCancel,
  });

  final VoidCallback onOpen;
  final VoidCallback? onChat;
  final VoidCallback? onProfile;
  final VoidCallback? onRate;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_OrderAction>(
      tooltip: 'خيارات إضافية',
      onSelected: (action) {
        switch (action) {
          case _OrderAction.open:
            onOpen();
            break;
          case _OrderAction.chat:
            onChat?.call();
            break;
          case _OrderAction.profile:
            onProfile?.call();
            break;
          case _OrderAction.rate:
            onRate?.call();
            break;
          case _OrderAction.cancel:
            onCancel?.call();
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: _OrderAction.open,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.open_in_new_rounded),
            title: Text('فتح التفاصيل'),
          ),
        ),
        if (onChat != null)
          const PopupMenuItem(
            value: _OrderAction.chat,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.chat_bubble_outline_rounded),
              title: Text('مراسلة'),
            ),
          ),
        if (onProfile != null)
          const PopupMenuItem(
            value: _OrderAction.profile,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.person_outline_rounded),
              title: Text('عرض الفني'),
            ),
          ),
        if (onRate != null)
          const PopupMenuItem(
            value: _OrderAction.rate,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.star_outline_rounded),
              title: Text('تقييم'),
            ),
          ),
        if (onCancel != null)
          const PopupMenuItem(
            value: _OrderAction.cancel,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.cancel_outlined),
              title: Text('إلغاء الطلب'),
            ),
          ),
      ],
      child: Container(
        width: 48.w,
        height: 48.w,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: KadmatColors.lightBorder),
        ),
        child: Icon(
          Icons.more_horiz_rounded,
          size: 22.s,
          color: KadmatColors.lightTextPrimary,
        ),
      ),
    );
  }
}

class _HeaderMetricCard extends StatelessWidget {
  const _HeaderMetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 38.w,
            height: 38.w,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Icon(icon, color: Colors.white, size: 18.s),
          ),
          SizedBox(width: 10.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18.fz,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 12.fz,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15.s, color: KadmatColors.lightTextSecondary),
          SizedBox(width: 6.w),
          Text(label),
        ],
      ),
    );
  }
}

class _OrdersEmptyState extends StatelessWidget {
  const _OrdersEmptyState({required this.filter});

  final String filter;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(24.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28.r),
            border: Border.all(color: KadmatColors.lightBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72.w,
                height: 72.w,
                decoration: BoxDecoration(
                  color: KadmatColors.brandAccent,
                  borderRadius: BorderRadius.circular(24.r),
                ),
                child: Icon(
                  Icons.inbox_outlined,
                  size: 34.s,
                  color: KadmatColors.brandSecondary,
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                filter == 'الكل'
                    ? 'لا توجد طلبات بعد'
                    : 'لا توجد طلبات ضمن هذا التصنيف',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8.h),
              Text(
                'ستظهر هنا الطلبات الحقيقية التي أنشأتها وحالتها الحالية بخطوات واضحة وسهلة المتابعة.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 18.h),
              KadmatPrimaryButton(
                label: 'إنشاء طلب جديد',
                icon: Icons.add_rounded,
                onPressed: () => context.push(AppRoutes.customerCreateRequest),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrdersErrorState extends StatelessWidget {
  const _OrdersErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(24.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28.r),
            border: Border.all(color: KadmatColors.lightBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 56,
                color: KadmatColors.stateError,
              ),
              SizedBox(height: 16.h),
              Text(message, textAlign: TextAlign.center),
              SizedBox(height: 16.h),
              KadmatPrimaryButton(
                label: 'إعادة المحاولة',
                icon: Icons.refresh_rounded,
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
