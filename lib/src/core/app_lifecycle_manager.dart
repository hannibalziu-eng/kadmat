import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/presence/presence_service.dart';

class AppLifecycleManager extends ConsumerStatefulWidget {
  final Widget child;
  const AppLifecycleManager({super.key, required this.child});

  @override
  ConsumerState<AppLifecycleManager> createState() =>
      _AppLifecycleManagerState();
}

class _AppLifecycleManagerState extends ConsumerState<AppLifecycleManager>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final presenceService = ref.read(presenceServiceProvider);

    switch (state) {
      case AppLifecycleState.resumed:
        // User came back to app -> Online
        // Only if they were previously "Away" (don't force online if they manually set Busy/Offline)
        if (presenceService.currentStatus == UserPresenceStatus.away) {
          presenceService.setStatus(UserPresenceStatus.online, userId);
          debugPrint('📱 App Resumed: Set to Online');
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        // App backgrounded -> Away
        // Only if they are currently "Online"
        if (presenceService.currentStatus == UserPresenceStatus.online) {
          presenceService.setStatus(UserPresenceStatus.away, userId);
          debugPrint('📱 App Backgrounded: Set to Away');
        }
        break;
      case AppLifecycleState.detached:
        // App killed -> Offline ideally, but tough to guarantee execution.
        // We rely on Supabase Realtime "disconnect" eventually detecting it,
        // or we try to set it here best-effort.
        presenceService.disconnect();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
