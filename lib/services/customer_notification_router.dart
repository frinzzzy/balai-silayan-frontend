import 'dart:async';

import 'package:flutter/material.dart';

import '../order_status_screen.dart';
import '../user_session.dart';
import 'audio_notification_service.dart';
import 'customer_ticket_service.dart';
import 'notification_center.dart';
import 'notification_router.dart';

/// Customer-side routing para sa push notifications at in-app history taps.
///
/// Ang admin dashboard ang may sariling handler (`AdminDashboardScreen`). Dito
/// naman naka-map ang order notifications ng customer papunta sa ticket/status
/// screen: tap sa push (app background o killed) o sa in-app Notification
/// History → diretso sa `OrderStatusScreen` ng tamang order.
///
/// Fallback ang Notification History kapag:
/// - hindi order-related ang notification,
/// - wala pang active session (hal. bagong install / nag-expire na), o
/// - expired/invalid na ang session token kaya hindi ma-fetch ang tickets.
class CustomerNotificationRouter {
  CustomerNotificationRouter._();

  static bool _registered = false;
  static bool _routing = false;

  /// Mga push `type` na order-related. Pero kahit walang `type` (lumang
  /// backend payload), basta may `order_id`, order pa rin ang ituturing.
  static const Set<String> _orderTypes = <String>{
    'new_order',
    'additional_order',
    'order_status',
    'order_update',
    'order',
    'bill_requested',
  };

  /// I-register ang customer handler sa [NotificationRouter]. Idempotent —
  /// siguraduhing natawag pagkatapos ng `SessionBootstrap.restore()` para
  /// tama agad ang session na magagamit sa pag-fetch ng tickets.
  static void register() {
    if (_registered) return;
    _registered = true;
    NotificationRouter.registerHandler(_handle);
  }

  static void _handle(Map<String, dynamic> data) {
    unawaited(_route(data));
  }

  static Future<void> _route(Map<String, dynamic> data) async {
    if (_routing) return;

    final String type = (data['type'] ?? '').toString().toLowerCase();
    final int? orderId = int.tryParse(
      (data['order_id'] ?? data['id'] ?? '').toString(),
    );
    final bool isOrderNotification =
        orderId != null && (type.isEmpty || _orderTypes.contains(type));

    if (!isOrderNotification) {
      await AudioNotificationService.openNotificationHistoryFromPush();
      return;
    }

    _routing = true;
    try {
      final NavigatorState? navigator = await _waitForNavigator();
      if (navigator == null) return;

      // Walang session (bagong install o na-clear): huwag munang buksan ang
      // ticket — nasa Notification History pa rin ang detalye.
      if (!UserSession.hasActiveSession) {
        await AudioNotificationService.openNotificationHistoryFromPush();
        return;
      }

      Map<dynamic, dynamic>? ticket;
      try {
        final List<dynamic> tickets =
            await CustomerTicketService.fetchRecentTickets();
        for (final dynamic raw in tickets) {
          if (raw is! Map) continue;
          final dynamic id = raw['id'] ?? raw['order_id'];
          if (id?.toString() == orderId.toString()) {
            ticket = raw;
            break;
          }
        }
      } catch (_) {
        // Expired/invalid session — history ang fallback para hindi mawala
        // ang context ng notification.
        await AudioNotificationService.openNotificationHistoryFromPush();
        return;
      }

      final Map<dynamic, dynamic>? matched = ticket;
      final dynamic resolvedId = matched?['id'] ?? matched?['order_id'] ?? orderId;
      final double totalAmount =
          double.tryParse(matched?['total_amount']?.toString() ?? '0') ?? 0.0;
      final dynamic rawItems = matched?['items'];
      final List<dynamic> items =
          rawItems is List ? List<dynamic>.from(rawItems) : <dynamic>[];
      final bool isAdditional = matched != null &&
          (matched['is_additional_order'] == true ||
              matched['parent_order_id'] != null ||
              matched['order_type']?.toString().toUpperCase() == 'ADDITIONAL');

      // Huwag i-await ang route lifetime — hindi dapat ma-block ang susunod
      // na notification/tap habang bukas pa ang ticket screen.
      unawaited(
        navigator.push<void>(
          MaterialPageRoute<void>(
            builder: (_) => OrderStatusScreen(
              orderId: resolvedId,
              isTakeout: UserSession.isTakeout,
              tableId: UserSession.activeTableId,
              totalAmount: totalAmount,
              isAdditionalOrder: isAdditional,
              initialOrderItems: items.isEmpty ? null : items,
              initialNotes: (matched?['notes'] ?? '').toString(),
            ),
          ),
        ),
      );
    } finally {
      _routing = false;
    }
  }

  /// Hintayin ang root navigator (cold start / killed app) bago mag-navigate.
  static Future<NavigatorState?> _waitForNavigator() async {
    NavigatorState? navigator = NotificationCenter.navigatorKey.currentState;
    for (int attempt = 0; attempt < 20 && navigator == null; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      navigator = NotificationCenter.navigatorKey.currentState;
    }
    return navigator;
  }
}
