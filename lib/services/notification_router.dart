import 'dart:convert';

import 'audio_notification_service.dart';

/// Sentral na pagdedesisyon kung saan pupunta kapag tinap ang isang notification.
///
/// Nagre-register ng [handler] ang admin dashboard (staff destinations) at ang
/// customer app (`CustomerNotificationRouter` → ticket). Kapag wala pang handler
/// (hal. cold start bago mag-register), Notification History ang fallback —
/// hindi nawawala ang notification.
class NotificationRouter {
  NotificationRouter._();

  static void Function(Map<String, dynamic> data)? handler;

  /// Pending na notification mula sa cold start (`getInitialMessage`).
  /// Ise-store hangga't hindi pa nare-register ang handler (admin login).
  static Map<String, dynamic>? pendingData;

  static void handle(Map<String, dynamic> data) {
    final Function(Map<String, dynamic> data)? h = handler;
    if (h == null) {
      pendingData = data;
      AudioNotificationService.openNotificationHistoryFromPush();
      return;
    }
    h(data);
  }

  /// Tinatawag kapag tinap ang isang entry sa IN-APP Notification History.
  /// Kung wala pang handler, WALANG ginagawa — huwag muling buksan ang history
  /// dahil nandoon na tayo (iwasang mag-loop).
  static void handleFromHistory(Map<String, dynamic> data) {
    final Function(Map<String, dynamic> data)? h = handler;
    if (h == null) return;
    h(data);
  }

  /// Tinatawag pagkatapos mag-login ang admin. Kung may pending na notif mula
  /// sa cold start, isasagawa na ang tamang destination.
  static void registerHandler(
    void Function(Map<String, dynamic> data) newHandler,
  ) {
    handler = newHandler;
    final Map<String, dynamic>? pending = pendingData;
    if (pending == null) return;
    pendingData = null;
    newHandler(pending);
  }

  /// I-parse ang payload ng local notification. JSON map = FCM data payload;
  /// kung hindi, ituring na order id at buksan ang history.
  static void handlePayload(String? payload) {
    if (payload == null || payload.trim().isEmpty) {
      AudioNotificationService.openNotificationHistoryFromPush();
      return;
    }
    try {
      final dynamic decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        handle(decoded);
        return;
      }
      handle(<String, dynamic>{'order_id': decoded.toString()});
    } catch (_) {
      handle(<String, dynamic>{'order_id': payload});
    }
  }
}
