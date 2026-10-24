import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'admin_dashboard_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {}
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
      home: const AdminDashboardScreen(),
    );
  }
}
