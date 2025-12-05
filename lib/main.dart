import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'src/core/app_theme.dart';
import 'src/core/router.dart';
import 'src/core/services/local_notifications.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'src/core/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

  // Initialize Hive for caching
  await Hive.initFlutter();
  await Hive.openBox('app_cache');

  // Initialize local notifications
  final notificationService = LocalNotificationsService();
  await notificationService.initialize();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);

    return ResponsiveProvider(
      child: MaterialApp.router(
        title: 'Kadmat',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark, // Enforce dark mode as requested
        routerConfig: router,
        builder: (context, child) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          );
        },
      ),
    );
  }
}
