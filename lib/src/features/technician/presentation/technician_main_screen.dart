import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/app_theme.dart';
import '../../../core/services/location/location_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/fcm_service.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/navigation/app_routes.dart';
import '../../auth/data/auth_repository.dart';
import '../../notifications/data/notification_repository.dart';

import '../data/technician_repository.dart';
import 'dashboard/technician_dashboard_screen.dart';
import 'providers/technician_tab_provider.dart';
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
  final List<Widget> _pages = const [
    TechnicianDashboardScreen(),
    TechnicianRequestsScreen(),
    TechnicianWalletScreen(),
    TechnicianProfileScreen(),
  ];

  StreamSubscription? _fcmSubscription;
  ProviderSubscription<AsyncValue<Position>>? _locationSubscription;
  ProviderSubscription<AsyncValue<String?>>? _authSubscription;
  ProviderSubscription<int>? _unreadNotificationsSubscription;

  @override
  void initState() {
    super.initState();
    _setupNotificationListener();
    _setupLocationSyncListener();
    _setupAuthListener();
    _setupUnreadNotificationsListener();
  }

  void _setupNotificationListener() {
    final pushGateway = ref.read(pushGatewayProvider);
    _fcmSubscription = pushGateway.navigationStream.listen((payload) {
      if (payload.isNotEmpty && mounted) {
        // For technicians, navigate to the job detail screen
        context.push(AppRoutes.buildTechnicianJobDetailPath(payload));
      }
    });
  }

  void _setupLocationSyncListener() {
    _locationSubscription = ref.listenManual<AsyncValue<Position>>(
      locationStreamProvider,
      (_, next) {
        next.when(
          data: (position) {
            ref
                .read(technicianRepositoryProvider)
                .updateLocation(position.latitude, position.longitude);
            ref
                .read(notificationServiceProvider)
                .listenForNewRequests(position.latitude, position.longitude);
          },
          error: (_, __) {},
          loading: () {},
        );
      },
      fireImmediately: true,
    );
  }

  void _setupAuthListener() {
    _authSubscription = ref.listenManual<AsyncValue<String?>>(
      authStateChangesProvider,
      (_, next) {
        next.when(
          data: (_) {
            final authenticatedUserId =
                Supabase.instance.client.auth.currentUser?.id;
            if (authenticatedUserId == null) return;

            final notificationService = ref.read(notificationServiceProvider);
            unawaited(notificationService.initialize());
            notificationService.listenForJobUpdates(authenticatedUserId);
            notificationService.listenForMessages(authenticatedUserId);
          },
          error: (_, __) {},
          loading: () {},
        );
      },
      fireImmediately: true,
    );
  }

  void _setupUnreadNotificationsListener() {
    _unreadNotificationsSubscription = ref.listenManual<int>(
      liveUnreadNotificationsCountProvider,
      (previous, next) {
        if (!mounted) return;
        if (previous == null) return;
        if (next <= previous) return;

        final delta = next - previous;
        final label = delta == 1 ? 'إشعار جديد' : '$delta إشعارات جديدة';
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('لديك $label في لوحة الفني'),
            action: SnackBarAction(
              label: 'عرض',
              onPressed: () => context.push(AppRoutes.notifications),
            ),
          ),
        );
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _fcmSubscription?.cancel();
    _locationSubscription?.close();
    _authSubscription?.close();
    _unreadNotificationsSubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(technicianTabIndexProvider);
    final unreadNotifications = ref.watch(liveUnreadNotificationsCountProvider);

    return Scaffold(
      extendBody: true,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: KeyedSubtree(
          key: ValueKey<int>(currentIndex),
          child: _pages[currentIndex],
        ),
      ),
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
            _buildNavItem(
              0,
              currentIndex,
              Icons.dashboard_rounded,
              'الرئيسية',
              badgeCount: unreadNotifications,
            ),
            _buildNavItem(1, currentIndex, Icons.list_alt_rounded, 'الطلبات'),
            _buildNavItem(
              2,
              currentIndex,
              Icons.account_balance_wallet_rounded,
              'المحفظة',
            ),
            _buildNavItem(
              3,
              currentIndex,
              Icons.person_outline_rounded,
              'حسابي',
            ),
          ],
        ),
      ).animate().fadeIn(duration: 600.ms).slideY(begin: 1, end: 0),
    );
  }

  Widget _buildNavItem(
    int index,
    int currentIndex,
    IconData icon,
    String label, {
    int badgeCount = 0,
  }) {
    final isSelected = currentIndex == index;
    return Semantics(
      button: true,
      label: label,
      selected: isSelected,
      child: Tooltip(
        message: label,
        child: GestureDetector(
          onTap: () =>
              ref.read(technicianTabIndexProvider.notifier).state = index,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
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
                      .scale(
                        begin: const Offset(1, 1),
                        end: const Offset(1.2, 1.2),
                      )
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
              if (badgeCount > 0)
                Positioned(
                  top: -5,
                  right: -5,
                  child: GestureDetector(
                    onTap: () => context.push(AppRoutes.notifications),
                    child: Container(
                      padding: EdgeInsets.all(4.w),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        badgeCount > 9 ? '+9' : badgeCount.toString(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10.fz,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
