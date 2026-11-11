import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'admin_dashboard_screen.dart';
import 'services/audio_notification_service.dart';
import 'services/notification_center.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {}

  // In-app banner/system notification infra para sa admin bill alerts.
  await AudioNotificationService.initializeLocalNotifications();
  await AudioNotificationService.requestNotificationPermission();
  WidgetsBinding.instance.addObserver(NotificationLifecycleObserver());

  runApp(const BalaiAdminApp());
}

class BalaiAdminApp extends StatelessWidget {
  const BalaiAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Balai Silayan - Admin & Staff Portal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      // Kailangan ito para makapag-overlay ng banner kahit saan sa app
      // (kasama ang mga nakabukas na dialog) at para may fallback messenger.
      navigatorKey: NotificationCenter.navigatorKey,
      scaffoldMessengerKey: NotificationCenter.messengerKey,
      home: const AdminDashboardScreen(),
    );
  }
}
