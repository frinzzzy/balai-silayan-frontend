import 'package:flutter/foundation.dart';

class ApiConfig {
  /// ⚠️ MAHALAGA PARA SA REAL PHONE / APK SETUP:
  /// Kung ang iyong phone at laptop ay magkakonekta sa iisang Wi-Fi (o Hotspot),
  /// ilagay dito ang Local IP address ng iyong laptop (halimbawa: '192.168.1.50:5000').
  /// Kung naka-Android Emulator ka, iwanan itong blangko ('').
  static const String customLaptopIp = '';

  static String get baseUrl {
    if (customLaptopIp.isNotEmpty) {
      return customLaptopIp.startsWith('http') ? customLaptopIp : 'http://$customLaptopIp';
    }
    if (kIsWeb) {
      return 'http://localhost:5000';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5000'; // Android Emulator loopback
    }
    return 'http://localhost:5000';
  }
}
