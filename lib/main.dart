import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'qr_scanner_screen.dart';
import 'admin_dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {}
  runApp(const ProductionSoftEngApp());
}

class ProductionSoftEngApp extends StatelessWidget {
  const ProductionSoftEngApp({super.key});

  // Toggle this to true to boot directly into the Admin Dashboard for testing/presentation,
  // or false to boot into the normal Customer QR Scanner screen.
  static const bool showAdminDashboardDirectly = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Balai Silayan Heritage Restaurant',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: const Color(0xFFF8F4EC), // Heritage Cream Background
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF203F35),      // Deep Forest Heritage Green
          secondary: Color(0xFFA47C3D),    // Heritage Gold
          surface: Color(0xFFFFFDFA),      // Ivory Card Surface
          error: Color(0xFF8E5136),        // Terracotta Rust
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF203F35), letterSpacing: -0.3),
          bodyMedium: TextStyle(color: Color(0xFF788078), height: 1.4),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFFFFDFA),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          labelStyle: const TextStyle(color: Color(0xFF788078), fontWeight: FontWeight.w500),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5DFD3))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5DFD3))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(
              0xFF500808), width: 1.8)),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFFFFFDFA),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFE5DFD3)),
          ),
        ),
      ),
      home: showAdminDashboardDirectly
          ? const AdminDashboardScreen()
          : const QrScannerScreen(),
    );
  }
}
