import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../user_session.dart';

/// FCM background handler — kapag PATAY o naka-background ang app, ito ang
/// mag-a-post ng notification sa system tray (gamit ang existing local
/// notifications plugin, para sa consistent na channel + icon).
@pragma('vm:entry-point')
Future<void> fcmBackgroundMessageHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

  final String? title = message.notification?.title;
  final String? body = message.notification?.body;

  await plugin.show(
    id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title: message.data['title']?.toString() ?? title ?? 'Balai Silayan',
    body: message.data['body']?.toString() ?? body ?? '',
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        'balai_silayan_orders',
        'Balai Silayan Order Alerts',
        channelDescription: 'Balai Silayan order status alerts',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: 'ic_stat_balai',
      ),
    ),
    payload: message.data['order_id']?.toString(),
  );
}

class FcmService {
  FcmService._();

  static String? _cachedToken;

  static Future<void> init() async {
    try {
      await Firebase.initializeApp();

      FirebaseMessaging.onBackgroundMessage(fcmBackgroundMessageHandler);

      final NotificationSettings settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('⚠️ [FCM] Notification permission denied.');
        return;
      }

      final String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        _cachedToken = token;
        debugPrint('✅ [FCM] Token acquired: $token');
        await _register(token);
      }

      FirebaseMessaging.instance.onTokenRefresh.listen((String newToken) {
        _cachedToken = newToken;
        debugPrint('🔄 [FCM] Token refreshed: $newToken');
        _register(newToken);
      });
    } catch (e) {
      debugPrint('⚠️ [FCM] init failed: $e');
    }
  }

  /// Re-register pagkatapos ng bagong session (QR scan / new order) para
  /// ma-link ang FCM token sa tamang session/table.
  static Future<void> registerCurrentSession() async {
    try {
      final String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        _cachedToken = token;
        await _register(token);
      }
    } catch (e) {
      debugPrint('⚠️ [FCM] registerCurrentSession failed: $e');
    }
  }

  static Future<void> _register(String token) async {
    try {
      final http.Client client = http.Client();
      final http.Response response = await client.post(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/devices/register'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': token,
          'session_id': UserSession.activeSessionId,
          'table_id': UserSession.activeTableId,
        }),
      );
      client.close();
      debugPrint('✅ [FCM] Token registered (status=${response.statusCode}).');
    } catch (e) {
      debugPrint('⚠️ [FCM] register error: $e');
    }
  }
}
