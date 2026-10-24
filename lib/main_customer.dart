import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'qr_scanner_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {}
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
      home: const QrScannerScreen(),
    );
  }
}
