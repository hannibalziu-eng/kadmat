import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/navigation/job_flow_redirects.dart';
import '../../../core/utils/error_handler.dart';
import '../../../core/utils/service_name_formatter.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('طلباتي'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(watchMyJobsRealtimeProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: _filters
                  .map(
                    (filter) => Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: ChoiceChip(
                        label: Text(filter),
                        selected: _selectedFilter == filter,
                        onSelected: (_) =>
                            setState(() => _selectedFilter = filter),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          Expanded(
            child: jobsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  _OrdersErrorState(message: ErrorHandler.getMessage(error)),
              data: (jobs) {
                final filteredJobs = _applyFilter(jobs);
                if (filteredJobs.isEmpty) {
                  return _OrdersEmptyState(filter: _selectedFilter);
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(watchMyJobsRealtimeProvider);
                    await Future<void>.delayed(
                      const Duration(milliseconds: 300),
                    );
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredJobs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
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
                      serviceName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      technicianName == null || technicianName.trim().isEmpty
                          ? hasAssignedTechnician
                                ? 'تم تعيين فني'
                                : 'بانتظار تعيين الفني'
                          : 'الفني: $technicianName',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _statusLabel(status),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaChip(
                icon: Icons.receipt_long,
                label:
                    'رقم الطلب: ${job.id.substring(0, job.id.length > 8 ? 8 : job.id.length)}',
              ),
              _MetaChip(
                icon: Icons.payments_outlined,
                label: '${totalPrice.toStringAsFixed(2)} ر.س',
              ),
            ],
          ),
          if (!JobCommunicationPolicy.canUseJobCommunication(job)) ...[
            const SizedBox(height: 12),
            Text(
              JobCommunicationPolicy.unavailableMessage,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('متابعة'),
              ),
              if (onChat != null)
                OutlinedButton.icon(
                  onPressed: onChat,
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('مراسلة'),
                ),
              if (onProfile != null)
                OutlinedButton.icon(
                  onPressed: onProfile,
                  icon: const Icon(Icons.person_outline),
                  label: const Text('عرض الفني'),
                ),
              if (onRate != null)
                ElevatedButton.icon(
                  onPressed: onRate,
                  icon: const Icon(Icons.star_outline),
                  label: const Text('تقييم'),
                ),
              if (onCancel != null)
                TextButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('إلغاء'),
                ),
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
        return Colors.green;
      case JobStatus.pendingConfirm:
        return Colors.orange;
      case JobStatus.cancelled:
        return Colors.red;
      case JobStatus.onTheWay:
      case JobStatus.arrived:
      case JobStatus.inProgress:
        return Colors.blue;
      default:
        return Colors.grey;
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
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 16), const SizedBox(width: 6), Text(label)],
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              filter == 'الكل'
                  ? 'لا توجد طلبات بعد'
                  : 'لا توجد طلبات ضمن هذا التصنيف',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'ستظهر هنا الطلبات الحقيقية التي أنشأتها وحالتها الحالية.',
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _OrdersErrorState extends StatelessWidget {
  const _OrdersErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
