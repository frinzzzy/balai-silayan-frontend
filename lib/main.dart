import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'qr_scanner_screen.dart';
import 'admin_dashboard_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {}
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
      home: showAdminDashboardDirectly
          ? const AdminDashboardScreen()
          : const QrScannerScreen(),
    );
  }
}
