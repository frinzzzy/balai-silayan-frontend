import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'menu_screen.dart';
import 'user_session.dart';
import 'welcome_screen.dart';
import 'admin_dashboard_screen.dart';
import 'services/audio_notification_service.dart';
import 'services/customer_notification_router.dart';
import 'services/fcm_service.dart';
import 'services/global_socket_listener.dart';
import 'services/notification_center.dart';
import 'services/session_bootstrap.dart';
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
      unawaited(AudioNotificationService.restoreHistoryOnResume());
      unawaited(AudioNotificationService.requestNotificationPermission());
    } else {
      // I-save agad ang session bago pa patayin ng OS ang app.
      UserSession.persist();
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {}
  WidgetsBinding.instance.addObserver(NotificationLifecycleObserver());
  // I-restore ang dating session/cart bago i-register ang FCM token para
  // tama agad ang customer na naka-link sa device.
  await SessionBootstrap.restore();
  // Customer push/history taps → ticket. Ang admin dashboard ang mag-o-override
  // kapag binuksan ito (may sariling handler).
  CustomerNotificationRouter.register();
  unawaited(AudioNotificationService.requestNotificationPermission());
  unawaited(AudioNotificationService.loadPersistedHistory());
  unawaited(AudioNotificationService.initializeLocalNotifications());
  unawaited(FcmService.init());
  unawaited(SupabaseRealtimeService.instance.start());
  runApp(const ProductionSoftEngApp());
}

class ProductionSoftEngApp extends StatelessWidget {
  const ProductionSoftEngApp({super.key});

  static const bool showAdminDashboardDirectly =  false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Balai Silayan Heritage Restaurant',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      scaffoldMessengerKey: AudioNotificationService.messengerKey,
      navigatorKey: NotificationCenter.navigatorKey,
      navigatorObservers: [GlobalOrderRouteObserver()],
      home: showAdminDashboardDirectly
          ? const AdminDashboardScreen()
          : SessionBootstrap.hasRestoredSession
              ? MenuScreen(
                  tableId: UserSession.activeTableId,
                  tableNumber: UserSession.activeTableNumber,
                  isTakeout: UserSession.isTakeout,
                )
              : const WelcomeScreen(),
    );
  }
}
