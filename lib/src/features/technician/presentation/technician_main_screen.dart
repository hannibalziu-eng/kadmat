import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import '../../../core/app_theme.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/notification_service.dart';
import '../../auth/data/auth_repository.dart';

import '../data/technician_repository.dart';
import 'dashboard/technician_dashboard_screen.dart';
import 'requests/technician_requests_screen.dart';
import 'wallet/technician_wallet_screen.dart';
import 'profile/technician_profile_screen.dart';

class TechnicianMainScreen extends ConsumerStatefulWidget {
  const TechnicianMainScreen({super.key});

  @override
  ConsumerState<TechnicianMainScreen> createState() =>
      _TechnicianMainScreenState();
}

class _TechnicianMainScreenState extends ConsumerState<TechnicianMainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    TechnicianDashboardScreen(),
    TechnicianRequestsScreen(),
    TechnicianWalletScreen(),
    TechnicianProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // Listen to location updates and sync with backend
    ref.listen(locationStreamProvider, (previous, next) {
      next.when(
        data: (position) {
          ref
              .read(technicianRepositoryProvider)
              .updateLocation(position.latitude, position.longitude);

          // Update notification listener for new requests based on location
          ref
              .read(notificationServiceProvider)
              .listenForNewRequests(position.latitude, position.longitude);
        },
        error: (error, stackTrace) {
          // Handle location error if needed
        },
        loading: () {},
      );
    });

    // Initialize notification listeners for job updates
    // Listen for auth state changes and set up listeners when user logs in
    ref.listen(authStateChangesProvider, (previous, next) {
      next.when(
        data: (userId) {
          if (userId != null) {
            ref.read(notificationServiceProvider).listenForJobUpdates(userId);
          }
        },
        error: (error, stackTrace) {},
        loading: () {},
      );
    });

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: Container(
        margin: EdgeInsets.all(24.w),
        height: 70.h,
        decoration: AppTheme.glassDecoration(
          radius: 35.r,
          color: Theme.of(context).cardColor,
          opacity: 0.85,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(0, Icons.dashboard_rounded, 'الرئيسية'),
            _buildNavItem(1, Icons.list_alt_rounded, 'الطلبات'),
            _buildNavItem(2, Icons.account_balance_wallet_rounded, 'المحفظة'),
            _buildNavItem(3, Icons.person_outline_rounded, 'حسابي'),
          ],
        ),
      ).animate().fadeIn(duration: 600.ms).slideY(begin: 1, end: 0),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
                icon,
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.grey,
                size: 24.s,
              )
              .animate(target: isSelected ? 1 : 0)
              .scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2))
              .tint(color: Theme.of(context).primaryColor),
          SizedBox(height: 4.h),
          if (isSelected)
            Container(
              width: 4.w,
              height: 4.w,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                shape: BoxShape.circle,
              ),
            ).animate().fadeIn().scale(),
        ],
      ),
    );
  }
}
