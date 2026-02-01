import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'src/core/app_theme.dart';
import 'src/core/router_modular.dart';
import 'src/core/widgets/offline_banner.dart';
import 'src/core/services/local_notifications.dart';
import 'src/core/services/fcm_service.dart';
import 'src/core/services/offline/adapters/pending_request_adapter.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'src/core/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize Supabase
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

  // Initialize Hive for caching
  await Hive.initFlutter();
  Hive.registerAdapter(
    PendingRequestAdapter(),
  ); // Register PendingRequest Adapter
  await Hive.openBox('app_cache');

  // Initialize local notifications
  final notificationService = LocalNotificationsService();
  await notificationService.initialize();

  // Initialize FCM
  try {
    // Note: Only works if google-services.json / GoogleService-Info.plist are present
    await FcmService().initialize();
  } catch (e) {
    debugPrint('FCM Init Failed: $e');
  }

  runApp(
    ProviderScope(
      overrides: [
        localNotificationsProvider.overrideWithValue(notificationService),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();

    // Listen for auth state changes and handle errors
    Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        final event = data.event;
        debugPrint('🔐 Auth State Changed: $event');

        // If signed out due to invalid token, the router will handle redirect
        if (event == AuthChangeEvent.signedOut) {
          debugPrint('👋 User signed out - redirecting to welcome screen');
        }
      },
      onError: (error) {
        // Handle auth errors like Invalid Refresh Token
        debugPrint('🚨 Auth Error: $error');
        if (error is AuthException) {
          final msg = error.message.toLowerCase();
          if (msg.contains('refresh_token_already_used') ||
              msg.contains('invalid refresh token') ||
              msg.contains('session_not_found')) {
            debugPrint('🧹 Clearing corrupted session...');
            // Sign out to clear the bad session
            Supabase.instance.client.auth.signOut().catchError((_) {});
          }
        }
      },
    );

    // Listen for notification taps
    ref.read(localNotificationsProvider).onNotificationTap.listen((payload) {
      if (payload != null) {
        debugPrint('🔔 Notification Tapped with payload: $payload');
        // Check if payload is a Job ID (simple string)
        if (payload.isNotEmpty) {
          // Navigate to job details or active job screen
          // We assume payload is Job ID.
          // We can verify if user is technician or customer to route correctly,
          // but for now let's route to a generic loading or check.

          // Actually, we can check auth state user type here?
          // Or just push to a route that handles redirection.
          // Let's try to navigate to /active-job/$payload for now,
          // assuming customer context is most common for notifications about updates.
          // Ideally, the payload should contain type info like "job_id:123|type:technician"

          // For this phase, let's assume specific job ID navigation.
          ref.read(goRouterProvider).push('/active-job/$payload');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: 'Kadmat',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark, // Enforce dark mode as requested
      routerConfig: router,
      builder: (context, child) {
        return ResponsiveProvider(
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Stack(children: [child!, const OfflineBanner()]),
          ),
        );
      },
    );
  }
}
