import 'package:flutter/material.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';
import '../../core/services/fcm_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import '../../core/app_theme.dart';
import '../home/presentation/home_screen.dart';
import '../messages/presentation/messages_screen.dart';
import '../orders/presentation/orders_screen.dart';
import '../profile/presentation/profile_screen.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/data/auth_repository.dart';
import '../../core/services/notification_service.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomeScreenContent(),
    MessagesScreen(),
    OrdersScreen(),
    ProfileScreen(),
  ];

  StreamSubscription? _fcmSubscription;

  @override
  void initState() {
    super.initState();
    _setupNotificationListener();
  }

  void _setupNotificationListener() {
    _fcmSubscription = FcmService().navigationStream.listen((payload) {
      if (payload.isNotEmpty) {
        context.push('/active-job/$payload');
      }
    });
  }

  @override
  void dispose() {
    _fcmSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen for auth state changes to initialize notification service
    ref.listen(authStateChangesProvider, (previous, next) {
      next.when(
        data: (userId) {
          if (userId != null) {
            // Check if user is customer (default for MainScreen)
            final notificationService = ref.read(notificationServiceProvider);
            notificationService.listenForCustomerJobUpdates(userId);
            notificationService.listenForMessages(userId);
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
            _buildNavItem(0, Icons.home_rounded, 'الرئيسية'),
            _buildNavItem(1, Icons.mail_outline_rounded, 'الرسائل'),
            _buildNavItem(2, Icons.list_alt_rounded, 'الطلبات'),
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
