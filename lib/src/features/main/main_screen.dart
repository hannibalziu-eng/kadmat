import 'package:flutter/material.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';
import '../../core/services/fcm_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/widgets/kadmat_shell_navigation.dart';
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
  ProviderSubscription<AsyncValue<String?>>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _setupNotificationListener();
    _setupAuthListener();
  }

  void _setupNotificationListener() {
    final pushGateway = ref.read(pushGatewayProvider);
    _fcmSubscription = pushGateway.navigationStream.listen((payload) {
      if (payload.isNotEmpty) {
        if (!mounted) return;
        context.push(AppRoutes.buildCustomerSearchingPath(payload));
      }
    });
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
            notificationService.listenForCustomerJobUpdates(
              authenticatedUserId,
            );
            notificationService.listenForMessages(authenticatedUserId);
          },
          error: (_, __) {},
          loading: () {},
        );
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _fcmSubscription?.cancel();
    _authSubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: KadmatShellBottomBar(
        currentIndex: _currentIndex,
        items: [
          KadmatShellNavItemData(
            icon: Icons.home_rounded,
            label: 'الرئيسية',
            onTap: () => setState(() => _currentIndex = 0),
          ),
          KadmatShellNavItemData(
            icon: Icons.mail_outline_rounded,
            label: 'الرسائل',
            onTap: () => setState(() => _currentIndex = 1),
          ),
          KadmatShellNavItemData(
            icon: Icons.list_alt_rounded,
            label: 'الطلبات',
            onTap: () => setState(() => _currentIndex = 2),
          ),
          KadmatShellNavItemData(
            icon: Icons.person_outline_rounded,
            label: 'حسابي',
            onTap: () => setState(() => _currentIndex = 3),
          ),
        ],
      ).animate().fadeIn(duration: 600.ms).slideY(begin: 1, end: 0),
    );
  }
}
