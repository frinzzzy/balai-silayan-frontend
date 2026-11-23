import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Raw local storage para sa customer session at cart.
///
/// Sinadya nitong **hindi** i-import ang `UserSession` o `CustomerCartStore`
/// para maiwasan ang circular dependency. Ang `SessionBootstrap` ang
/// nag-a-apply ng naka-save na data pabalik sa app.
///
/// Layunin: kapag na-kill ang app (o na-restart ang phone), maibalik ang
/// Google session, table, at cart — hindi na kailangang mag-login o mag-scan
/// muli.
class SessionPersistence {
  SessionPersistence._();

  static final SessionPersistence instance = SessionPersistence._();

  static const String _sessionKey = 'customer_session_v1';
  static const String _cartKey = 'customer_cart_v1';

  /// Gaano katagal pwedeng i-restore ang isang session. Tugma ito sa 30-day
  /// expiry ng backend-issued customer session JWT; mas matanda pa doon ay
  /// siguradong tanggihan na ng server, kaya mas mabuting huwag nang i-restore.
  static const Duration maxSessionAge = Duration(days: 30);

  Future<void> saveSession(Map<String, dynamic> session) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> payload = <String, dynamic>{
        ...session,
        'savedAt': DateTime.now().millisecondsSinceEpoch,
      };
      await prefs.setString(_sessionKey, jsonEncode(payload));
    } catch (error) {
      debugPrint('⚠️ [SessionPersistence] saveSession failed: $error');
    }
  }

  Future<Map<String, dynamic>?> loadSession() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_sessionKey);
      if (raw == null || raw.isEmpty) return null;
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return Map<String, dynamic>.from(decoded);
    } catch (error) {
      debugPrint('⚠️ [SessionPersistence] loadSession failed: $error');
      return null;
    }
  }

  /// `key` ang cart scope (hal. `table:12`), para hindi ma-restore ang cart ng
  /// ibang table/session.
  Future<void> saveCart(
    String key,
    List<Map<String, dynamic>> lines,
    String notes,
  ) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> payload = <String, dynamic>{
        'key': key,
        'lines': lines,
        'notes': notes,
      };
      await prefs.setString(_cartKey, jsonEncode(payload));
    } catch (error) {
      debugPrint('⚠️ [SessionPersistence] saveCart failed: $error');
    }
  }

  /// Ibinabalik ang cart **kung tugma** ang naka-save na key sa [key].
  Future<List<Map<String, dynamic>>> loadCart(String key) async {
    final Map<String, dynamic>? payload = await _loadCartPayload();
    if (payload == null || payload['key'] != key) {
      return const <Map<String, dynamic>>[];
    }
    final dynamic lines = payload['lines'];
    if (lines is! List) return const <Map<String, dynamic>>[];
    return lines
        .whereType<Map>()
        .map((Map row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  /// Ibinabalik ang kitchen notes **kung tugma** ang naka-save na key.
  Future<String> loadNotes(String key) async {
    final Map<String, dynamic>? payload = await _loadCartPayload();
    if (payload == null || payload['key'] != key) return '';
    return payload['notes']?.toString() ?? '';
  }

  Future<Map<String, dynamic>?> _loadCartPayload() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_cartKey);
      if (raw == null || raw.isEmpty) return null;
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return Map<String, dynamic>.from(decoded);
    } catch (error) {
      debugPrint('⚠️ [SessionPersistence] loadCart failed: $error');
      return null;
    }
  }

  Future<void> clear() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
      await prefs.remove(_cartKey);
    } catch (error) {
      debugPrint('⚠️ [SessionPersistence] clear failed: $error');
    }
  }
}
