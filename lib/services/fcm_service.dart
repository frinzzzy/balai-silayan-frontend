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

  // Kapag may `notification` payload, ang Android FCM SDK na mismo ang
  // nagdi-display sa tray. Huwag nang mag-show muli para hindi doble.
  if (message.notification != null) return;

  final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

  final String title =
      message.data['title']?.toString() ?? 'Balai Silayan';
  final String body = message.data['body']?.toString() ?? '';

  await plugin.show(
    id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title: title,
    body: body,
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

  static const String _staffTokenPath = '/api/v1/staff/fcm-token';

  static String? _cachedToken;
  static bool _backgroundHandlerRegistered = false;
  static bool _tokenRefreshListening = false;

  // Huling role na na-register para maulit ang tamang endpoint kapag
  // nag-refresh ang FCM token.
  static String? _registeredMode; // 'customer' | 'staff'
  static String? _registeredStaffToken;
  static int? _registeredSessionId;
  static String? _registeredSessionToken;

  static Future<void> init() async {
    try {
      await Firebase.initializeApp();

      // I-register agad kahit denied ang permission. Kapag pinayagan ito sa
      // Settings at nag-resume ang app, hindi na kailangan ng app restart.
      if (!_backgroundHandlerRegistered) {
        FirebaseMessaging.onBackgroundMessage(fcmBackgroundMessageHandler);
        _backgroundHandlerRegistered = true;
      }

      if (!_tokenRefreshListening) {
        _tokenRefreshListening = true;
        FirebaseMessaging.instance.onTokenRefresh.listen((String newToken) {
          _cachedToken = newToken;
          debugPrint('🔄 [FCM] Token refreshed.');
          unawaited(_registerCurrentMode(newToken));
        });
      }

      final NotificationSettings settings =
          await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint(
          '⚠️ [FCM] Notification permission denied — push registration will retry on the next launch/resume.',
        );
        return;
      }

      final String? token = await _token();
      if (token == null) return;

      debugPrint('✅ [FCM] Token acquired.');
      await _registerCurrentMode(token);
    } catch (e) {
      debugPrint('⚠️ [FCM] init failed: $e');
    }
  }

  /// Re-register pagkatapos ng bagong session (QR scan / new order) para
  /// ma-link ang FCM token sa tamang session/table.
  static Future<void> registerCurrentSession() async {
    try {
      final int? sessionId = UserSession.activeSessionId ??
          int.tryParse(UserSession.sessionId ?? '');
      final String? sessionToken = UserSession.activeSessionToken;
      if (sessionId == null ||
          sessionId <= 0 ||
          sessionToken == null ||
          sessionToken.isEmpty) {
        return;
      }

      final String? token = await _token();
      if (token == null) return;

      await _registerAsCustomer(
        token: token,
        sessionId: sessionId,
        sessionToken: sessionToken,
      );
    } catch (e) {
      debugPrint('⚠️ [FCM] registerCurrentSession failed: $e');
    }
  }

  /// I-register ang device bilang staff/admin device. Tinatawag ito pagkatapos
  /// ng admin login para may background alerts ang admin kahit nasa labas ng app.
  static Future<void> registerAsStaff({String? authToken}) async {
    try {
      final String? token = authToken ?? UserSession.authToken;
      if (token == null || token.isEmpty) return;

      final String? fcmToken = await _token();
      if (fcmToken == null) return;

      await _registerAsStaff(token: fcmToken, staffAuthToken: token);
    } catch (e) {
      debugPrint('⚠️ [FCM] registerAsStaff failed: $e');
    }
  }

  /// Tanggalin ang staff token sa logout para hindi na padalhan ng admin
  /// alerts ang device na hindi na naka-login.
  static Future<void> unregisterAsStaff() async {
    final String? fcmToken = _cachedToken;
    final String? staffToken = _registeredStaffToken ?? UserSession.authToken;
    if (fcmToken == null || staffToken == null || staffToken.isEmpty) return;

    try {
      final http.Client client = http.Client();
      try {
        await client
            .delete(
              Uri.parse('${ApiConfig.baseUrl}$_staffTokenPath'),
              headers: <String, String>{
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $staffToken',
              },
              body: jsonEncode(<String, String>{'fcm_token': fcmToken}),
            )
            .timeout(const Duration(seconds: 15));
      } finally {
        client.close();
      }
      debugPrint('✅ [FCM] Staff token unregistered.');
    } catch (e) {
      debugPrint('⚠️ [FCM] unregisterAsStaff error: $e');
    } finally {
      if (_registeredMode == 'staff') {
        _registeredMode = null;
        _registeredStaffToken = null;
      }
    }
  }

  static Future<String?> _token() async {
    if (_cachedToken != null && _cachedToken!.isNotEmpty) return _cachedToken;
    final String? token = await FirebaseMessaging.instance.getToken();
    if (token != null && token.isNotEmpty) {
      _cachedToken = token;
      return token;
    }
    return null;
  }

  static Future<void> _registerCurrentMode(String token) async {
    if (_registeredMode == 'staff' && _registeredStaffToken != null) {
      await _registerAsStaff(
        token: token,
        staffAuthToken: _registeredStaffToken!,
      );
      return;
    }

    if (_registeredMode == 'customer' &&
        _registeredSessionId != null &&
        _registeredSessionToken != null) {
      await _registerAsCustomer(
        token: token,
        sessionId: _registeredSessionId!,
        sessionToken: _registeredSessionToken!,
      );
      return;
    }

    await registerCurrentSession();
  }

  static Future<void> _registerAsCustomer({
    required String token,
    required int sessionId,
    required String sessionToken,
  }) async {
    try {
      final http.Response response = await _postJson(
        '${ApiConfig.baseUrl}/api/v1/customer/sessions/$sessionId/fcm-token',
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $sessionToken',
        },
        body: <String, dynamic>{'fcm_token': token},
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        _registeredMode = 'customer';
        _registeredSessionId = sessionId;
        _registeredSessionToken = sessionToken;
        debugPrint('✅ [FCM] Customer token registered (status=${response.statusCode}).');
      } else {
        debugPrint(
          '⚠️ [FCM] Customer token registration failed (status=${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('⚠️ [FCM] registerAsCustomer error: $e');
    }
  }

  static Future<void> _registerAsStaff({
    required String token,
    required String staffAuthToken,
  }) async {
    try {
      final http.Response response = await _postJson(
        '${ApiConfig.baseUrl}$_staffTokenPath',
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $staffAuthToken',
        },
        body: <String, dynamic>{'fcm_token': token},
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        _registeredMode = 'staff';
        _registeredStaffToken = staffAuthToken;
        _registeredSessionId = null;
        _registeredSessionToken = null;
        debugPrint('✅ [FCM] Staff token registered (status=${response.statusCode}).');
      } else {
        debugPrint(
          '⚠️ [FCM] Staff token registration failed (status=${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('⚠️ [FCM] registerAsStaff error: $e');
    }
  }

  static Future<http.Response> _postJson(
    String url, {
    required Map<String, String> headers,
    required Map<String, dynamic> body,
  }) async {
    final http.Client client = http.Client();
    try {
      return await client
          .post(Uri.parse(url), headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
    } finally {
      client.close();
    }
  }
}
