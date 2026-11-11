import 'package:flutter/material.dart';

import '../order_type_selection_screen.dart';
import '../user_session.dart';
import '../services/notification_center.dart';
import '../services/order_context.dart';
import '../services/audio_notification_service.dart';

/// Pop-up na lumalabas LANG kapag ang na-finish na ticket ay:
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

  static Future<void> show({
    required String orderCode,
    required String orderId,
    String? message,
  }) async {
    if (_isShowing) return;
    final BuildContext? rootContext =
        NotificationCenter.navigatorKey.currentContext;
    if (rootContext == null) return;

    _isShowing = true;
    final bool? goBack = await showDialog<bool>(
      context: rootContext,
      barrierDismissible: false,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFFDFA),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Finished Order',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF203F35),
          ),
        ),
        content: Text(
          message ??
              'Na-settle na ang ticket $orderCode. Kailangan mo nang bumalik sa order choices para magpatuloy.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF203F35), height: 1.4),
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
      _returnToOrderChoices(orderCode: orderCode);
    }
    _isShowing = false;
  }

  static void _returnToOrderChoices({required String orderCode}) {
    // ⚠️ Huwag i-clear ang buong session — may iba pang active tickets ang table.
    UserSession.isAdditionalOrder = false;
    UserSession.targetParentOrderId = null;
    OrderContext.instance.reset();

    // Ipinapakita ang session-closed notif (lalo na sa additional-order case
    // na naging parent ang na-finish na ticket) bago bumalik sa order choices.
    AudioNotificationService.showSessionClosedBanner(
      orderCode: orderCode,
      orderId: UserSession.lastPlacedOrderId,
      tableId: UserSession.activeTableId ?? UserSession.activeTableNumber,
      sessionId: UserSession.activeSessionId ?? int.tryParse(UserSession.sessionId ?? ''),
    );

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
