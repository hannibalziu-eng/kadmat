import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'src/core/app_theme.dart';
import 'src/core/router_modular.dart';
import 'src/core/navigation/app_routes.dart';
import 'src/core/widgets/offline_banner.dart';
import 'src/core/services/local_notifications.dart';
import 'src/core/services/fcm_service.dart';
import 'src/core/services/offline/adapters/pending_request_adapter.dart';
import 'src/core/services/location/location_service.dart';
import 'src/features/auth/data/auth_repository.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'src/core/constants.dart';
import 'src/core/app_lifecycle_manager.dart';

import 'package:easy_localization/easy_localization.dart';

void main() async {
  debugPrint('🚀 APP STARTING - INITIALIZING...');
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('✅ WidgetsFlutterBinding Initialized');

  try {
    await EasyLocalization.ensureInitialized();
    debugPrint('✅ EasyLocalization Initialized');
  } catch (e) {
    debugPrint('❌ EasyLocalization Failed: $e');
  }

  // Load environment variables
  try {
    await dotenv.load(fileName: ".env");
    debugPrint('✅ DotEnv Loaded');
  } catch (e) {
    debugPrint('❌ DotEnv Failed (Likely missing .env file): $e');
    // Continue anyway, Supabase might fail later if keys are missing from env
  }

  // Initialize Supabase
  try {
    debugPrint('🔌 Initializing Supabase...');
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
    );
    debugPrint('✅ Supabase Initialized');
  } catch (e) {
    debugPrint('❌ Supabase Init Failed: $e');
  }

  // Initialize Firebase Core (required for FCM/Crashlytics/Performance)
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp();
      debugPrint('✅ Firebase Core Initialized');
    } catch (e) {
      debugPrint('⚠️ Firebase Core Init Failed: $e');
    }
  }

  // Initialize Crashlytics
  if (!kIsWeb) {
    try {
      // Pass all uncaught "fatal" errors from the framework to Crashlytics
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
      debugPrint('✅ Crashlytics Initialized');
    } catch (e) {
      debugPrint(
        '⚠️ Crashlytics Init Failed (Expected on Web/Sim without config): $e',
      );
    }
  }

  // Initialize Performance Monitoring
  if (!kIsWeb) {
    try {
      await FirebasePerformance.instance.setPerformanceCollectionEnabled(true);
      debugPrint('✅ Performance Monitor Initialized');
    } catch (e) {
      debugPrint('⚠️ Performance Init Failed: $e');
    }
  }

  // Initialize Hive for caching
  try {
    await Hive.initFlutter();
    Hive.registerAdapter(
      PendingRequestAdapter(),
    ); // Register PendingRequest Adapter
    await Hive.openBox('app_cache');
    debugPrint('✅ Hive Initialized');
  } catch (e) {
    debugPrint('❌ Hive Init Failed: $e');
  }

  // Initialize local notifications
  final localNotifications = LocalNotificationsService();
  try {
    await localNotifications.initialize();
    debugPrint('✅ LocalNotifications Initialized');
  } catch (e) {
    debugPrint('❌ LocalNotifications Init Failed: $e');
  }

  // Initialize FCM
  if (!kIsWeb) {
    try {
      // Note: Only works if google-services.json / GoogleService-Info.plist are present
      await FcmService().initialize();
      debugPrint('✅ FCM Initialized');
    } catch (e) {
      debugPrint('⚠️ FCM Init Failed: $e');
    }
  } else {
    debugPrint('ℹ️ FCM skipped on Web');
  }

  // Initialize Location Service (Background Config)
  try {
    await LocationService().initialize();
    debugPrint('✅ LocationService Initialized');
  } catch (e) {
    debugPrint('❌ LocationService Init Failed: $e');
  }

  debugPrint('🚀 CALLING runAPP...');

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('ar'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('ar'),
      startLocale: const Locale('ar'),
      child: ProviderScope(
        overrides: [
          localNotificationsProvider.overrideWithValue(localNotifications),
        ],
        child: const MyApp(),
      ),
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
          final userType = ref.read(authRepositoryProvider).userType;
          final route = userType == 'technician'
              ? AppRoutes.buildTechnicianJobDetailPath(payload)
              : AppRoutes.buildCustomerSearchingPath(payload);
          ref.read(goRouterProvider).push(route);
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
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      builder: (context, child) {
        return ResponsiveProvider(
          child: Directionality(
            textDirection: context.locale.languageCode == 'ar'
                ? ui.TextDirection.rtl
                : ui.TextDirection.ltr,
            child: AppLifecycleManager(
              child: Stack(children: [child!, const OfflineBanner()]),
            ),
          ),
        );
      },
    );
  }
}
