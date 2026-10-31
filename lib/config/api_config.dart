class ApiConfig {
  /// 🔴 LIVE RENDER BACKEND URL - ginagamit para sa cloud-based / multi-user testing.
  static const String liveBackendUrl = 'https://softengproject.onrender.com';

  /// ⚠️ MAHALAGA PARA SA LOCAL DEVELOPMENT:
  /// Kung ang iyong phone at laptop ay magkakonekta sa iisang Wi-Fi (o Hotspot),
  /// ilagay dito ang Local IP address ng iyong laptop (halimbawa: '192.168.1.50:5000').
  /// Kung naka-Android Emulator ka, iwanan itong blangko ('').
  /// (Para sa cloud backend, iwanan itong blangko at gamitin ang [liveBackendUrl].)
  static const String customLaptopIp = '';

  static String get baseUrl {
    if (customLaptopIp.isNotEmpty) {
      return customLaptopIp.startsWith('http') ? customLaptopIp : 'http://$customLaptopIp';
    }
    return liveBackendUrl;
  }
}
