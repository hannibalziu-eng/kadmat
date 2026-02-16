import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart' show Position;
import '../../../../core/app_theme.dart';
import '../../../../core/widgets/kadmat_toast.dart';
import '../../../jobs/presentation/job_controller.dart';
import '../../../jobs/domain/job.dart';
import '../../../jobs/data/job_repository.dart';
import '../../../../core/navigation/app_routes.dart';
import '../providers/technician_dispatch_feed_provider.dart';
import '../utils/technician_dispatch_queue.dart';

enum _NewRequestsSortMode { newest, closest, oldestWaiting }

class TechnicianRequestsScreen extends ConsumerStatefulWidget {
  const TechnicianRequestsScreen({super.key});

  @override
  ConsumerState<TechnicianRequestsScreen> createState() =>
      _TechnicianRequestsScreenState();
}

class _TechnicianRequestsScreenState
    extends ConsumerState<TechnicianRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  _NewRequestsSortMode _newRequestsSortMode = _NewRequestsSortMode.newest;
  bool _urgentOnlyNewRequests = false;
  bool _compactNewRequests = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('الطلبات الواردة'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).primaryColor,
          indicatorWeight: 2.h,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
          labelStyle: TextStyle(fontSize: 14.fz, fontWeight: FontWeight.bold),
          unselectedLabelStyle: TextStyle(fontSize: 14.fz),
          tabs: const [
            Tab(text: 'طلبات جديدة'),
            Tab(text: 'بانتظار الموافقة'),
            Tab(text: 'قيد التنفيذ'),
            Tab(text: 'مكتملة'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNewRequestsTab(),
          _buildAwaitingApprovalTab(),
          _buildInProgressTab(),
          _buildCompletedTab(),
        ],
      ),
    );
  }

  Widget _buildNewRequestsTab() {
    final dispatchFeedAsync = ref.watch(technicianDispatchFeedProvider);
    final repository = ref.watch(jobRepositoryProvider);

    return dispatchFeedAsync.when(
      data: (feed) {
        final position = feed.location;
        final visibleJobs = feed.visibleJobs;
        final queueJobs = _prepareNewRequests(visibleJobs, position);
        final filteredOutCount = visibleJobs.length - queueJobs.length;
        final priorityJob = _pickPriorityNewRequest(queueJobs, position);
        final regularJobs = priorityJob == null
            ? queueJobs
            : queueJobs.where((job) => job.id != priorityJob.id).toList();

        debugPrint(
          '📋 NewRequests Tab: visible=${visibleJobs.length}, queue=${queueJobs.length}',
        );

        return FutureBuilder<bool>(
          future: repository.isTechnicianLocked(),
          builder: (context, lockSnapshot) {
            final isLocked = lockSnapshot.data ?? false;

            return Column(
              children: [
                if (isLocked)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      border: Border(
                        bottom: BorderSide(color: Colors.orange, width: 2.h),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lock, color: Colors.orange, size: 24.s),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Text(
                            'لديك طلب قيد التنفيذ. يجب إكماله قبل قبول طلبات جديدة',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 14.fz,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
                  child: _buildNewRequestsControls(),
                ),
                if (queueJobs.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 8.h),
                    child: _buildNewRequestsHealthStrip(queueJobs),
                  ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(technicianDispatchFeedProvider);
                      ref.invalidate(watchNearbyJobsStreamProvider);
                    },
                    child: queueJobs.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.symmetric(
                              horizontal: 24.w,
                              vertical: 120.h,
                            ),
                            children: [
                              Icon(
                                _urgentOnlyNewRequests
                                    ? Icons.alarm_off_rounded
                                    : Icons.inbox_outlined,
                                size: 56.s,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 12.h),
                              Text(
                                _urgentOnlyNewRequests
                                    ? 'لا توجد طلبات عاجلة الآن'
                                    : 'لا توجد طلبات جديدة حالياً',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15.fz,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (filteredOutCount > 0) ...[
                                SizedBox(height: 8.h),
                                Text(
                                  'تم إخفاء $filteredOutCount طلبات قديمة منتهية تلقائياً',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12.fz,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ],
                          )
                        : ListView(
                            padding: EdgeInsets.all(16.w),
                            children: [
                              if (priorityJob != null) ...[
                                _buildPriorityRequestCard(
                                  job: priorityJob,
                                  currentLocation: position,
                                  isLocked: isLocked,
                                ).animate().fadeIn().slideY(begin: 0.1),
                                SizedBox(height: 12.h),
                              ],
                              ...regularJobs.asMap().entries.map((entry) {
                                final index = entry.key;
                                final job = entry.value;
                                return GestureDetector(
                                  onTap: () =>
                                      _showJobPreview(context, job, isLocked),
                                  child:
                                      _buildRequestCard(
                                        job: job,
                                        serviceName:
                                            job.service?['name'] ?? 'خدمة',
                                        customerName:
                                            job.customer?['full_name'] ??
                                            'عميل',
                                        location:
                                            job.addressText ?? 'موقع غير محدد',
                                        time: _formatTimeLabel(job.createdAt),
                                        icon: Icons.work,
                                        iconColor: Colors.blue,
                                        iconBgColor: Colors.blue.shade50,
                                        statusText: _isUrgentJob(job)
                                            ? 'عاجل'
                                            : 'جديد',
                                        statusColor: _isUrgentJob(job)
                                            ? Colors.red
                                            : Colors.orange,
                                        compact: _compactNewRequests,
                                        secondaryInfo: _buildRequestMeta(
                                          job,
                                          position,
                                        ),
                                        secondaryInfoColor: _isUrgentJob(job)
                                            ? Colors.red
                                            : Colors.blueGrey,
                                        showActions: true,
                                        isLocked: isLocked,
                                        onAccept: isLocked
                                            ? null
                                            : () async {
                                                await _acceptJobAndNavigate(
                                                  job.id,
                                                );
                                              },
                                        onReject: () {
                                          if (context.mounted) {
                                            KadmatToast.showInfo(
                                              context,
                                              title: 'تخطي الطلب',
                                              message:
                                                  'يمكنك تجاهل هذا الطلب وسيظهر لغيرك من الفنيين',
                                            );
                                          }
                                        },
                                      ).animate().fadeIn().slideX(
                                        delay: (80 * index).ms,
                                      ),
                                );
                              }),
                              if (filteredOutCount > 0) ...[
                                SizedBox(height: 4.h),
                                Center(
                                  child: Text(
                                    'تم إخفاء $filteredOutCount طلبات قديمة تلقائياً',
                                    style: TextStyle(
                                      fontSize: 11.fz,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                  ),
                ),
              ],
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) {
        final normalized = error.toString().toLowerCase();
        final isLocationError =
            normalized.contains('location') ||
            normalized.contains('permission');

        return Center(
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isLocationError ? Icons.location_off : Icons.wifi_off,
                  size: 64.s,
                  color: Colors.grey,
                ),
                SizedBox(height: 12.h),
                Text(
                  isLocationError
                      ? 'فعّل الموقع لعرض الطلبات القريبة'
                      : 'تعذر تحميل الطلبات الجديدة',
                  style: TextStyle(
                    fontSize: 16.fz,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8.h),
                Text(
                  isLocationError
                      ? 'لا يمكن تحديد الموقع حالياً. تأكد من صلاحية الموقع والمحاولة مجدداً.'
                      : 'تحقق من الاتصال بالإنترنت وسيتم إعادة المحاولة تلقائياً.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.fz, color: Colors.grey),
                ),
                SizedBox(height: 16.h),
                ElevatedButton.icon(
                  onPressed: () {
                    ref.invalidate(technicianDispatchFeedProvider);
                    ref.invalidate(watchNearbyJobsStreamProvider);
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _isUrgentJob(Job job) {
    return TechnicianDispatchQueue.isUrgentJob(job);
  }

  List<Job> _prepareNewRequests(List<Job> jobs, Position currentLocation) {
    return TechnicianDispatchQueue.prepareJobs(
      jobs: jobs,
      sortMode: _toDispatchSortMode(_newRequestsSortMode),
      urgentOnly: _urgentOnlyNewRequests,
      technicianLocation: _toGeoPoint(currentLocation),
    );
  }

  double _distanceToJobMeters(Job job, Position currentLocation) {
    return TechnicianDispatchQueue.distanceToJobMeters(
      job: job,
      technicianLocation: _toGeoPoint(currentLocation),
    );
  }

  String _formatWaitingLabel(DateTime createdAt) {
    return TechnicianDispatchQueue.waitingLabel(createdAt);
  }

  String _buildRequestMeta(Job job, Position currentLocation) {
    final distanceKm = _distanceToJobMeters(job, currentLocation) / 1000;
    return '${_formatWaitingLabel(job.createdAt)} • ${distanceKm.toStringAsFixed(1)} كم';
  }

  Job? _pickPriorityNewRequest(List<Job> jobs, Position currentLocation) {
    return TechnicianDispatchQueue.pickPriorityJob(
      jobs: jobs,
      technicianLocation: _toGeoPoint(currentLocation),
    );
  }

  TechnicianDispatchSortMode _toDispatchSortMode(_NewRequestsSortMode mode) {
    switch (mode) {
      case _NewRequestsSortMode.newest:
        return TechnicianDispatchSortMode.newest;
      case _NewRequestsSortMode.closest:
        return TechnicianDispatchSortMode.closest;
      case _NewRequestsSortMode.oldestWaiting:
        return TechnicianDispatchSortMode.oldestWaiting;
    }
  }

  TechnicianGeoPoint _toGeoPoint(Position position) {
    return TechnicianGeoPoint(lat: position.latitude, lng: position.longitude);
  }

  Widget _buildNewRequestsControls() {
    return Wrap(
      spacing: 8.w,
      runSpacing: 6.h,
      children: [
        ChoiceChip(
          label: const Text('الأحدث'),
          selected: _newRequestsSortMode == _NewRequestsSortMode.newest,
          onSelected: (_) {
            setState(() {
              _newRequestsSortMode = _NewRequestsSortMode.newest;
            });
          },
        ),
        ChoiceChip(
          label: const Text('الأقرب'),
          selected: _newRequestsSortMode == _NewRequestsSortMode.closest,
          onSelected: (_) {
            setState(() {
              _newRequestsSortMode = _NewRequestsSortMode.closest;
            });
          },
        ),
        ChoiceChip(
          label: const Text('الأطول انتظار'),
          selected: _newRequestsSortMode == _NewRequestsSortMode.oldestWaiting,
          onSelected: (_) {
            setState(() {
              _newRequestsSortMode = _NewRequestsSortMode.oldestWaiting;
            });
          },
        ),
        FilterChip(
          label: const Text('عاجل فقط'),
          selected: _urgentOnlyNewRequests,
          onSelected: (selected) {
            setState(() {
              _urgentOnlyNewRequests = selected;
            });
          },
          selectedColor: Colors.red.withValues(alpha: 0.15),
          checkmarkColor: Colors.red,
        ),
        FilterChip(
          label: const Text('عرض مختصر'),
          selected: _compactNewRequests,
          onSelected: (selected) {
            setState(() {
              _compactNewRequests = selected;
            });
          },
        ),
      ],
    );
  }

  Widget _buildNewRequestsHealthStrip(List<Job> jobs) {
    if (jobs.isEmpty) return const SizedBox.shrink();
    final now = DateTime.now();
    final waits = jobs
        .map((job) => now.difference(job.createdAt).inMinutes.clamp(0, 1440))
        .toList();
    final avgWait =
        (waits.fold<int>(0, (sum, item) => sum + item) / waits.length).round();
    final maxWait = waits.fold<int>(0, (max, item) => item > max ? item : max);
    final urgentCount = jobs.where(_isUrgentJob).length;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildHealthMetric(
              icon: Icons.list_alt_rounded,
              title: 'المتاح',
              value: '${jobs.length}',
            ),
          ),
          Expanded(
            child: _buildHealthMetric(
              icon: Icons.alarm,
              title: 'العاجل',
              value: '$urgentCount',
            ),
          ),
          Expanded(
            child: _buildHealthMetric(
              icon: Icons.timelapse_rounded,
              title: 'متوسط الانتظار',
              value: avgWait < 1 ? 'أقل من د' : '$avgWait د',
            ),
          ),
          Expanded(
            child: _buildHealthMetric(
              icon: Icons.schedule_rounded,
              title: 'أطول انتظار',
              value: maxWait < 1 ? 'أقل من د' : '$maxWait د',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthMetric({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, size: 16.s, color: Theme.of(context).primaryColor),
        SizedBox(height: 4.h),
        Text(
          title,
          style: TextStyle(
            fontSize: 10.fz,
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

  Widget _buildPriorityRequestCard({
    required Job job,
    required Position currentLocation,
    required bool isLocked,
  }) {
    final waitingLabel = _formatWaitingLabel(job.createdAt);
    final distanceKm = (_distanceToJobMeters(job, currentLocation) / 1000)
        .toStringAsFixed(1);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Colors.red.withValues(alpha: 0.14),
            Theme.of(context).cardColor.withValues(alpha: 0.96),
          ],
        ),
        borderRadius: BorderRadius.circular(14.r),
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
                'طلب أولوية',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 13.fz,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                waitingLabel,
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 12.fz,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            job.service?['name'] ?? 'خدمة',
            style: TextStyle(fontSize: 16.fz, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4.h),
          Text(
            '${job.customer?['full_name'] ?? 'عميل'} • $distanceKm كم',
            style: TextStyle(
              fontSize: 13.fz,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isLocked
                      ? null
                      : () async {
                          await _acceptJobAndNavigate(job.id);
                        },
                  icon: const Icon(Icons.local_offer_outlined),
                  label: const Text('تقديم عرض'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              OutlinedButton.icon(
                onPressed: () => _showJobPreview(context, job, isLocked),
                icon: Icon(Icons.visibility_rounded, size: 18.s),
                label: const Text('معاينة'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// تبويب "بانتظار الموافقة" - للطلبات التي قبلها الفني وينتظر موافقة العميل على السعر
  Widget _buildAwaitingApprovalTab() {
    final myJobsAsync = ref.watch(myJobsProvider);

    return myJobsAsync.when(
      data: (jobs) {
        // فقط الطلبات المقبولة وبانتظار موافقة العميل على السعر
        final awaitingJobs = jobs
            .where((j) => j.status == 'accepted' || j.status == 'price_pending')
            .toList();

        debugPrint('📋 Awaiting Approval Tab: ${awaitingJobs.length} jobs');

        if (awaitingJobs.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(24.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.hourglass_empty, size: 80.s, color: Colors.grey),
                  SizedBox(height: 16.h),
                  const Text(
                    'لا توجد طلبات بانتظار الموافقة',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(myJobsProvider);
            await ref.read(myJobsProvider.future);
          },
          child: ListView.builder(
            padding: EdgeInsets.all(16.w),
            itemCount: awaitingJobs.length,
            itemBuilder: (context, index) {
              final job = awaitingJobs[index];
              return _buildRequestCard(
                job: job,
                serviceName: job.service?['name'] ?? 'خدمة',
                customerName: job.customer?['full_name'] ?? 'عميل',
                location: job.addressText ?? 'موقع غير محدد',
                time: _formatTimeLabel(job.createdAt),
                icon: Icons.pending_actions,
                iconColor: Colors.amber,
                iconBgColor: Colors.amber.shade50,
                statusText: _getAwaitingStatusText(job.status),
                statusColor: Colors.amber,
                showActions: false,
                showSetPriceButton: job.status == 'accepted',
                showWaitingPriceApproval: job.status == 'price_pending',
                onSetPrice: () {
                  debugPrint('💰 Navigate to set price: ${job.id}');
                  context.go(AppRoutes.buildTechnicianSetPricePath(job.id));
                },
              ).animate().fadeIn().slideX();
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) {
        debugPrint('❌ Awaiting Approval Error: $error');
        return _buildTabErrorState(
          title: 'تعذر تحميل الطلبات بانتظار الموافقة',
          onRetry: () => ref.invalidate(myJobsProvider),
        );
      },
    );
  }

  String _getAwaitingStatusText(String status) {
    switch (status) {
      case 'accepted':
        return 'بانتظار تحديد السعر';
      case 'price_pending':
        return 'بانتظار موافقة العميل';
      default:
        return 'بانتظار';
    }
  }

  Widget _buildInProgressTab() {
    // Continuously watch myJobs - rebuilds whenever status changes
    final myJobsAsync = ref.watch(myJobsProvider);

    return myJobsAsync.when(
      data: (jobs) {
        debugPrint(
          '📋 InProgress Tab: Total=${jobs.length}, Statuses=${jobs.map((j) => j.status).toList()}',
        );

        // الطلبات النشطة بعد موافقة العميل على السعر:
        // on_the_way -> arrived -> in_progress
        final inProgressJobs = jobs
            .where(
              (j) =>
                  j.status == 'on_the_way' ||
                  j.status == 'arrived' ||
                  j.status == 'in_progress',
            )
            .toList();

        debugPrint('✅ Filtered in_progress jobs=${inProgressJobs.length}');

        if (inProgressJobs.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(24.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 80.s, color: Colors.grey),
                  SizedBox(height: 16.h),
                  const Text(
                    'لا توجد طلبات قيد التنفيذ',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            // Force refresh when user pulls down
            ref.invalidate(myJobsProvider);
            await ref.read(myJobsProvider.future);
          },
          child: ListView.builder(
            padding: EdgeInsets.all(16.w),
            itemCount: inProgressJobs.length,
            itemBuilder: (context, index) {
              final job = inProgressJobs[index];
              debugPrint('🎨 Building card: ${job.id}, status=${job.status}');

              return _buildRequestCard(
                job: job,
                serviceName: job.service?['name'] ?? 'خدمة',
                customerName: job.customer?['full_name'] ?? 'عميل',
                location: job.addressText ?? 'موقع غير محدد',
                time: _formatTimeLabel(job.createdAt),
                icon: Icons.work_history,
                iconColor: Colors.cyan,
                iconBgColor: Colors.cyan.shade50,
                statusText: _getStatusText(job.status),
                statusColor: _getStatusColor(job.status),
                showActions: false,
                showSetPriceButton: job.status == 'accepted',
                showWaitingPriceApproval: job.status == 'price_pending',
                showArrivedButton: job.status == 'on_the_way',
                showStartWorkButton: job.status == 'arrived',
                showCompleteButton: job.status == 'in_progress',
                onArrived: () async {
                  await ref
                      .read(jobRepositoryProvider)
                      .updateTechnicianProgress(job.id, progress: 'arrived');
                  ref.invalidate(myJobsProvider);
                },
                onStartWork: () async {
                  await ref
                      .read(jobRepositoryProvider)
                      .updateTechnicianProgress(job.id, progress: 'start_work');
                  ref.invalidate(myJobsProvider);
                },
                onSetPrice: () {
                  debugPrint('💰 Navigate to set price: ${job.id}');
                  context.go(AppRoutes.buildTechnicianSetPricePath(job.id));
                },
                onComplete: () async {
                  debugPrint('✔️ Completing job: ${job.id}');
                  await ref
                      .read(jobControllerProvider.notifier)
                      .completeJob(job.id);
                  ref.invalidate(myJobsProvider);
                },
              ).animate().fadeIn().slideX();
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) {
        debugPrint('❌ InProgress Error: $error, $stackTrace');
        return _buildTabErrorState(
          title: 'تعذر تحميل الطلبات قيد التنفيذ',
          onRetry: () => ref.invalidate(myJobsProvider),
        );
      },
    );
  }

  Widget _buildCompletedTab() {
    final myJobsAsync = ref.watch(myJobsProvider);

    return myJobsAsync.when(
      data: (jobs) {
        final completedJobs = jobs
            .where((j) => j.status == 'completed')
            .toList();

        if (completedJobs.isEmpty) {
          return Center(child: Text('لا توجد طلبات مكتملة'));
        }

        return ListView.builder(
          padding: EdgeInsets.all(16.w),
          itemCount: completedJobs.length,
          itemBuilder: (context, index) {
            final job = completedJobs[index];
            return _buildRequestCard(
              job: job,
              serviceName: job.service?['name'] ?? 'خدمة',
              customerName: job.customer?['full_name'] ?? 'عميل',
              location: job.addressText ?? 'موقع غير محدد',
              time: _formatTimeLabel(job.createdAt),
              icon: Icons.check_circle_outline,
              iconColor: Colors.green,
              iconBgColor: Colors.green.shade50,
              statusText: 'مكتمل',
              statusColor: Colors.green,
              showActions: false,
              showRating: true,
              rating: (job.customer?['rating'] as num?)?.toDouble() ?? 0.0,
            ).animate().fadeIn().slideX();
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _buildTabErrorState(
        title: 'تعذر تحميل الطلبات المكتملة',
        onRetry: () => ref.invalidate(myJobsProvider),
      ),
    );
  }

  Widget _buildTabErrorState({
    required String title,
    required VoidCallback onRetry,
  }) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 56.s, color: Colors.orange),
            SizedBox(height: 12.h),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16.fz, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10.h),
            Text(
              'أعد المحاولة بعد ثوانٍ',
              style: TextStyle(fontSize: 13.fz, color: Colors.grey),
            ),
            SizedBox(height: 16.h),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeLabel(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} يوم';

    return '${time.year}/${time.month.toString().padLeft(2, '0')}/${time.day.toString().padLeft(2, '0')}';
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'accepted':
        return 'في انتظار تحديد السعر';
      case 'price_pending':
        return 'في انتظار موافقة العميل';
      case 'on_the_way':
        return 'في الطريق إلى العميل';
      case 'arrived':
        return 'وصلت إلى موقع العميل';
      case 'in_progress':
        return 'قيد التنفيذ';
      default:
        return 'قيد التنفيذ';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.orange;
      case 'price_pending':
        return Colors.amber;
      case 'on_the_way':
        return Colors.blueAccent;
      case 'arrived':
        return Colors.teal;
      case 'in_progress':
        return Colors.blue;
      default:
        return Colors.blue;
    }
  }

  Future<void> _acceptJobAndNavigate(String jobId) async {
    if (!mounted) return;
    await context.push(AppRoutes.buildTechnicianBiddingPath(jobId));
  }

  /// Show job preview BottomSheet
  void _showJobPreview(BuildContext context, Job job, bool isLocked) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: EdgeInsets.all(24.w),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.grey,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            SizedBox(height: 20.h),

            // Service Name
            Text(
              job.service?['name'] ?? 'خدمة',
              style: TextStyle(fontSize: 20.fz, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16.h),

            // Customer Info
            Row(
              children: [
                Icon(Icons.person, size: 20.s, color: Colors.grey),
                SizedBox(width: 8.w),
                Text(
                  job.customer?['full_name'] ?? 'عميل',
                  style: TextStyle(fontSize: 14.fz, color: Colors.grey),
                ),
              ],
            ),
            SizedBox(height: 12.h),

            // Location
            Row(
              children: [
                Icon(Icons.location_on, size: 20.s, color: Colors.grey),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    job.addressText ?? 'موقع غير محدد',
                    style: TextStyle(fontSize: 14.fz, color: Colors.grey),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),

            // Description Preview
            if (job.description != null && job.description!.isNotEmpty) ...[
              Text(
                'الوصف:',
                style: TextStyle(fontSize: 14.fz, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8.h),
              Text(
                job.description!.length > 100
                    ? '${job.description!.substring(0, 100)}...'
                    : job.description!,
                style: TextStyle(fontSize: 14.fz, color: Colors.grey),
              ),
              SizedBox(height: 16.h),
            ],

            // Lock Warning (if locked)
            if (isLocked)
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: Colors.orange),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock, color: Colors.orange, size: 20.s),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        'لا يمكنك قبول طلبات جديدة حالياً',
                        style: TextStyle(color: Colors.orange, fontSize: 12.fz),
                      ),
                    ),
                  ],
                ),
              ),

            SizedBox(height: 20.h),

            // View Details Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLocked
                    ? null
                    : () async {
                        Navigator.pop(context);
                        await _acceptJobAndNavigate(job.id);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: const Text('عرض التفاصيل والقبول'),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestCard({
    required Job job,
    required String serviceName,
    required String customerName,
    required String location,
    required String time,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String statusText,
    required Color statusColor,
    bool compact = false,
    String? secondaryInfo,
    Color? secondaryInfoColor,
    bool showActions = false,
    bool showCompleteButton = false,
    bool showArrivedButton = false,
    bool showStartWorkButton = false,
    bool showSetPriceButton = false,
    bool showWaitingPriceApproval = false,
    bool showRating = false,
    double rating = 0.0,
    bool isLocked = false, // NEW: Lock status
    VoidCallback? onAccept,
    VoidCallback? onReject,
    VoidCallback? onComplete,
    VoidCallback? onArrived,
    VoidCallback? onStartWork,
    VoidCallback? onSetPrice,
  }) {
    return Card(
      margin: EdgeInsets.only(bottom: 16.h),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: InkWell(
        onTap: () =>
            context.push(AppRoutes.buildTechnicianJobDetailPath(job.id)),
        borderRadius: BorderRadius.circular(16.r),
        child: Padding(
          padding: EdgeInsets.all(compact ? 12.w : 16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Icon, Title, Status
              Row(
                children: [
                  Container(
                    width: compact ? 42.w : 48.w,
                    height: compact ? 42.h : 48.h,
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(
                      icon,
                      color: iconColor,
                      size: compact ? 22.s : 28.s,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          serviceName,
                          style: TextStyle(
                            fontSize: compact ? 14.fz : 16.fz,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          'عميل: $customerName',
                          style: TextStyle(
                            fontSize: compact ? 11.fz : 12.fz,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12.fz,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              // Location
              Row(
                children: [
                  Icon(Icons.location_on, size: 16.s, color: Colors.grey),
                  SizedBox(width: 4.w),
                  Expanded(
                    child: Text(
                      location,
                      style: TextStyle(fontSize: 12.fz, color: Colors.grey),
                      maxLines: compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              // Time
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16.s, color: Colors.grey),
                  SizedBox(width: 4.w),
                  Text(
                    time,
                    style: TextStyle(fontSize: 12.fz, color: Colors.grey),
                  ),
                ],
              ),
              if (secondaryInfo != null) ...[
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Icon(
                      Icons.timelapse_rounded,
                      size: 16.s,
                      color: secondaryInfoColor ?? Colors.blueGrey,
                    ),
                    SizedBox(width: 4.w),
                    Expanded(
                      child: Text(
                        secondaryInfo,
                        style: TextStyle(
                          fontSize: 12.fz,
                          color: secondaryInfoColor ?? Colors.blueGrey,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              // Rating (for completed)
              if (showRating) ...[
                SizedBox(height: 12.h),
                Row(
                  children: [
                    ...List.generate(5, (index) {
                      return Icon(
                        index < rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 18.s,
                      );
                    }),
                    SizedBox(width: 8.w),
                    Text(
                      '($rating)',
                      style: TextStyle(fontSize: 12.fz, color: Colors.grey),
                    ),
                  ],
                ),
              ],
              SizedBox(height: 12.h),

              if (showActions) ...[
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isLocked ? null : onAccept,
                        icon: const Icon(Icons.local_offer_outlined),
                        label: Text(isLocked ? 'مقفول' : 'تقديم عرض'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isLocked
                              ? Colors.grey
                              : AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onReject,
                        icon: const Icon(Icons.skip_next_rounded),
                        label: const Text('تخطي'),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
              ],

              // ACTIONS
              if (showSetPriceButton)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onSetPrice,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    child: const Text('تحديد السعر'),
                  ),
                ),

              if (showWaitingPriceApproval)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: Colors.amber),
                  ),
                  child: const Center(
                    child: Text(
                      'بانتظار موافقة العميل',
                      style: TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              if (showCompleteButton)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onComplete,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('إكمال الطلب'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                  ),
                ),

              if (showArrivedButton)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onArrived,
                    icon: const Icon(Icons.place),
                    label: const Text('تأكيد الوصول'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                  ),
                ),

              if (showStartWorkButton)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onStartWork,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('بدء العمل'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                  ),
                ),

              SizedBox(height: 12.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'عرض التفاصيل',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontSize: 12.fz,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 12.s,
                    color: Theme.of(context).primaryColor,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
