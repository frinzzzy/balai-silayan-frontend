import 'package:flutter/material.dart';

import '../order_type_selection_screen.dart';
import '../user_session.dart';
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
      final bool? goBack = await showDialog<bool>(
        context: rootContext,
        barrierDismissible: false,
        builder: (BuildContext ctx) => AlertDialog(
          backgroundColor: const Color(0xFFFFFDFA),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            isDeclined ? 'Order Declined' : 'Finished Order',
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
                  message ??
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
              child: const Text(
                'Back to Menu',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );

      if (goBack == true) {
        _returnToOrderChoices(
          orderCode: orderCode,
          showSessionClosedBanner: !isDeclined,
        );
      }
      return true;
    } finally {
      _isShowing = false;
    }
  }

  static void _returnToOrderChoices({
    required String orderCode,
    bool showSessionClosedBanner = true,
  }) {
    // ⚠️ Huwag i-clear ang buong session — may iba pang active tickets ang table.
    UserSession.isAdditionalOrder = false;
    UserSession.targetParentOrderId = null;
    OrderContext.instance.reset();

    if (showSessionClosedBanner) {
      // Ipinapakita ang session-closed notif (lalo na sa additional-order case
      // na naging parent ang na-finished na ticket) bago bumalik sa order choices.
      AudioNotificationService.showSessionClosedBanner(
        orderCode: orderCode,
        orderId: UserSession.lastPlacedOrderId,
        tableId: UserSession.activeTableId ?? UserSession.activeTableNumber,
        sessionId: UserSession.activeSessionId ?? int.tryParse(UserSession.sessionId ?? ''),
      );
    }

    final int tableNumber =
        UserSession.activeTableId ?? UserSession.activeTableNumber ?? 7;
    final NavigatorState? navigator = NotificationCenter.navigatorKey.currentState;
    if (navigator == null) return;

    // `(route) => false` — bumalik sa OrderTypeSelectionScreen (walang luma na
    // na-navigate mula sa OrderStatusScreen).
    navigator.pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => OrderTypeSelectionScreen(
          tableId: tableNumber,
          tableNumber: tableNumber,
        ),
      ),
      (route) => false,
    );
  }
}
