import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../user_session.dart';
import 'customer_cart_store.dart';
import 'session_persistence.dart';

/// Nagre-restore ng naka-save na customer session + cart bago mag-`runApp`.
///
/// Ito ang nagbibigay ng "tuloy pa rin kahit na-kill ang app": kapag may
/// valid at hindi pa expired na session sa `SharedPreferences`, awtomatikong
/// bubukas ang Menu (takeout o dine-in) at ibabalik ang laman ng cart.
///
/// Para sa **dine-in (QR)**, vine-verify muna sa backend kung bukas pa ang
/// table session bago i-restore — para kapag settled/closed na ang mesa
/// (bayad na, o pinatay ng cashier), hindi na muling buksan ang lumang mesa
/// at babalik ang customer sa Welcome/QR flow.
class SessionBootstrap {
  SessionBootstrap._();

  static bool _hasRestoredSession = false;

  /// `true` kapag may na-restore na session — gamitin ito para piliin kung
  /// `MenuScreen` o `WelcomeScreen` ang initial home.
  static bool get hasRestoredSession => _hasRestoredSession;

  /// Tinatawag isang beses sa `main()` bago ang `runApp`.
  ///
  /// Safe itong tawagin kahit walang naka-save na session — walang mangyayari.
  static Future<void> restore() async {
    try {
      final Map<String, dynamic>? saved =
          await SessionPersistence.instance.loadSession();

      if (saved == null) {
        _hasRestoredSession = false;
        return;
      }

      if (!UserSession.applyPersisted(saved)) {
        // Expired o invalid — huwag nang i-restore para hindi mag-stuck ang
        // customer sa lumang session.
        await SessionPersistence.instance.clear();
        _hasRestoredSession = false;
        return;
      }

      // Dine-in (QR) sessions can resume too. I-verify muna sa backend kung
      // bukas pa ang table session. Takeout (Google) sessions keep the
      // existing age-based restore dahil customer JWT ang hawak nila.
      if (!UserSession.isTakeout) {
        final bool stillActive = await _isDineInSessionStillActive();
        if (!stillActive) {
          // Closed/expired na ang mesa — huwag i-restore; mag-scan na lang
          // muli ng QR para makakuha ng bagong table session.
          UserSession.clearSession();
          _hasRestoredSession = false;
          return;
        }
      }

      await CustomerCartStore.restoreFromDisk();
      _hasRestoredSession = true;
      debugPrint(
        '✅ [SessionBootstrap] Restored session '
        '(takeout: ${UserSession.isTakeout}, '
        'table: ${UserSession.activeTableNumber ?? UserSession.activeTableId})',
      );
    } catch (error) {
      _hasRestoredSession = false;
      debugPrint('⚠️ [SessionBootstrap] restore failed: $error');
    }
  }

  /// `true` kapag bukas pa ('ACTIVE'/'OPEN') ang table session sa backend.
  ///
  /// Best-effort ito: kapag offline, timeout, o 5xx, hindi natin haharangin
  /// ang customer (ibabalik pa rin natin ang session). Sasaluhin naman ng
  /// backend validation sa oras ng order kung talagang sarado na ito.
  static Future<bool> _isDineInSessionStillActive() async {
    final int? sessionId = UserSession.activeSessionId ??
        int.tryParse(UserSession.sessionId ?? '');
    final String? token =
        UserSession.customerSessionToken ?? UserSession.authToken;

    if (sessionId == null ||
        sessionId <= 0 ||
        token == null ||
        token.isEmpty) {
      return false;
    }

    try {
      final http.Response response = await http
          .get(
            Uri.parse(
              '${ApiConfig.baseUrl}/api/v1/customer/sessions/$sessionId/orders-summary',
            ),
            headers: <String, String>{'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) return true;

      // 401/403 = expired/invalid token o inactive session (anggulo ng
      // `touchAuthenticatedSession`); 404 = wala nang session.
      if (response.statusCode == 401 ||
          response.statusCode == 403 ||
          response.statusCode == 404) {
        return false;
      }

      // 5xx/iba pa — huwag harangin ang customer.
      return true;
    } on TimeoutException {
      return true;
    } catch (error) {
      debugPrint(
        '⚠️ [SessionBootstrap] dine-in session validation failed: $error',
      );
      return true;
    }
  }
}
