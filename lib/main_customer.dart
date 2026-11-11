import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'welcome_screen.dart';
import 'services/audio_notification_service.dart';
import 'services/fcm_service.dart';
import 'services/global_socket_listener.dart';
import 'services/notification_center.dart';
import 'services/supabase_realtime_service.dart';
import 'theme/app_theme.dart';

/// Lifecycle observer na nagdadala ng foreground/background state ng app sa
/// notification service (overlay vs system notification) at nagre-request ng
/// notification permission sa resume.
class NotificationLifecycleObserver with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final bool isForeground = state == AppLifecycleState.resumed;
    AudioNotificationService.setAppInForeground(isForeground);
    if (isForeground) {
      AudioNotificationService.flushPendingBanners();
      unawaited(AudioNotificationService.requestNotificationPermission());
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {}
  WidgetsBinding.instance.addObserver(NotificationLifecycleObserver());
  unawaited(AudioNotificationService.requestNotificationPermission());
  unawaited(AudioNotificationService.initializeLocalNotifications());
  unawaited(FcmService.init());
  unawaited(SupabaseRealtimeService.instance.start());
  runApp(const BalaiCustomerApp());
}

class BalaiCustomerApp extends StatelessWidget {
  const BalaiCustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Balai Silayan - Customer Portal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      scaffoldMessengerKey: AudioNotificationService.messengerKey,
      navigatorKey: NotificationCenter.navigatorKey,
      navigatorObservers: [GlobalOrderRouteObserver()],
      home: const WelcomeScreen(),
    );
  }
}
