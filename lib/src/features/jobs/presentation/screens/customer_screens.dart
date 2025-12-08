import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/app_theme.dart';
import '../../data/job_repository.dart';
import '../../domain/job.dart';
import '../widgets/job_widgets.dart';

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
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  Timer? _pollTimer;
  Job? _job;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _startPolling();
  }

  void _startPolling() {
    _fetchJob();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _fetchJob());
  }

  Future<void> _fetchJob() async {
    try {
      final job = await ref
          .read(jobRepositoryProvider)
          .getJobById(widget.jobId);
      if (!mounted) return;

      setState(() {
        _job = job;
        _isLoading = false;
      });

      // Auto-navigate when technician accepts
      if (job != null && job.status == 'accepted') {
        _pollTimer?.cancel();
        context.go('/jobs/${widget.jobId}/customer/technician-found');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('جاري البحث'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Search Icon
              AnimatedBuilder(
                animation: Listenable.merge([
                  _pulseController,
                  _rotateController,
                ]),
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.0 + (_pulseController.value * 0.2),
                    child: Transform.rotate(
                      angle: _rotateController.value * 2 * 3.14159,
                      child: Container(
                        width: 120.w,
                        height: 120.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppTheme.primaryColor.withOpacity(0.3),
                              AppTheme.primaryColor.withOpacity(0.1),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Icon(
                          Icons.search,
                          size: 60.s,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  );
                },
              ),

              SizedBox(height: 40.h),

              Text(
                'جاري البحث عن فني...',
                style: TextStyle(
                  fontSize: 24.fz,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),

              SizedBox(height: 12.h),

              Text(
                'سيتم إعلامك عند قبول فني للطلب',
                style: TextStyle(fontSize: 14.fz, color: Colors.white60),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 32.h),

              // Job Details Card
              if (_job != null) _buildJobDetails(),

              SizedBox(height: 40.h),

              // Cancel Button
              TextButton.icon(
                onPressed: _cancelJob,
                icon: const Icon(Icons.close, color: Colors.red),
                label: Text(
                  'إلغاء الطلب',
                  style: TextStyle(color: Colors.red, fontSize: 16.fz),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJobDetails() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: AppTheme.glassDecoration(radius: 16.r),
      child: Column(
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
              Icon(Icons.location_on, color: Colors.white54, size: 20.s),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  _job?.addressText ?? '',
                  style: TextStyle(fontSize: 14.fz, color: Colors.white70),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _cancelJob() async {
    final confirm = await showDialog<bool>(
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

    if (confirm == true) {
      try {
        await ref.read(jobRepositoryProvider).cancelJob(widget.jobId);
        if (mounted) context.go('/');
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e'), backgroundColor: Colors.red),
          );
        }
      }
    }
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
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchJob());
  }

  Future<void> _fetchJob() async {
    try {
      final job = await ref
          .read(jobRepositoryProvider)
          .getJobById(widget.jobId);
      if (!mounted) return;

      setState(() => _job = job);

      // Auto-navigate when price is set
      if (job != null && job.status == 'price_pending') {
        _pollTimer?.cancel();
        context.go('/jobs/${widget.jobId}/customer/price-offer');
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
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('تم العثور على فني'),
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
                    'تم قبول طلبك! ✨',
                    style: TextStyle(
                      fontSize: 24.fz,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  SizedBox(height: 8.h),

                  Text(
                    'الفني يقوم بتحديد السعر...',
                    style: TextStyle(fontSize: 16.fz, color: Colors.white60),
                  ),

                  SizedBox(height: 32.h),

                  // Timeline
                  JobTimeline(currentStatus: _job!.status),

                  SizedBox(height: 24.h),

                  // Technician Card
                  if (_job?.technician != null)
                    ProfileCard(
                      name: _job!.technician?['full_name'],
                      phone: _job!.technician?['phone'],
                      imageUrl: _job!.technician?['profile_image_url'],
                      rating: (_job!.technician?['rating'] as num?)?.toDouble(),
                      label: 'الفني',
                    ),

                  SizedBox(height: 24.h),

                  // Job Status Badge
                  JobStatusBadge(status: _job!.status),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم قبول السعر! الفني في الطريق.'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/jobs/${widget.jobId}/customer/in-progress');
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

  Future<void> _rejectPrice() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('رفض السعر', style: TextStyle(color: Colors.white)),
        content: const Text(
          'هل تريد إلغاء الطلب والبحث عن فني آخر؟',
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
            child: const Text('نعم، ارفض'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref
          .read(jobRepositoryProvider)
          .cancelJob(widget.jobId, reason: 'رفض السعر');
      if (mounted) context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('عرض السعر'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _job == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(24.w),
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long,
                    color: AppTheme.primaryColor,
                    size: 60.s,
                  ),

                  SizedBox(height: 24.h),

                  Text(
                    'عرض سعر من الفني',
                    style: TextStyle(
                      fontSize: 22.fz,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  SizedBox(height: 32.h),

                  // Price Card
                  PriceCard(
                    initialPrice: _job!.initialPrice,
                    proposedPrice: _job!.technicianPrice,
                    showBreakdown: false,
                  ),

                  SizedBox(height: 16.h),

                  // Price comparison
                  if (_job!.initialPrice != null &&
                      _job!.technicianPrice != null)
                    Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: _job!.technicianPrice! <= _job!.initialPrice!
                            ? Colors.green.withOpacity(0.2)
                            : Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _job!.technicianPrice! <= _job!.initialPrice!
                                ? Icons.thumb_up
                                : Icons.info,
                            color: _job!.technicianPrice! <= _job!.initialPrice!
                                ? Colors.green
                                : Colors.orange,
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            _job!.technicianPrice! <= _job!.initialPrice!
                                ? 'السعر أقل أو يساوي تقديرك المبدئي!'
                                : 'السعر أعلى من تقديرك المبدئي',
                            style: TextStyle(
                              color:
                                  _job!.technicianPrice! <= _job!.initialPrice!
                                  ? Colors.green
                                  : Colors.orange,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                  SizedBox(height: 24.h),

                  // Technician Card
                  if (_job?.technician != null)
                    ProfileCard(
                      name: _job!.technician?['full_name'],
                      phone: _job!.technician?['phone'],
                      imageUrl: _job!.technician?['profile_image_url'],
                      rating: (_job!.technician?['rating'] as num?)?.toDouble(),
                      label: 'الفني',
                    ),

                  SizedBox(height: 32.h),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : _rejectPrice,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: EdgeInsets.symmetric(vertical: 16.h),
                          ),
                          child: const Text('رفض'),
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
                              : const Text('قبول السعر'),
                        ),
                      ),
                    ],
                  ),
                ],
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
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchJob());
  }

  Future<void> _fetchJob() async {
    try {
      final job = await ref
          .read(jobRepositoryProvider)
          .getJobById(widget.jobId);
      if (!mounted) return;

      setState(() => _job = job);

      // Auto-navigate when completed
      if (job != null && job.status == 'completed') {
        _pollTimer?.cancel();
        context.go('/jobs/${widget.jobId}/customer/rate');
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
                    'الفني يعمل على طلبك! 🔧',
                    style: TextStyle(
                      fontSize: 22.fz,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  if (_job?.priceConfirmedAt != null)
                    ElapsedTimer(startTime: _job!.priceConfirmedAt!),
                  SizedBox(height: 24.h),
                  JobTimeline(currentStatus: _job!.status),
                  SizedBox(height: 24.h),
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.attach_money, color: Colors.green),
                        SizedBox(width: 8.w),
                        Text(
                          'السعر المتفق عليه: ${_job!.finalPrice ?? _job!.technicianPrice ?? 0} ريال',
                          style: TextStyle(
                            fontSize: 16.fz,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24.h),
                  if (_job?.technician != null)
                    ProfileCard(
                      name: _job!.technician?['full_name'],
                      phone: _job!.technician?['phone'],
                      imageUrl: _job!.technician?['profile_image_url'],
                      rating: (_job!.technician?['rating'] as num?)?.toDouble(),
                      label: 'الفني',
                    ),
                ],
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
  Job? _job;
  int _rating = 0;
  final _reviewController = TextEditingController();
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

  Future<void> _submitRating() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار تقييم'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref
          .read(jobRepositoryProvider)
          .rateJob(
            widget.jobId,
            _rating,
            review: _reviewController.text.isNotEmpty
                ? _reviewController.text
                : null,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('شكراً على تقييمك! ⭐'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/jobs/${widget.jobId}/customer/completed');
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
    _reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('تقييم الخدمة'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24.w),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.done_all, color: Colors.teal, size: 60.s),
            ),
            SizedBox(height: 24.h),
            Text(
              'تم إنهاء الخدمة بنجاح! 🎉',
              style: TextStyle(
                fontSize: 22.fz,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'كيف كانت تجربتك مع الفني؟',
              style: TextStyle(fontSize: 16.fz, color: Colors.white60),
            ),
            SizedBox(height: 32.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return GestureDetector(
                  onTap: () => setState(() => _rating = index + 1),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.w),
                    child: Icon(
                      index < _rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 48.s,
                    ),
                  ),
                );
              }),
            ),
            SizedBox(height: 32.h),
            Container(
              decoration: AppTheme.glassDecoration(radius: 12.r),
              child: TextField(
                controller: _reviewController,
                maxLines: 4,
                maxLength: 250,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'اكتب تعليقك هنا (اختياري)...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16.w),
                  counterStyle: const TextStyle(color: Colors.white38),
                ),
              ),
            ),
            SizedBox(height: 32.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitRating,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
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
                        'إرسال التقييم',
                        style: TextStyle(
                          fontSize: 18.fz,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            SizedBox(height: 16.h),
            TextButton(
              onPressed: () => context.go('/'),
              child: Text(
                'تخطي',
                style: TextStyle(color: Colors.white60, fontSize: 16.fz),
              ),
            ),
          ],
        ),
      ),
    );
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
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('ملخص الطلب'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _job == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(24.w),
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(24.w),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryColor.withOpacity(0.3),
                          Colors.teal.withOpacity(0.3),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.verified,
                      color: Colors.white,
                      size: 60.s,
                    ),
                  ),
                  SizedBox(height: 24.h),
                  Text(
                    'تم الإنهاء بنجاح! 🎉',
                    style: TextStyle(
                      fontSize: 24.fz,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 32.h),
                  Container(
                    padding: EdgeInsets.all(20.w),
                    decoration: AppTheme.glassDecoration(radius: 16.r),
                    child: Column(
                      children: [
                        _buildRow('الخدمة', _job!.service?['name'] ?? '-'),
                        Divider(color: Colors.white24, height: 24.h),
                        _buildRow(
                          'السعر النهائي',
                          '${_job!.finalPrice ?? _job!.technicianPrice ?? 0} ريال',
                          valueColor: Colors.green,
                        ),
                        if (_job!.customerRating != null) ...[
                          Divider(color: Colors.white24, height: 24.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'تقييمك',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14.fz,
                                ),
                              ),
                              Row(
                                children: List.generate(
                                  5,
                                  (i) => Icon(
                                    i < (_job!.customerRating ?? 0)
                                        ? Icons.star
                                        : Icons.star_border,
                                    color: Colors.amber,
                                    size: 20.s,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: 24.h),
                  if (_job?.technician != null)
                    ProfileCard(
                      name: _job!.technician?['full_name'],
                      phone: _job!.technician?['phone'],
                      imageUrl: _job!.technician?['profile_image_url'],
                      rating: (_job!.technician?['rating'] as num?)?.toDouble(),
                      label: 'الفني',
                      showContactButtons: false,
                    ),
                  SizedBox(height: 32.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => context.go('/'),
                      icon: const Icon(Icons.home),
                      label: const Text('العودة للرئيسية'),
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

  Widget _buildRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white70, fontSize: 14.fz),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 16.fz,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
