import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../qr_scanner_screen.dart';
import '../user_session.dart';
import '../services/customer_navigation.dart';
import '../services/notification_center.dart';
import '../services/order_context.dart';
import '../services/audio_notification_service.dart';

/// Uri ng outcome na ipinapakita ng dialog.
enum OrderOutcome {
  /// Na-settle/paid na ang ticket.
  finished,

  /// Na-decline/cancel ng kitchen o admin ang ticket.
  declined,
}

/// Pop-up na lumalabas LANG kapag ang na-update na ticket ay:
/// - ang sariling order ng customer, o
/// - ang parent ticket ng additional order na ginagawa niya, o
/// - ang ticket na kasalukuyang tinitingnan niya.
///
/// Hindi ito gumagamit ng `UserSession.clearSession()` para hindi mabura ang
/// iba pang active tickets ng table — ang navigation ay via `OrderContext`
/// reset lang (non-destructive).
class FinishedOrderDialog {
  FinishedOrderDialog._();

  static bool _isShowing = false;

  /// Nagpapakita ng dialog. Bumabalik ng `true` kung aktwal na naipakita ito
  /// (para hindi maubos ang dedupe key kapag hindi pa ready ang navigator).
  static Future<bool> show({
    required String orderCode,
    required String orderId,
    OrderOutcome outcome = OrderOutcome.finished,
    String? reason,
    String? message,
    bool forceSessionFinished = false,
  }) async {
    if (_isShowing) return false;
    final BuildContext? rootContext =
        NotificationCenter.navigatorKey.currentContext;
    if (rootContext == null) return false;

    final bool isDeclined = outcome == OrderOutcome.declined;
    final String safeReason =
        (reason == null || reason.trim().isEmpty) ? 'Item Out of Stock' : reason.trim();

    _isShowing = true;
    try {
      // Kapag ang huling ticket na lang ang natapos (wala nang ibang active
      // order sa session), session-finished ang ipakita — hindi "Back to Menu".
      final bool sessionFinished = !isDeclined &&
          (forceSessionFinished || await _isSessionFinished(orderId));

      if (!rootContext.mounted) return false;

      final bool? goBack = await showDialog<bool>(
        context: rootContext,
        barrierDismissible: false,
        builder: (BuildContext ctx) => AlertDialog(
          backgroundColor: const Color(0xFFFFFDFA),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            isDeclined
                ? 'Order Declined'
                : sessionFinished
                    ? 'Session Finished'
                    : 'Finished Order',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDeclined
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF203F35),
            ),
          ),
          content: isDeclined
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message ??
                          'Pasensya na po, ang inyong order ($orderCode) ay na-decline ng kitchen/admin.',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF203F35),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Text(
                        'Reason: $safeReason',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF991B1B),
                        ),
                      ),
                    ),
                  ],
                )
              : Text(
                  sessionFinished
                      ? 'This table session is finished. Salamat sa paghain! '
                          'I-scan muli ang QR code ng table para magsimula ng bagong session.'
                      : message ??
                          'Na-settle na ang ticket $orderCode. Kailangan mo nang bumalik sa order choices para magpatuloy.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF203F35),
                    height: 1.4,
                  ),
                ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF203F35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                sessionFinished ? 'Scan QR Again' : 'Back to Menu',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );

      if (goBack == true) {
        if (sessionFinished) {
          _returnToQrScan();
        } else {
          _returnToOrderChoices(
            orderCode: orderCode,
            showSessionClosedBanner: !isDeclined,
          );
        }
      }
      return true;
    } finally {
      _isShowing = false;
    }
  }

  /// `true` kapag wala nang ibang active order sa session — ibig sabihin,
  /// ang katatapos lang na ticket ay ang huling order ng table.
  static Future<bool> _isSessionFinished(dynamic orderId) async {
    final int? tableId =
        UserSession.activeTableId ?? UserSession.activeTableNumber;
    final int? sessionId = UserSession.activeSessionId ??
        int.tryParse(UserSession.sessionId ?? '');
    if (tableId == null && sessionId == null) return false;

    try {
      final String query = <String>[
        if (tableId != null) 'table_id=$tableId',
        if (sessionId != null) 'session_id=$sessionId',
      ].join('&');
      final http.Response response = await http
          .get(
            Uri.parse(
              '${ApiConfig.baseUrl}/api/v1/customer/orders/live?$query',
            ),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) return false;

      final dynamic decoded = jsonDecode(response.body);
      final dynamic rawData = decoded is Map
          ? (decoded['data'] ?? decoded['orders'] ?? decoded)
          : decoded;
      final List<dynamic> orders =
          rawData is List ? rawData : const <dynamic>[];

      // Tanggalin sa count ang mismong katatapos na ticket — puwedeng nauna
      // pang bumalik ito sa live query bago mag-commit ang payment.
      final String finishedId = _normalizeOrderId(orderId);
      final bool hasOtherActiveOrder = orders.any((dynamic raw) {
        if (raw is! Map) return true;
        final String id = _normalizeOrderId(raw['order_id'] ?? raw['id']);
        if (finishedId.isNotEmpty && id == finishedId) return false;
        return true;
      });

      return !hasOtherActiveOrder;
    } catch (_) {
      return false;
    }
  }

  static String _normalizeOrderId(dynamic value) {
    return (value?.toString() ?? '').replaceAll(RegExp(r'[^0-9]'), '');
  }

  /// Session finished: i-clear ang lumang session at dalhin ang customer sa
  /// QR scanner para makapagsimula ng bagong table session.
  static void _returnToQrScan() {
    UserSession.clearSession();
    UserSession.clearAllBillRequests();
    UserSession.isAdditionalOrder = false;
    UserSession.targetParentOrderId = null;
    UserSession.lastPlacedOrderId = null;
    UserSession.firstOrderId = null;
    UserSession.autoAdditionalParentId = null;
    OrderContext.instance.reset();

    final BuildContext? rootContext =
        NotificationCenter.navigatorKey.currentContext;
    if (rootContext == null) return;

    Navigator.of(rootContext).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => const QrScannerScreen(),
      ),
      (route) => route.isFirst,
    );
  }

  static void _returnToOrderChoices({
    required String orderCode,
    bool showSessionClosedBanner = true,
  }) {
    if (showSessionClosedBanner) {
      // Ipinapakita ang session-closed notif (lalo na sa additional-order case
      // na naging parent ang na-finished na ticket) bago i-reset ang flags.
      AudioNotificationService.showSessionClosedBanner(
        orderCode: orderCode,
        orderId: UserSession.lastPlacedOrderId,
        tableId: UserSession.activeTableId ?? UserSession.activeTableNumber,
        sessionId: UserSession.activeSessionId ?? int.tryParse(UserSession.sessionId ?? ''),
      );
    }

    // ⚠️ Huwag i-clear ang buong session — may iba pang active tickets ang table.
    // I-reset lang ang additional-order context para ang susunod na order ay
    // malinis na bagong order, at hindi na mag-auto-additional sa finished
    // o declined ticket.
    UserSession.isAdditionalOrder = false;
    UserSession.targetParentOrderId = null;
    UserSession.autoAdditionalParentId = null;
    UserSession.lastPlacedOrderId = null;
    OrderContext.instance.reset();

    final int tableNumber =
        UserSession.activeTableId ?? UserSession.activeTableNumber ?? 7;
    final BuildContext? rootContext =
        NotificationCenter.navigatorKey.currentContext;
    if (rootContext == null) return;

    CustomerNavigation.openMenu(
      rootContext,
      tableId: tableNumber,
      tableNumber: tableNumber,
      isAdditionalOrder: false,
      resetOrderContext: true,
    );
  }
}
