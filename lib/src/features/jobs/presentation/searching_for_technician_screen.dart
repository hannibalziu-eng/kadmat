import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import '../../../core/app_theme.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/navigation/job_flow_redirects.dart';
import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/utils/error_handler.dart';
import '../data/job_repository.dart';
import '../domain/job_status.dart';
import '../../../common_widgets/badge_widget.dart';

class SearchingForTechnicianScreen extends ConsumerStatefulWidget {
  final String jobId;
  final String serviceName;
  final double? lat;
  final double? lng;

  const SearchingForTechnicianScreen({
    super.key,
    required this.jobId,
    required this.serviceName,
    this.lat,
    this.lng,
  });

  @override
  ConsumerState<SearchingForTechnicianScreen> createState() =>
      _SearchingForTechnicianScreenState();
}

class _SearchingForTechnicianScreenState
    extends ConsumerState<SearchingForTechnicianScreen>
    with TickerProviderStateMixin {
  static const String _statusUpdatedRedirectMessage =
      'تم تحديث حالة الطلب، يتم نقلك للحالة الحالية';

  late AnimationController _pulseController;
  late AnimationController _rippleController;

  int _searchRadius = 2000; // meters
  final int _currentTier = 1;
  final int _estimatedTime = 3; // minutes
  bool _isCancelling = false;
  bool _handledTerminalState = false;
  bool _technicianFound = false;
  String? _acceptingOfferId;
  Map<String, dynamic>? _technician;
  final bool _showingNoTechMessage =
      false; // Show "no tech yet" without blocking
  StreamSubscription? _jobSubscription;
  // Default location (Riyadh) - will be replaced by actual location
  late double _lat;
  late double _lng;

  @override
  void initState() {
    super.initState();

    _lat = widget.lat ?? 24.7136;
    _lng = widget.lng ?? 46.6753;

    // Pulse animation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    // Ripple animation
    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat();

    // Start listening to job changes
    _startListening();

    // Backup: Poll every 10 seconds to ensure we don't miss updates
    // (Real-time subscription is primary, this is fallback)
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!mounted || _technicianFound) {
        timer.cancel();
        return;
      }
      _checkJobStatus();
    });
  }

  Timer? _pollTimer; // Store timer reference for cleanup

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  bool _isValidUuid(String value) => _uuidRegex.hasMatch(value.trim());

  Future<void> _checkJobStatus() async {
    try {
      final jobRepo = ref.read(jobRepositoryProvider);
      final job = await jobRepo.getJob(widget.jobId);

      if (job == null) {
        debugPrint('⚠️ Polling: Job not found (null). Stopping polling.');
        // Job might be cancelled or deleted. Stop polling to avoid loops.
        // In a real app, you might want to show a dialog or navigate back.
        return;
      }

      debugPrint(
        '🔍 Polling Result: Status=${job.status}, TechID=${job.technicianId}, Navigating=$_navigating',
      );

      final normalizedStatus = JobStatus.normalize(job.status);
      if (normalizedStatus == JobStatus.cancelled && !_handledTerminalState) {
        _handledTerminalState = true;
        _stopSearchListeners();
        if (mounted) {
          context.go(AppRoutes.home);
        }
        return;
      }

      final route = customerRouteForJobStatus(
        status: job.status,
        jobId: widget.jobId,
      );
      if (route != null && !_navigating) {
        debugPrint('✅ Polling: Redirecting customer to $route');
        _handleFoundTechnician(job);
      }
    } catch (e) {
      debugPrint('⚠️ Polling error: $e');
    }
  }

  void _handleFoundTechnician(dynamic job) {
    if (_navigating) return;

    _navigating = true;
    setState(() {
      _technicianFound = true;
      _technician = job.technician;
    });

    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      final route = customerRouteForJobStatus(
        status: (job.status ?? '').toString(),
        jobId: widget.jobId,
      );
      context.go(route ?? AppRoutes.buildCustomerInProgressPath(widget.jobId));
    });
  }

  bool _navigating = false; // Guard to prevent double navigation

  StreamSubscription? _offersSubscription;
  List<Map<String, dynamic>> _offers = [];

  @override
  void dispose() {
    _pulseController.dispose();
    _rippleController.dispose();
    _jobSubscription?.cancel();
    _offersSubscription?.cancel();
    _pollTimer?.cancel(); // Cancel polling timer
    super.dispose();
  }

  void _stopSearchListeners() {
    _jobSubscription?.cancel();
    _jobSubscription = null;
    _offersSubscription?.cancel();
    _offersSubscription = null;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _startListening() {
    final jobRepo = ref.read(jobRepositoryProvider);

    // Watch Job Status
    _jobSubscription = jobRepo.watchJob(widget.jobId).listen((job) {
      debugPrint('🕵️‍♀️ Job Update -> Status: ${job.status}');
      final normalizedStatus = JobStatus.normalize(job.status);

      if (normalizedStatus == JobStatus.cancelled && !_handledTerminalState) {
        _handledTerminalState = true;
        _stopSearchListeners();
        if (mounted) {
          context.go(AppRoutes.home);
        }
        return;
      }

      if (job.searchRadius != null && job.searchRadius != _searchRadius) {
        setState(() {
          _searchRadius = job.searchRadius!;
          // Update tiers...
        });
      }

      final route = customerRouteForJobStatus(
        status: job.status,
        jobId: widget.jobId,
      );
      if (route != null && !_navigating) {
        _handleFoundTechnician(job);
      }
    }, onError: (e) => debugPrint('🔴 Job watch error: $e'));

    // Watch Offers
    _offersSubscription = jobRepo.watchJobOffers(widget.jobId).listen((offers) {
      debugPrint('💰 Offers Update: ${offers.length} offers received');
      if (mounted) {
        setState(() {
          _offers = offers;
        });
      }
    }, onError: (e) => debugPrint('🔴 Offers watch error: $e'));
  }

  Future<void> _acceptOffer(String offerId) async {
    final normalizedOfferId = offerId.trim();
    if (_acceptingOfferId != null) return;

    if (!_isValidUuid(normalizedOfferId)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('معرّف العرض غير صالح، حدّث الصفحة وحاول مجددًا'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _acceptingOfferId = normalizedOfferId);
    try {
      await ref
          .read(jobRepositoryProvider)
          .acceptOffer(widget.jobId, normalizedOfferId);
      // Logic handled by job stream listener (status -> accepted)
    } on InvalidStatusException catch (e) {
      if (!mounted) return;
      final hintedRoute = customerRouteForJobStatus(
        status: e.currentStatus ?? '',
        jobId: widget.jobId,
      );
      if (hintedRoute != null) {
        await _showStatusUpdatedAndGo(hintedRoute);
        return;
      }

      try {
        final latest = await ref
            .read(jobRepositoryProvider)
            .getJobById(widget.jobId);
        if (!mounted || latest == null) return;
        final route = customerRouteForJobStatus(
          status: latest.status,
          jobId: widget.jobId,
        );
        if (route != null) {
          await _showStatusUpdatedAndGo(route);
          return;
        }
        if (JobStatus.normalize(latest.status) == JobStatus.cancelled) {
          context.go(AppRoutes.home);
          return;
        }
      } catch (_) {
        // Fall through to warning message below.
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.orange),
      );
    } catch (e) {
      if (!mounted) return;
      try {
        final latest = await ref
            .read(jobRepositoryProvider)
            .getJobById(widget.jobId);
        if (!mounted || latest == null) return;
        final route = customerRouteForJobStatus(
          status: latest.status,
          jobId: widget.jobId,
        );
        if (route != null) {
          await _showStatusUpdatedAndGo(route);
          return;
        }
        if (JobStatus.normalize(latest.status) == JobStatus.cancelled) {
          context.go(AppRoutes.home);
          return;
        }
      } catch (_) {}
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر إكمال قبول العرض الآن. حاول مجددًا.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _acceptingOfferId = null);
      }
    }
  }

  Future<void> _showStatusUpdatedAndGo(String route) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(_statusUpdatedRedirectMessage),
        backgroundColor: Colors.blueGrey,
        duration: Duration(milliseconds: 1200),
      ),
    );
    await Future.delayed(const Duration(milliseconds: 280));
    if (!mounted) return;
    context.go(route);
  }

  Future<void> _cancelJobAndExit() async {
    if (_isCancelling) return;

    setState(() => _isCancelling = true);
    _navigating = true;

    try {
      await ref.read(jobRepositoryProvider).cancelJob(widget.jobId);
      _stopSearchListeners();

      if (!mounted) return;
      context.go(AppRoutes.home);
    } on InvalidStatusException catch (e) {
      final normalized = JobStatus.normalize(e.currentStatus ?? '');
      final isAlreadyTerminal =
          normalized == JobStatus.cancelled ||
          normalized == JobStatus.completed ||
          normalized == JobStatus.rated;

      if (isAlreadyTerminal) {
        _stopSearchListeners();
        if (mounted) context.go(AppRoutes.home);
        return;
      }

      if (mounted) {
        ErrorHandler.handle(context, e);
      }
      _navigating = false;
    } on JobNotFoundException {
      _stopSearchListeners();
      if (mounted) context.go(AppRoutes.home);
    } catch (e) {
      if (mounted) {
        ErrorHandler.handle(context, e);
      }
      _navigating = false;
    } finally {
      if (mounted) {
        setState(() => _isCancelling = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        _showCancelDialog();
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        body: SafeArea(
          child: _technicianFound
              ? _buildFoundScreen()
              : _buildSearchingScreen(),
        ),
      ),
    );
  }

  Widget _buildSearchingScreen() {
    return Column(
      children: [
        // Header
        Padding(
          padding: EdgeInsets.all(16.w),
          child: Row(
            children: [
              IconButton(
                onPressed: () => _showCancelDialog(),
                icon: Icon(Icons.close, color: Colors.white70, size: 24.s),
              ),
              Expanded(
                child: Text(
                  widget.serviceName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18.fz,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(width: 48.w),
            ],
          ),
        ).animate().fadeIn().slideY(begin: -0.3),

        // Map with animated search radius
        Expanded(
          child: Stack(
            children: [
              // Flutter Map
              ClipRRect(
                borderRadius: BorderRadius.circular(24.r),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(_lat, _lng),
                      initialZoom: _getZoomForRadius(),
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.none, // Disable interaction
                      ),
                    ),
                    children: [
                      // Dark tile layer
                      TileLayer(
                        urlTemplate:
                            'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                        subdomains: const ['a', 'b', 'c', 'd'],
                        retinaMode: true,
                        userAgentPackageName: 'com.kadmat.app',
                      ),
                      // Animated search radius circle
                      CircleLayer(
                        circles: [
                          // Outer pulsing circle
                          CircleMarker(
                            point: LatLng(_lat, _lng),
                            radius: _searchRadius.toDouble(),
                            useRadiusInMeter: true,
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderColor: AppTheme.primaryColor.withValues(
                              alpha: 0.5,
                            ),
                            borderStrokeWidth: 2,
                          ),
                          // Inner solid circle
                          CircleMarker(
                            point: LatLng(_lat, _lng),
                            radius: 50,
                            useRadiusInMeter: true,
                            color: AppTheme.primaryColor.withValues(alpha: 0.3),
                            borderColor: AppTheme.primaryColor,
                            borderStrokeWidth: 3,
                          ),
                        ],
                      ),
                      // Center marker
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(_lat, _lng),
                            width: 60.w,
                            height: 60.h,
                            child: _buildPulsingMarker(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Tier indicator
              PositionedDirectional(
                top: 16.h,
                end: 32.w,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(color: AppTheme.primaryColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.radar,
                        color: AppTheme.primaryColor,
                        size: 16.s,
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        'المرحلة $_currentTier من 3',
                        style: TextStyle(
                          fontSize: 12.fz,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 500.ms),
              ),
            ],
          ),
        ),

        // Status Card
        Container(
          margin: EdgeInsets.all(16.w),
          padding: EdgeInsets.all(20.w),
          decoration: AppTheme.glassDecoration(radius: 24.r),
          child: Column(
            children: [
              // Status text with shimmer
              Text(
                    _showingNoTechMessage
                        ? 'لم يتم العثور على فني بعد...\nما زلنا نبحث!'
                        : 'جاري البحث عن فني قريب...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20.fz,
                      fontWeight: FontWeight.bold,
                      color: _showingNoTechMessage
                          ? Colors.orange
                          : Colors.white,
                    ),
                  )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .shimmer(
                    duration: 2.seconds,
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  ),

              SizedBox(height: 16.h),

              // Info Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildInfoItem(
                    icon: Icons.radar,
                    label: 'نطاق البحث',
                    value: '${(_searchRadius / 1000).toStringAsFixed(0)} كم',
                  ),
                  Container(width: 1.w, height: 40.h, color: Colors.white24),
                  _buildInfoItem(
                    icon: Icons.access_time,
                    label: 'الوقت المتوقع',
                    value: '$_estimatedTime دقائق',
                  ),
                ],
              ),

              SizedBox(height: 16.h),

              // Progress with tiers
              Row(
                children: List.generate(3, (index) {
                  final isActive = index < _currentTier;
                  final isCurrent = index == _currentTier - 1;
                  return Expanded(
                    child: Container(
                      height: 6.h,
                      margin: EdgeInsets.symmetric(horizontal: 4.w),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppTheme.primaryColor
                            : Colors.white12,
                        borderRadius: BorderRadius.circular(3.r),
                        boxShadow: isCurrent
                            ? [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withValues(
                                    alpha: 0.5,
                                  ),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  );
                }),
              ),

              SizedBox(height: 12.h),

              // Cancel button
              TextButton.icon(
                onPressed: () => _showCancelDialog(),
                icon: Icon(Icons.cancel_outlined, size: 18.s),
                label: const Text('إلغاء الطلب'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red.shade300,
                ),
              ),
            ],
          ),
        ).animate().fadeIn().slideY(begin: 0.3),
        _buildOffersList(),
      ],
    );
  }

  Widget _buildPulsingMarker() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = 1.0 + (_pulseController.value * 0.2);
        return Transform.scale(
          scale: scale,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryColor.withValues(alpha: 0.7),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.5),
                  blurRadius: 20.r,
                  spreadRadius: 5.r,
                ),
              ],
            ),
            child: Icon(Icons.location_on, color: Colors.white, size: 30.s),
          ),
        );
      },
    );
  }

  double _getZoomForRadius() {
    if (_searchRadius <= 2000) return 14.5;
    if (_searchRadius <= 5000) return 13.0;
    return 11.5;
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 24.s),
        SizedBox(height: 8.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 18.fz,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          label,
          style: TextStyle(fontSize: 12.fz, color: Colors.white60),
        ),
      ],
    );
  }

  Widget _buildFoundScreen() {
    final techName = _technician?['full_name'] ?? 'الفني';
    final techPhone = _technician?['phone'] ?? '';
    final techRating = (_technician?['rating'] ?? 5.0).toDouble();
    final techPhoto = _technician?['avatar_url'];

    return SingleChildScrollView(
      padding: EdgeInsets.all(24.w),
      child: Column(
        children: [
          SizedBox(height: 40.h),

          // Success Icon
          Container(
            width: 80.w,
            height: 80.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.green,
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withValues(alpha: 0.4),
                  blurRadius: 20.r,
                  spreadRadius: 5.r,
                ),
              ],
            ),
            child: Icon(Icons.check, color: Colors.white, size: 40.s),
          ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),

          SizedBox(height: 24.h),

          Text(
            '🎉 تم العثور على فني!',
            style: TextStyle(
              fontSize: 24.fz,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ).animate().fadeIn(delay: 200.ms),

          SizedBox(height: 32.h),

          // Technician Info Card
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                // Technician Photo & Name
                Row(
                  children: [
                    CircleAvatar(
                      radius: 35.r,
                      backgroundColor: AppTheme.primaryColor,
                      backgroundImage: techPhoto != null
                          ? NetworkImage(techPhoto)
                          : null,
                      child: techPhoto == null
                          ? Icon(Icons.person, size: 35.s, color: Colors.white)
                          : null,
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            techName,
                            style: TextStyle(
                              fontSize: 20.fz,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Row(
                            children: [
                              Icon(Icons.star, color: Colors.amber, size: 18.s),
                              SizedBox(width: 4.w),
                              Text(
                                techRating.toStringAsFixed(1),
                                style: TextStyle(
                                  fontSize: 16.fz,
                                  color: Colors.white70,
                                ),
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                '(${_technician?['reviews_count'] ?? 0} تقييم)',
                                style: TextStyle(
                                  fontSize: 12.fz,
                                  color: Colors.white38,
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8.w,
                                  vertical: 2.h,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                child: Text(
                                  'موثق',
                                  style: TextStyle(
                                    fontSize: 12.fz,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Badges Section
                          if (_technician != null &&
                              _technician!['badges'] != null &&
                              (_technician!['badges'] as List).isNotEmpty) ...[
                            SizedBox(height: 8.h),
                            Wrap(
                              spacing: 8.w,
                              runSpacing: 4.h,
                              children: (_technician!['badges'] as List).map((
                                badge,
                              ) {
                                return BadgeWidget(
                                  label: badge['label'] ?? '',
                                  iconName: badge['icon_name'] ?? '',
                                  badgeType: badge['badge_type'] ?? '',
                                  isCompact: true,
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 20.h),
                Divider(color: Colors.white24),
                SizedBox(height: 20.h),

                // Action Buttons
                Row(
                  children: [
                    // Call Button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: techPhone.isNotEmpty
                            ? () => _callTechnician(techPhone)
                            : null,
                        icon: Icon(Icons.phone, size: 20.s),
                        label: Text('اتصال'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    // Chat Button (placeholder)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: Icon(Icons.chat_bubble_outline, size: 20.s),
                        label: Text('محادثة'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          side: BorderSide(color: AppTheme.primaryColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),

          SizedBox(height: 24.h),

          // Wait message
          Text(
            'سيتم توجيهك لتتبع الطلب خلال ثوانٍ...',
            style: TextStyle(fontSize: 14.fz, color: Colors.white60),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 600.ms),

          SizedBox(height: 16.h),

          // Skip button
          TextButton(
            onPressed: () =>
                context.go(AppRoutes.buildCustomerSearchingPath(widget.jobId)),
            child: Text(
              'الانتقال الآن ←',
              style: TextStyle(fontSize: 16.fz, color: AppTheme.primaryColor),
            ),
          ).animate().fadeIn(delay: 800.ms),
        ],
      ),
    );
  }

  void _callTechnician(String phone) {
    // In a real app, use url_launcher to make a phone call
    debugPrint('Calling: $phone');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('جاري الاتصال بـ $phone'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: Text(
          'إلغاء الطلب؟',
          style: TextStyle(
            fontSize: 18.fz,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        content: Text(
          'هل أنت متأكد من إلغاء طلب الخدمة؟',
          style: TextStyle(fontSize: 14.fz, color: Colors.white70),
          textAlign: TextAlign.center,
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('لا، استمر'),
                ),
              ),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isCancelling
                      ? null
                      : () async {
                          Navigator.pop(dialogContext);
                          await _cancelJobAndExit();
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: Text(_isCancelling ? 'جاري الإلغاء...' : 'نعم، إلغاء'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOffersList() {
    if (_offers.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 280.h,
      width: double.infinity, // Ensure full width
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30.r),
          topRight: Radius.circular(30.r),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 20,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              children: [
                Text(
                  'عروض الفنيين (${_offers.length})',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.fz,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_offers.length > 1)
                  Text(
                    'اسحب للمزيد ←',
                    style: TextStyle(color: Colors.white54, fontSize: 12.fz),
                  ),
              ],
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: PageController(viewportFraction: 0.9),
              itemCount: _offers.length,
              itemBuilder: (context, index) {
                return _buildOfferCard(_offers[index]);
              },
            ),
          ),
          SizedBox(height: 16.h),
        ],
      ),
    ).animate().slideY(begin: 1.0, duration: 400.ms, curve: Curves.easeOutBack);
  }

  Widget _buildOfferCard(Map<String, dynamic> offer) {
    final tech = offer['technician'] ?? {};
    final price = offer['price'];
    final offerId = (offer['id'] ?? '').toString().trim();
    final isOfferValid = _isValidUuid(offerId);
    final isAcceptingThisOffer = _acceptingOfferId == offerId;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 6.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30.r,
                backgroundColor: Colors.grey[800],
                backgroundImage: tech['profile_image_url'] != null
                    ? NetworkImage(tech['profile_image_url'])
                    : null,
                child: tech['profile_image_url'] == null
                    ? const Icon(Icons.person, color: Colors.white)
                    : null,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tech['full_name'] ?? 'فني',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.fz,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(Icons.star, color: Colors.amber, size: 14.s),
                        Text(
                          ' ${tech['rating'] ?? 5.0}',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: AppTheme.primaryColor),
                ),
                child: Text(
                  '$price ﷼',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 20.fz,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (!isOfferValid || _acceptingOfferId != null)
                  ? null
                  : () => _acceptOffer(offerId),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: isAcceptingThisOffer
                  ? SizedBox(
                      width: 18.s,
                      height: 18.s,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      isOfferValid ? 'قبول العرض' : 'عرض غير صالح',
                      style: TextStyle(
                        fontSize: 16.fz,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
