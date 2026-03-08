import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/services/location/location_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/fcm_service.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/widgets/kadmat_shell_navigation.dart';
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
      bottomNavigationBar: KadmatShellBottomBar(
        currentIndex: currentIndex,
        items: [
          KadmatShellNavItemData(
            icon: Icons.dashboard_rounded,
            label: 'الرئيسية',
            badgeCount: unreadNotifications,
            onTap: () =>
                ref.read(technicianTabIndexProvider.notifier).state = 0,
          ),
          KadmatShellNavItemData(
            icon: Icons.list_alt_rounded,
            label: 'الطلبات',
            onTap: () =>
                ref.read(technicianTabIndexProvider.notifier).state = 1,
          ),
          KadmatShellNavItemData(
            icon: Icons.account_balance_wallet_rounded,
            label: 'المحفظة',
            onTap: () =>
                ref.read(technicianTabIndexProvider.notifier).state = 2,
          ),
          KadmatShellNavItemData(
            icon: Icons.person_outline_rounded,
            label: 'حسابي',
            onTap: () =>
                ref.read(technicianTabIndexProvider.notifier).state = 3,
          ),
        ],
      ).animate().fadeIn(duration: 600.ms).slideY(begin: 1, end: 0),
    );
  }
}
