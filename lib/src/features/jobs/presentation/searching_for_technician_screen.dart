import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import '../../../core/app_theme.dart';
import '../data/job_repository.dart';
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
  late AnimationController _pulseController;
  late AnimationController _rippleController;

  int _searchRadius = 2000; // meters
  int _currentTier = 1;
  int _estimatedTime = 3; // minutes
  bool _technicianFound = false;
  Map<String, dynamic>? _technician;
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

    // Backup: Poll every 3 seconds to ensure we don't miss updates
    Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted || _technicianFound) {
        timer.cancel();
        return;
      }
      _checkJobStatus();
    });
  }

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

      if (job.status == 'accepted' &&
          job.technicianId != null &&
          !_navigating) {
        debugPrint('✅ Polling: Job accepted! TechID: ${job.technicianId}');
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
      if (mounted) {
        context.go('/active-job/${widget.jobId}');
      }
    });
  }

  bool _navigating = false; // Guard to prevent double navigation

  void _startListening() {
    final jobRepo = ref.read(jobRepositoryProvider);
    _jobSubscription = jobRepo
        .watchJob(widget.jobId)
        .listen(
          (job) {
            debugPrint(
              '🕵️‍♀️ SearchingScreen: Job Update -> Status: ${job.status}, TechID: ${job.technicianId}',
            );

            // Update search radius from job data
            if (job.searchRadius != null && job.searchRadius != _searchRadius) {
              setState(() {
                _searchRadius = job.searchRadius!;
                _currentTier = _searchRadius <= 2000
                    ? 1
                    : (_searchRadius <= 5000 ? 2 : 3);
                _estimatedTime = _currentTier == 1
                    ? 3
                    : (_currentTier == 2 ? 5 : 8);
              });
            }

            if (job.status == 'accepted' &&
                job.technicianId != null &&
                !_navigating) {
              debugPrint(
                '✅ SearchingScreen: Job accepted! TechID: ${job.technicianId}',
              );
              _handleFoundTechnician(job);
            } else if (job.status == 'no_technician_found' && !_navigating) {
            } else if (job.status == 'no_technician_found' && !_navigating) {
              debugPrint('❌ SearchingScreen: No technician found');
              _navigating = true;
              _showNoTechnicianDialog();
            }
          },
          onError: (e) {
            debugPrint('🔴 SearchingScreen: Job watch error: $e');
          },
        );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rippleController.dispose();
    _jobSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: SafeArea(
        child: _technicianFound ? _buildFoundScreen() : _buildSearchingScreen(),
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
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderColor: AppTheme.primaryColor.withOpacity(0.5),
                            borderStrokeWidth: 2,
                          ),
                          // Inner solid circle
                          CircleMarker(
                            point: LatLng(_lat, _lng),
                            radius: 50,
                            useRadiusInMeter: true,
                            color: AppTheme.primaryColor.withOpacity(0.3),
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
              Positioned(
                top: 16.h,
                right: 32.w,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark.withOpacity(0.9),
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
                ),
              ).animate().fadeIn(delay: 500.ms),
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
                    'جاري البحث عن فني قريب...',
                    style: TextStyle(
                      fontSize: 20.fz,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .shimmer(
                    duration: 2.seconds,
                    color: AppTheme.primaryColor.withOpacity(0.3),
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
                                  color: AppTheme.primaryColor.withOpacity(0.5),
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
                  AppTheme.primaryColor.withOpacity(0.7),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.5),
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
                  color: Colors.green.withOpacity(0.4),
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
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
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
                                  color: Colors.green.withOpacity(0.2),
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
            onPressed: () => context.go('/active-job/${widget.jobId}'),
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
      builder: (context) => AlertDialog(
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
                  onPressed: () => Navigator.pop(context),
                  child: const Text('لا، استمر'),
                ),
              ),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    // Cancel the job
                    await ref
                        .read(jobRepositoryProvider)
                        .cancelJob(widget.jobId);
                    if (mounted) context.go('/');
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('نعم، إلغاء'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showNoTechnicianDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: Text(
          '😔 للأسف',
          style: TextStyle(
            fontSize: 20.fz,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        content: Text(
          'لم نتمكن من العثور على فني متاح حالياً.\nهل تود إعادة المحاولة؟',
          style: TextStyle(fontSize: 14.fz, color: Colors.white70),
          textAlign: TextAlign.center,
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.go('/');
                  },
                  child: const Text('لا، إلغاء'),
                ),
              ),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // Retry logic here
                  },
                  child: const Text('إعادة المحاولة'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
