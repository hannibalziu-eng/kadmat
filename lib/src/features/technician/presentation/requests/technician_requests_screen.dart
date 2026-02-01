import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/kadmat_toast.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../jobs/presentation/job_controller.dart';
import '../../../jobs/domain/job.dart';
import '../../../jobs/data/job_repository.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/router.dart';
import '../../../auth/data/auth_repository.dart';

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
    final locationAsync = ref.watch(locationStreamProvider);

    return locationAsync.when(
      data: (position) {
        final lat = position.latitude;
        final lng = position.longitude;

        final nearbyJobsAsync = ref.watch(
          watchNearbyJobsStreamProvider(lat: lat, lng: lng),
        );

        // Watch technician lock status
        final repository = ref.watch(jobRepositoryProvider);

        return nearbyJobsAsync.when(
          data: (jobs) {
            debugPrint('📋 NewRequests Tab: Total=${jobs.length}');

            return FutureBuilder<bool>(
              future: repository.isTechnicianLocked(),
              builder: (context, lockSnapshot) {
                final isLocked = lockSnapshot.data ?? false;

                return Column(
                  children: [
                    // Lock Warning Banner
                    if (isLocked)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16.w),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.orange,
                              width: 2.h,
                            ),
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

                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(
                            watchNearbyJobsStreamProvider(lat: lat, lng: lng),
                          );
                          await ref
                              .read(
                                watchNearbyJobsStreamProvider(
                                  lat: lat,
                                  lng: lng,
                                ).future,
                              )
                              .catchError((_) => <Job>[]);
                        },
                        child: jobs.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: const [
                                  SizedBox(height: 120),
                                  Center(
                                    child: Text('لا توجد طلبات جديدة حالياً'),
                                  ),
                                ],
                              )
                            : ListView.builder(
                                padding: EdgeInsets.all(16.w),
                                itemCount: jobs.length,
                                itemBuilder: (context, index) {
                                  final job = jobs[index];
                                  return GestureDetector(
                                    onTap: () =>
                                        _showJobPreview(context, job, isLocked),
                                    child: _buildRequestCard(
                                      job: job,
                                      serviceName:
                                          job.service?['name'] ?? 'خدمة',
                                      customerName:
                                          job.customer?['full_name'] ?? 'عميل',
                                      location:
                                          job.addressText ?? 'موقع غير محدد',
                                      time: job.createdAt.toString(),
                                      icon: Icons.work,
                                      iconColor: Colors.blue,
                                      iconBgColor: Colors.blue.shade50,
                                      statusText: 'جديد',
                                      statusColor: Colors.orange,
                                      showActions: true,
                                      isLocked: isLocked,
                                      onAccept: isLocked
                                          ? null
                                          : () async {
                                              debugPrint(
                                                '✅ Accepting job: ${job.id}',
                                              );
                                              try {
                                                // Use goRouterProvider for robust navigation
                                                final goRouter = ref.read(
                                                  goRouterProvider,
                                                );

                                                await ref
                                                    .read(
                                                      jobControllerProvider
                                                          .notifier,
                                                    )
                                                    .acceptJob(job.id);

                                                debugPrint(
                                                  '🔄 Invalidating providers after accept',
                                                );
                                                ref.invalidate(
                                                  watchNearbyJobsStreamProvider(
                                                    lat: lat,
                                                    lng: lng,
                                                  ),
                                                );
                                                ref.invalidate(myJobsProvider);

                                                // Navigate to set price screen
                                                goRouter.push(
                                                  AppRoutes.buildTechnicianSetPricePath(
                                                    job.id,
                                                  ),
                                                );
                                              } on JobAlreadyAcceptedException catch (
                                                e
                                              ) {
                                                if (mounted) {
                                                  KadmatToast.showError(
                                                    context,
                                                    title: 'تم قبول الطلب',
                                                    message: e.message,
                                                  );
                                                }
                                              } on TechnicianLockedException catch (
                                                e
                                              ) {
                                                if (mounted) {
                                                  KadmatToast.showWarning(
                                                    context,
                                                    title: 'طلب قيد التنفيذ',
                                                    message: e.message,
                                                  );
                                                }
                                              } on InvalidStatusException catch (
                                                e
                                              ) {
                                                if (mounted) {
                                                  KadmatToast.showError(
                                                    context,
                                                    title: 'حالة غير صحيحة',
                                                    message: e.message,
                                                  );
                                                }
                                              } on NetworkException catch (e) {
                                                if (mounted) {
                                                  KadmatToast.showError(
                                                    context,
                                                    title: 'خطأ في الاتصال',
                                                    message: e.message,
                                                  );
                                                }
                                              } on JobNotFoundException catch (
                                                e
                                              ) {
                                                if (mounted) {
                                                  KadmatToast.showError(
                                                    context,
                                                    title: 'الطلب غير موجود',
                                                    message: e.message,
                                                  );
                                                }
                                              } catch (e) {
                                                if (mounted) {
                                                  KadmatToast.showError(
                                                    context,
                                                    title: 'فشل قبول الطلب',
                                                    message:
                                                        'حدث خطأ أثناء قبول الطلب. يرجى المحاولة مرة أخرى.',
                                                  );
                                                }
                                              }
                                            },
                                      onReject: () {
                                        // Implement reject logic
                                      },
                                    ).animate().fadeIn().slideX(delay: (100 * index).ms),
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) {
            debugPrint('❌ Nearby jobs error: $error');
            return Center(
              child: Padding(
                padding: EdgeInsets.all(24.w),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wifi_off, size: 64.s, color: Colors.grey),
                    SizedBox(height: 12.h),
                    Text(
                      'تعذر تحميل الطلبات الجديدة',
                      style: TextStyle(
                        fontSize: 16.fz,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      error.toString(),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.fz, color: Colors.grey),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 16.h),
                    ElevatedButton.icon(
                      onPressed: () {
                        ref.invalidate(
                          watchNearbyJobsStreamProvider(lat: lat, lng: lng),
                        );
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
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) {
        debugPrint('❌ Location error: $error');
        return Center(
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_off, size: 64.s, color: Colors.grey),
                SizedBox(height: 12.h),
                Text(
                  'فعّل الموقع لعرض الطلبات القريبة',
                  style: TextStyle(
                    fontSize: 16.fz,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8.h),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.fz, color: Colors.grey),
                ),
                SizedBox(height: 16.h),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(locationStreamProvider),
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
                time: job.createdAt.toString(),
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
        return Center(child: Text('خطأ: $error'));
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

        // ✅ فقط الطلبات قيد التنفيذ (بعد موافقة العميل على السعر)
        // accepted و price_pending يظهران في قسم منفصل
        final inProgressJobs = jobs
            .where((j) => j.status == 'in_progress')
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
                time: job.createdAt.toString(),
                icon: Icons.work_history,
                iconColor: Colors.cyan,
                iconBgColor: Colors.cyan.shade50,
                statusText: _getStatusText(job.status),
                statusColor: _getStatusColor(job.status),
                showActions: false,
                showSetPriceButton: job.status == 'accepted',
                showWaitingPriceApproval: job.status == 'price_pending',
                showCompleteButton: job.status == 'in_progress',
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
        return Center(child: Text('خطأ: $error'));
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
              time: job.createdAt.toString(),
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
      error: (error, stackTrace) => Center(child: Text('خطأ: $error')),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'accepted':
        return 'في انتظار تحديد السعر';
      case 'price_pending':
        return 'في انتظار موافقة العميل';
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
      case 'in_progress':
        return Colors.blue;
      default:
        return Colors.blue;
    }
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
                        debugPrint(
                          '🔵 ACCEPT BUTTON CLICKED - Starting Robust Flow',
                        );
                        final goRouter = ref.read(goRouterProvider);

                        try {
                          debugPrint('🔵 Popping context...');
                          Navigator.pop(context);

                          debugPrint('🔵 Calling acceptJob controller...');
                          final controller = ref.read(
                            jobControllerProvider.notifier,
                          );

                          // Attempt to accept
                          await controller.acceptJob(job.id);

                          debugPrint(
                            '🟢 acceptJob SUCCESS - Proceeding to Navigation',
                          );

                          // Refresh Data
                          ref.invalidate(myJobsProvider);
                          final currentLocation = ref
                              .read(locationStreamProvider)
                              .valueOrNull;
                          if (currentLocation != null) {
                            ref.invalidate(
                              watchNearbyJobsStreamProvider(
                                lat: currentLocation.latitude,
                                lng: currentLocation.longitude,
                              ),
                            );
                          } else {
                            ref.invalidate(watchNearbyJobsStreamProvider);
                          }

                          // Navigate
                          final route = AppRoutes.buildTechnicianSetPricePath(
                            job.id,
                          );
                          debugPrint('🟢 Pushing Route: $route');
                          goRouter.push(route);
                        } catch (e) {
                          debugPrint('⚠️ Error during acceptJob: $e');

                          // IDEMPOTENCY CHECK:
                          // If error is "Already Accepted" or "Locked", check if WE are the owner.
                          // If so, it's a false alarm (or retry), so just navigate!

                          bool shouldNavigate = false;
                          final currentUser = ref
                              .read(authRepositoryProvider)
                              .currentUser;

                          if (currentUser != null) {
                            debugPrint(
                              '🔄 Checking ownership for idempotency...',
                            );
                            // We need to verify if this job is now assigned to us
                            try {
                              final freshJob = await ref
                                  .read(jobRepositoryProvider)
                                  .getJob(job.id);
                              if (freshJob != null &&
                                  freshJob.technicianId == currentUser) {
                                debugPrint(
                                  '✅ IDEMPOTENCY CONFIRMED: User already owns job ${job.id}. Navigating...',
                                );
                                shouldNavigate = true;
                              }
                            } catch (_) {
                              // Ignore verify error
                            }
                          }

                          if (shouldNavigate) {
                            final route = AppRoutes.buildTechnicianSetPricePath(
                              job.id,
                            );
                            debugPrint('🟢 Recovered -> Pushing Route: $route');
                            goRouter.push(route);
                            return; // Exit
                          }

                          // If still not ours, show the real error
                          if (mounted) {
                            String title = 'فشل قبول الطلب';
                            String message = 'حدث خطأ غير متوقع';
                            bool isWarning = false;

                            if (e is JobAlreadyAcceptedException) {
                              title = 'تم قبول الطلب';
                              message = e.message;
                            } else if (e is TechnicianLockedException) {
                              title = 'طلب قيد التنفيذ';
                              message = e.message;
                              isWarning = true;
                            } else if (e is InvalidStatusException) {
                              title = 'حالة غير صحيحة';
                              message = e.message;
                            } else if (e is NetworkException) {
                              title = 'خطأ في الاتصال';
                              message = e.message;
                            } else if (e is JobNotFoundException) {
                              title = 'الطلب غير موجود';
                              message = e.message;
                            }

                            if (isWarning) {
                              KadmatToast.showWarning(
                                context,
                                title: title,
                                message: message,
                              );
                            } else {
                              KadmatToast.showError(
                                context,
                                title: title,
                                message: message,
                              );
                            }
                          }
                        }
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
    bool showActions = false,
    bool showCompleteButton = false,
    bool showSetPriceButton = false,
    bool showWaitingPriceApproval = false,
    bool showRating = false,
    double rating = 0.0,
    bool isLocked = false, // NEW: Lock status
    VoidCallback? onAccept,
    VoidCallback? onReject,
    VoidCallback? onComplete,
    VoidCallback? onSetPrice,
  }) {
    return Card(
      margin: EdgeInsets.only(bottom: 16.h),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: InkWell(
        onTap: () => context.push('/jobs/${job.id}/technician/detail'),
        borderRadius: BorderRadius.circular(16.r),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Icon, Title, Status
              Row(
                children: [
                  Container(
                    width: 48.w,
                    height: 48.h,
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(icon, color: iconColor, size: 28.s),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          serviceName,
                          style: TextStyle(
                            fontSize: 16.fz,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          'عميل: $customerName',
                          style: TextStyle(fontSize: 12.fz, color: Colors.grey),
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
                  Text(
                    location,
                    style: TextStyle(fontSize: 12.fz, color: Colors.grey),
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
