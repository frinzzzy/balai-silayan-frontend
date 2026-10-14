import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/user_session.dart';

class ApiService {
  static String get _baseUrl {
    if (kIsWeb) return 'http://localhost:5000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5000';
    }
    return 'http://localhost:5000';
  }

  static Map<String, String> get _authHeaders {
    final token = UserSession.customerSessionToken ?? UserSession.authToken;
    final Map<String, String> headers = {"Content-Type": "application/json"};
    if (token != null && token.isNotEmpty) {
      headers["Authorization"] = "Bearer $token";
    }
    return headers;
  }

  /// Scan QR Token endpoint
  static Future<Map<String, dynamic>?> scanQrToken(String token) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/session/scan/$token'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint('ApiService.scanQrToken error: $e');
    }
    return null;
  }

  /// Fetch unfinished table orders
  static Future<List<dynamic>> fetchUnfinishedOrders(int tableId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/v1/orders/unfinished?table_id=$tableId'),
        headers: _authHeaders,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['orders'] ?? data['data'] ?? [];
      }
    } catch (e) {
      debugPrint('ApiService.fetchUnfinishedOrders error: $e');
    }
    return [];
  }

  /// Fetch Session Bill / Grand Total
  static Future<Map<String, dynamic>?> fetchSessionBill({int? sessionId, int? tableId}) async {
    try {
      final targetSessionId = sessionId ?? UserSession.activeSessionId ?? int.tryParse(UserSession.sessionId ?? '');
      final targetTableId = tableId ?? UserSession.activeTableId ?? 7;

      final Uri uri = targetSessionId != null
          ? Uri.parse('$_baseUrl/api/v1/customer/sessions/$targetSessionId/bill')
          : Uri.parse('$_baseUrl/api/v1/tables/$targetTableId/bill');

      final response = await http.get(uri, headers: _authHeaders);
      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        return resData['data'] is Map ? resData['data'] : null;
      }
    } catch (e) {
      debugPrint('ApiService.fetchSessionBill error: $e');
    }
    return null;
  }

  /// Force activate session dev helper
  static Future<Map<String, dynamic>?> forceActiveSession(int tableId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/dev/force-active-session'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"table_id": tableId}),
      );
      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        return resData['data'] is Map ? resData['data'] : null;
      }
    } catch (e) {
      debugPrint('ApiService.forceActiveSession error: $e');
    }
    return null;
  }
}
