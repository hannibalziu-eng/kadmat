import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/app_theme.dart';
import '../../data/job_repository.dart';
import '../../domain/job.dart';
import '../widgets/job_widgets.dart';

/// Technician Accepted Screen - Shows job accepted confirmation
class TechnicianAcceptedScreen extends ConsumerStatefulWidget {
  final String jobId;

  const TechnicianAcceptedScreen({super.key, required this.jobId});

  @override
  ConsumerState<TechnicianAcceptedScreen> createState() =>
      _TechnicianAcceptedScreenState();
}

class _TechnicianAcceptedScreenState
    extends ConsumerState<TechnicianAcceptedScreen> {
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
        title: const Text('تم قبول الطلب'),
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
                      color: Colors.green.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check, color: Colors.green, size: 60.s),
                  ),

                  SizedBox(height: 24.h),

                  Text(
                    'تم قبول الطلب بنجاح! ✅',
                    style: TextStyle(
                      fontSize: 22.fz,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  SizedBox(height: 8.h),

                  Text(
                    'قم بتحديد السعر للعميل',
                    style: TextStyle(fontSize: 16.fz, color: Colors.white60),
                  ),

                  SizedBox(height: 32.h),

                  // Timeline
                  JobTimeline(currentStatus: _job!.status),

                  SizedBox(height: 24.h),

                  // Customer Card
                  if (_job?.customer != null)
                    ProfileCard(
                      name: _job!.customer?['full_name'],
                      phone: _job!.customer?['phone'],
                      imageUrl: _job!.customer?['profile_image_url'],
                      rating: (_job!.customer?['rating'] as num?)?.toDouble(),
                      label: 'العميل',
                    ),

                  SizedBox(height: 24.h),

                  // Job Details
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: AppTheme.glassDecoration(radius: 16.r),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.home_repair_service,
                              color: AppTheme.primaryColor,
                              size: 24.s,
                            ),
                            SizedBox(width: 12.w),
                            Text(
                              _job?.service?['name'] ?? 'خدمة',
                              style: TextStyle(
                                fontSize: 18.fz,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12.h),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              color: Colors.white54,
                              size: 20.s,
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Text(
                                _job?.addressText ?? '',
                                style: TextStyle(
                                  fontSize: 14.fz,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_job?.description != null &&
                            _job!.description!.isNotEmpty) ...[
                          SizedBox(height: 12.h),
                          Text(
                            _job!.description!,
                            style: TextStyle(
                              fontSize: 14.fz,
                              color: Colors.white60,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  SizedBox(height: 32.h),

                  // Set Price Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => context.go(
                        '/jobs/${widget.jobId}/technician/set-price',
                      ),
                      icon: const Icon(Icons.attach_money),
                      label: Text(
                        'تحديد السعر',
                        style: TextStyle(
                          fontSize: 18.fz,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
}

/// Technician Set Price Screen - Allows technician to set job price
class TechnicianSetPriceScreen extends ConsumerStatefulWidget {
  final String jobId;

  const TechnicianSetPriceScreen({super.key, required this.jobId});

  @override
  ConsumerState<TechnicianSetPriceScreen> createState() =>
      _TechnicianSetPriceScreenState();
}

class _TechnicianSetPriceScreenState
    extends ConsumerState<TechnicianSetPriceScreen> {
  Job? _job;
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isLoading = false;

  static const _quickAmounts = [150.0, 200.0, 250.0, 300.0, 400.0, 500.0];

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
      if (mounted) {
        setState(() => _job = job);
        // Pre-fill with initial price if available
        if (job?.initialPrice != null) {
          _priceController.text = job!.initialPrice!.toStringAsFixed(0);
        }
      }
    } catch (e) {
      // Ignore
    }
  }

  Future<void> _submitPrice() async {
    final price = double.tryParse(_priceController.text);
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال سعر صحيح'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref
          .read(jobRepositoryProvider)
          .setPrice(
            widget.jobId,
            price,
            notes: _notesController.text.isNotEmpty
                ? _notesController.text
                : null,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال السعر للعميل'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/jobs/${widget.jobId}/technician/waiting');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('تحديد السعر'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _job == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(24.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Service Info
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: AppTheme.glassDecoration(radius: 12.r),
                    child: Row(
                      children: [
                        Icon(
                          Icons.home_repair_service,
                          color: AppTheme.primaryColor,
                        ),
                        SizedBox(width: 12.w),
                        Text(
                          _job?.service?['name'] ?? 'خدمة',
                          style: TextStyle(
                            fontSize: 16.fz,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 24.h),

                  // Price Input Label
                  Text(
                    'أدخل السعر (ريال)',
                    style: TextStyle(
                      fontSize: 16.fz,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),

                  SizedBox(height: 12.h),

                  // Price Input
                  Container(
                    decoration: AppTheme.glassDecoration(radius: 16.r),
                    child: TextField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 48.fz,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        hintText: '0',
                        hintStyle: TextStyle(
                          fontSize: 48.fz,
                          color: Colors.white24,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 24.h),
                        suffixText: 'ر.س',
                        suffixStyle: TextStyle(
                          fontSize: 24.fz,
                          color: Colors.white60,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 16.h),

                  // Quick Amount Buttons
                  Wrap(
                    spacing: 8.w,
                    runSpacing: 8.h,
                    children: _quickAmounts.map((amount) {
                      return ActionChip(
                        label: Text('${amount.toInt()} ر.س'),
                        backgroundColor: AppTheme.surfaceDark,
                        labelStyle: const TextStyle(color: Colors.white),
                        onPressed: () {
                          _priceController.text = amount.toStringAsFixed(0);
                        },
                      );
                    }).toList(),
                  ),

                  SizedBox(height: 24.h),

                  // Commission Preview
                  if (_priceController.text.isNotEmpty)
                    Builder(
                      builder: (context) {
                        final price =
                            double.tryParse(_priceController.text) ?? 0;
                        final commission = price * 0.10;
                        final earnings = price - commission;

                        return Container(
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color: Colors.green.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            children: [
                              _buildPreviewRow('سعر الخدمة', price),
                              SizedBox(height: 8.h),
                              _buildPreviewRow(
                                'عمولة المنصة (10%)',
                                -commission,
                                isNegative: true,
                              ),
                              Divider(color: Colors.green.withOpacity(0.3)),
                              _buildPreviewRow(
                                'صافي أرباحك',
                                earnings,
                                isBold: true,
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                  SizedBox(height: 24.h),

                  // Notes Input
                  Text(
                    'ملاحظات (اختياري)',
                    style: TextStyle(fontSize: 14.fz, color: Colors.white60),
                  ),

                  SizedBox(height: 8.h),

                  Container(
                    decoration: AppTheme.glassDecoration(radius: 12.r),
                    child: TextField(
                      controller: _notesController,
                      maxLines: 3,
                      maxLength: 200,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'مثال: يشمل السعر المواد...',
                        hintStyle: TextStyle(color: Colors.white38),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16.w),
                        counterStyle: TextStyle(color: Colors.white38),
                      ),
                    ),
                  ),

                  SizedBox(height: 32.h),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitPrice,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
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
                              'إرسال السعر للعميل',
                              style: TextStyle(
                                fontSize: 18.fz,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPreviewRow(
    String label,
    double amount, {
    bool isNegative = false,
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14.fz,
            color: Colors.white70,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          '${isNegative ? "-" : ""}${amount.abs().toStringAsFixed(0)} ر.س',
          style: TextStyle(
            fontSize: 14.fz,
            color: isNegative ? Colors.red : Colors.green,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

/// Technician Waiting Screen - Shows waiting state while customer reviews price
class TechnicianWaitingScreen extends ConsumerStatefulWidget {
  final String jobId;

  const TechnicianWaitingScreen({super.key, required this.jobId});

  @override
  ConsumerState<TechnicianWaitingScreen> createState() =>
      _TechnicianWaitingScreenState();
}

class _TechnicianWaitingScreenState
    extends ConsumerState<TechnicianWaitingScreen> {
  Timer? _pollTimer;
  Job? _job;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    _fetchJob();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchJob());
  }

  Future<void> _fetchJob() async {
    try {
      final job = await ref
          .read(jobRepositoryProvider)
          .getJobById(widget.jobId);
      if (!mounted) return;

      setState(() => _job = job);

      // Auto-navigate when price confirmed
      if (job != null && job.status == 'in_progress') {
        _pollTimer?.cancel();
        context.go('/jobs/${widget.jobId}/technician/in-progress');
      }

      // Handle cancellation
      if (job != null && job.status == 'cancelled') {
        _pollTimer?.cancel();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إلغاء الطلب من العميل'),
              backgroundColor: Colors.red,
            ),
          );
          context.go('/');
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
        title: const Text('بانتظار موافقة العميل'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _job == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(24.w),
              child: Column(
                children: [
                  // Waiting Animation
                  Container(
                    padding: EdgeInsets.all(32.w),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.hourglass_top,
                      color: Colors.amber,
                      size: 60.s,
                    ),
                  ),

                  SizedBox(height: 24.h),

                  Text(
                    'بانتظار موافقة العميل...',
                    style: TextStyle(
                      fontSize: 20.fz,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  SizedBox(height: 8.h),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'العميل يراجع السعر',
                        style: TextStyle(
                          fontSize: 14.fz,
                          color: Colors.white60,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      _buildAnimatedDots(),
                    ],
                  ),

                  SizedBox(height: 32.h),

                  // Timeline
                  JobTimeline(currentStatus: _job!.status),

                  SizedBox(height: 24.h),

                  // Price Card
                  PriceCard(
                    proposedPrice: _job!.technicianPrice,
                    showBreakdown: true,
                  ),

                  SizedBox(height: 24.h),

                  // Customer Card
                  if (_job?.customer != null)
                    ProfileCard(
                      name: _job!.customer?['full_name'],
                      phone: _job!.customer?['phone'],
                      imageUrl: _job!.customer?['profile_image_url'],
                      rating: (_job!.customer?['rating'] as num?)?.toDouble(),
                      label: 'العميل',
                    ),

                  SizedBox(height: 32.h),

                  // Action Buttons
                  OutlinedButton.icon(
                    onPressed: () => context.go(
                      '/jobs/${widget.jobId}/technician/set-price',
                    ),
                    icon: const Icon(Icons.edit),
                    label: const Text('تعديل السعر'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white54),
                      padding: EdgeInsets.symmetric(
                        vertical: 14.h,
                        horizontal: 24.w,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildAnimatedDots() {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: 3),
      duration: const Duration(seconds: 1),
      builder: (context, value, child) {
        return Text(
          '.' * ((DateTime.now().second % 3) + 1),
          style: TextStyle(fontSize: 14.fz, color: Colors.white60),
        );
      },
    );
  }
}

/// Technician In Progress Screen - Shows job in progress with complete button
class TechnicianInProgressScreen extends ConsumerStatefulWidget {
  final String jobId;

  const TechnicianInProgressScreen({super.key, required this.jobId});

  @override
  ConsumerState<TechnicianInProgressScreen> createState() =>
      _TechnicianInProgressScreenState();
}

class _TechnicianInProgressScreenState
    extends ConsumerState<TechnicianInProgressScreen> {
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

  Future<void> _completeJob() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text(
          'إنهاء الخدمة',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'هل انتهيت من الخدمة وتريد تأكيد الإنهاء؟',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('لا'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('نعم، أنهيت'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await ref.read(jobRepositoryProvider).completeJob(widget.jobId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إنهاء الخدمة بنجاح! 🎉'),
              backgroundColor: Colors.green,
            ),
          );
          context.go('/jobs/${widget.jobId}/technician/completed');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
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
                  // Status Icon
                  Container(
                    padding: EdgeInsets.all(32.w),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.2),
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
                    'أنت الآن في العمل! 🔧',
                    style: TextStyle(
                      fontSize: 22.fz,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  SizedBox(height: 16.h),

                  // Timer
                  if (_job?.priceConfirmedAt != null)
                    ElapsedTimer(startTime: _job!.priceConfirmedAt!),

                  SizedBox(height: 24.h),

                  // Timeline
                  JobTimeline(currentStatus: _job!.status),

                  SizedBox(height: 24.h),

                  // Earnings Preview
                  PriceCard(
                    finalPrice: _job!.finalPrice ?? _job!.technicianPrice,
                    showBreakdown: true,
                  ),

                  SizedBox(height: 24.h),

                  // Customer Card
                  if (_job?.customer != null)
                    ProfileCard(
                      name: _job!.customer?['full_name'],
                      phone: _job!.customer?['phone'],
                      imageUrl: _job!.customer?['profile_image_url'],
                      rating: (_job!.customer?['rating'] as num?)?.toDouble(),
                      label: 'العميل',
                    ),

                  SizedBox(height: 32.h),

                  // Complete Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _completeJob,
                      icon: const Icon(Icons.check_circle),
                      label: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'إنهاء الخدمة',
                              style: TextStyle(
                                fontSize: 18.fz,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
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
}

/// Technician Completed Screen - Shows earnings summary
class TechnicianCompletedScreen extends ConsumerStatefulWidget {
  final String jobId;

  const TechnicianCompletedScreen({super.key, required this.jobId});

  @override
  ConsumerState<TechnicianCompletedScreen> createState() =>
      _TechnicianCompletedScreenState();
}

class _TechnicianCompletedScreenState
    extends ConsumerState<TechnicianCompletedScreen> {
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
    final price = _job?.finalPrice ?? _job?.technicianPrice ?? 0;
    final commission = price * 0.10;
    final earnings = price - commission;

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('تم الإنهاء'),
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
                      gradient: LinearGradient(
                        colors: [
                          Colors.green.withOpacity(0.3),
                          Colors.teal.withOpacity(0.3),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.celebration,
                      color: Colors.amber,
                      size: 60.s,
                    ),
                  ),

                  SizedBox(height: 24.h),

                  Text(
                    'ممتاز! أنهيت الخدمة 🎉',
                    style: TextStyle(
                      fontSize: 24.fz,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  SizedBox(height: 32.h),

                  // Earnings Card (Prominent)
                  Container(
                    padding: EdgeInsets.all(24.w),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.green.withOpacity(0.2),
                          Colors.green.withOpacity(0.1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'أرباحك من هذه الخدمة',
                          style: TextStyle(
                            fontSize: 14.fz,
                            color: Colors.white60,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          '${earnings.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 56.fz,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        Text(
                          'ريال سعودي',
                          style: TextStyle(
                            fontSize: 18.fz,
                            color: Colors.green,
                          ),
                        ),
                        SizedBox(height: 16.h),
                        Divider(color: Colors.green.withOpacity(0.3)),
                        SizedBox(height: 12.h),
                        _buildRow('سعر الخدمة', price),
                        SizedBox(height: 8.h),
                        _buildRow(
                          'عمولة المنصة (10%)',
                          commission,
                          isNegative: true,
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 24.h),

                  // Customer Card
                  if (_job?.customer != null)
                    ProfileCard(
                      name: _job!.customer?['full_name'],
                      phone: _job!.customer?['phone'],
                      imageUrl: _job!.customer?['profile_image_url'],
                      rating: (_job!.customer?['rating'] as num?)?.toDouble(),
                      label: 'العميل',
                      showContactButtons: false,
                    ),

                  SizedBox(height: 32.h),

                  // Action Buttons
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => context.go('/technician/jobs'),
                      icon: const Icon(Icons.work),
                      label: const Text('عرض المزيد من الطلبات'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 12.h),

                  OutlinedButton.icon(
                    onPressed: () => context.go('/'),
                    icon: const Icon(Icons.home),
                    label: const Text('العودة للرئيسية'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white54),
                      padding: EdgeInsets.symmetric(
                        vertical: 14.h,
                        horizontal: 24.w,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildRow(String label, double amount, {bool isNegative = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14.fz, color: Colors.white70),
        ),
        Text(
          '${isNegative ? "-" : ""}${amount.toStringAsFixed(0)} ر.س',
          style: TextStyle(
            fontSize: 14.fz,
            color: isNegative ? Colors.red : Colors.white,
          ),
        ),
      ],
    );
  }
}
