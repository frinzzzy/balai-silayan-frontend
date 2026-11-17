import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../config/api_config.dart';
import '../models/staff_user_model.dart';
import 'admin_service.dart';

/// Resulta ng staff list fetch. May readable error para maipakita sa UI
/// (401 expired session, 403, timeout, atbp.).
class StaffListResult {
  const StaffListResult({this.staff = const <StaffUser>[], this.error});

  final List<StaffUser> staff;
  final String? error;

  bool get ok => error == null;
}

/// Resulta ng create / future account actions.
class StaffActionResult {
  const StaffActionResult({required this.ok, this.message, this.user});

  final bool ok;
  final String? message;
  final StaffUser? user;
}

/// Thin client para sa `/api/v1/admin/staff` (ADMIN only).
class AdminStaffService {
  final String _baseUrl = ApiConfig.baseUrl;

  Map<String, String> get _headers {
    final String? token = AdminService.staffAuthToken;
    final Map<String, String> headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// GET /api/v1/admin/staff
  Future<StaffListResult> fetchStaff() async {
    try {
      final http.Response response = await http
          .get(
            Uri.parse('$_baseUrl/api/v1/admin/staff'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 15));

      final Map<String, dynamic> body = _decodeBody(response.body);
      if (response.statusCode == 200) {
        final List<dynamic> raw =
            (body['data'] is List) ? body['data'] as List<dynamic> : <dynamic>[];
        final List<StaffUser> staff = raw
            .whereType<Map>()
            .map((item) => StaffUser.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        return StaffListResult(staff: staff);
      }

      if (response.statusCode == 401) {
        return const StaffListResult(
          error: 'Session expired. Please log out and sign in again.',
        );
      }
      if (response.statusCode == 403) {
        return const StaffListResult(
          error: 'Only ADMIN accounts can view staff management.',
        );
      }
      return StaffListResult(
        error: _messageOf(body, 'Failed to load staff accounts.'),
      );
    } catch (error) {
      debugPrint('Error fetching staff list: $error');
      return const StaffListResult(
        error: 'Cannot reach the server. Check your connection and retry.',
      );
    }
  }

  /// POST /api/v1/admin/staff
  Future<StaffActionResult> createStaff({
    required String name,
    required String username,
    required String role,
    required String password,
    String? pin,
  }) async {
    final Map<String, dynamic> payload = <String, dynamic>{
      'name': name,
      'username': username,
      'role': role,
      'temp_password': password,
      if (pin != null && pin.isNotEmpty) 'pin': pin,
    };

    try {
      final http.Response response = await http
          .post(
            Uri.parse('$_baseUrl/api/v1/admin/staff'),
            headers: _headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 20));

      final Map<String, dynamic> body = _decodeBody(response.body);
      if (response.statusCode == 201) {
        final dynamic data = body['data'];
        final StaffUser? user = data is Map
            ? StaffUser.fromJson(Map<String, dynamic>.from(data))
            : null;
        return StaffActionResult(
          ok: true,
          message: _messageOf(body, 'Staff account created.'),
          user: user,
        );
      }

      if (response.statusCode == 401) {
        return const StaffActionResult(
          ok: false,
          message: 'Session expired. Please log out and sign in again.',
        );
      }
      return StaffActionResult(
        ok: false,
        message: _messageOf(body, 'Failed to create staff account.'),
      );
    } catch (error) {
      debugPrint('Error creating staff account: $error');
      return const StaffActionResult(
        ok: false,
        message: 'Cannot reach the server. Check your connection and retry.',
      );
    }
  }

  /// POST /api/v1/admin/staff/:id/deactivate — "Remove account" action.
  /// Soft deactivate lang (is_active = FALSE + token invalidation); walang
  /// hard delete ang staff accounts.
  Future<StaffActionResult> deactivateStaff({required int staffId}) async {
    final http.Response response = await http
        .post(
          Uri.parse('$_baseUrl/api/v1/admin/staff/$staffId/deactivate'),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 20));

    final Map<String, dynamic> body = _decodeBody(response.body);
    if (response.statusCode == 200) {
      return StaffActionResult(
        ok: true,
        message: _messageOf(body, 'Staff account deactivated.'),
      );
    }

    if (response.statusCode == 401) {
      return const StaffActionResult(
        ok: false,
        message: 'Session expired. Please log out and sign in again.',
      );
    }
    if (response.statusCode == 409) {
      return const StaffActionResult(
        ok: false,
        message: 'You cannot remove your own account.',
      );
    }
    return StaffActionResult(
      ok: false,
      message: _messageOf(body, 'Failed to remove staff account.'),
    );
  }

  /// POST /api/v1/admin/staff/:id/activate — restore a removed (deactivated)
  /// staff account back to active status.
  Future<StaffActionResult> activateStaff({required int staffId}) async {
    final http.Response response = await http
        .post(
          Uri.parse('$_baseUrl/api/v1/admin/staff/$staffId/activate'),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 20));

    final Map<String, dynamic> body = _decodeBody(response.body);
    if (response.statusCode == 200) {
      final dynamic data = body['data'];
      final StaffUser? user = data is Map
          ? StaffUser.fromJson(Map<String, dynamic>.from(data))
          : null;
      return StaffActionResult(
        ok: true,
        message: _messageOf(body, 'Staff account activated.'),
        user: user,
      );
    }

    if (response.statusCode == 401) {
      return const StaffActionResult(
        ok: false,
        message: 'Session expired. Please log out and sign in again.',
      );
    }
    return StaffActionResult(
      ok: false,
      message: _messageOf(body, 'Failed to activate staff account.'),
    );
  }

  Map<String, dynamic> _decodeBody(String rawBody) {
    try {
      final dynamic decoded = jsonDecode(rawBody);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      // Non-JSON response (proxy error page, cold-start HTML, atbp.).
    }
    return <String, dynamic>{};
  }

  String _messageOf(Map<String, dynamic> body, String fallback) {
    final dynamic message = body['message'];
    if (message is String && message.trim().isNotEmpty) return message.trim();
    return fallback;
  }
}
