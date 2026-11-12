import 'dart:async';

import 'package:flutter/foundation.dart';

import '../user_session.dart';
import '../widgets/finished_order_dialog.dart';
import 'audio_notification_service.dart';
import 'notification_center.dart';
import 'order_context.dart';
import 'order_event_bus.dart';

/// Sentral na policy para sa lahat ng order events — socket man o polling.
///
/// Responsibility:
/// 1. Palaging mag-banner (table/session scoped na ang filtering bago pa
///    makarating dito).
/// 2. Mag-pop-up ng "Finished Order" o "Order Declined" LANG kung ang
///    na-update na ticket ay konektado sa kasalukuyang ginagawa/tinitingnan
///    ng customer.
/// 3. I-broadcast ang refresh sa mga screen (walang single handler slot).
class OrderEventRouter {
  OrderEventRouter._();

  static final OrderEventRouter instance = OrderEventRouter._();

  static const Set<String> _terminalStatuses = <String>{
    'COMPLETED',
    'PAID',
    'CLOSED',
    'SETTLED',
  };

  static const Set<String> _declinedStatuses = <String>{
    'DECLINED',
    'REJECTED',
    'CANCELLED',
  };

  /// Mula sa socket payload.
  void onOrderEvent({
    required Map<String, dynamic> orderPayload,
    required Map<String, dynamic> payload,
    String eventType = 'status',
  }) {
    final String status = _pickString(<dynamic>[
      orderPayload['status'],
      orderPayload['order_status'],
      payload['status'],
      payload['order_status'],
    ]);

    final dynamic orderId = orderPayload['order_id'] ??
        orderPayload['id'] ??
        payload['order_id'] ??
        payload['id'];
    final dynamic parentOrderId =
        orderPayload['parent_order_id'] ?? payload['parent_order_id'];
    final String reason = _pickString(<dynamic>[
      orderPayload['decline_reason'],
      orderPayload['reason'],
      payload['decline_reason'],
      payload['reason'],
    ]);
    final String orderCode = _pickString(<dynamic>[
      orderPayload['order_code'],
      payload['order_code'],
    ]);

    _publish(
      status: status,
      orderId: orderId,
      parentOrderId: parentOrderId,
      orderCode: orderCode,
      reason: reason,
      eventType: eventType,
    );
  }

  /// Mula sa polling/HTTP detection (walang socket).
  void onStatusObserved({
    required String status,
    required dynamic orderId,
    String? orderCode,
    String? reason,
    dynamic parentOrderId,
    String eventType = 'poll',
  }) {
    _publish(
      status: status,
      orderId: orderId,
      parentOrderId: parentOrderId,
      orderCode: orderCode ?? '',
      reason: reason ?? '',
      eventType: eventType,
    );
  }

  /// Kapag pumasok ang customer sa additional-order flow, i-reset ang popup
  /// dedupe ng parent at ng sariling order para hindi barado ng lumang key
  /// ang susunod na update (hal. kapag nag-test ulit sa parehong ticket).
  void resetPopupDedupe(dynamic orderId) {
    final String id = _normalizeId(orderId);
    if (id.isEmpty) return;
    NotificationCenter.instance.forget('finished_dialog|$id');
    NotificationCenter.instance.forget('declined_dialog|$id');
  }

  void _publish({
    required String status,
    required dynamic orderId,
    required dynamic parentOrderId,
    required String orderCode,
    required String reason,
    required String eventType,
  }) {
    final String normalized = status.trim().toUpperCase();
    if (normalized.isEmpty) return;

    final String displayCode = orderCode.trim().isNotEmpty
        ? orderCode.trim()
        : UserSession.formatOrderCode(orderId);

    // 1. Banner — laging ipapakita (dedupe ang bahala sa doble).
    try {
      AudioNotificationService.showOrderStatusBanner(
        status: normalized,
        orderCode: displayCode,
        orderId: orderId,
        reason: reason,
        eventType: eventType,
      );
    } catch (e) {
      debugPrint('⚠️ [OrderEventRouter] banner error: $e');
    }

    // 2. Pop-up policy — tanging para sa konektadong ticket.
    final bool isRelevant = OrderContext.instance.isTicketRelevant(
      orderId,
      eventParentOrderId: parentOrderId,
    );

    if (isRelevant && _terminalStatuses.contains(normalized)) {
      unawaited(_maybeShowOutcomeDialog(
        orderCode: displayCode,
        orderId: orderId,
        outcome: OrderOutcome.finished,
        reason: reason,
      ));
    } else if (isRelevant && _declinedStatuses.contains(normalized)) {
      unawaited(_maybeShowOutcomeDialog(
        orderCode: displayCode,
        orderId: orderId,
        outcome: OrderOutcome.declined,
        reason: reason,
      ));
    }

    // 3. Refresh broadcast.
    OrderEventBus.instance.notifyRefresh();
  }

  Future<void> _maybeShowOutcomeDialog({
    required String orderCode,
    required dynamic orderId,
    required OrderOutcome outcome,
    required String reason,
  }) async {
    final String normalizedId = _normalizeId(orderId);
    final bool isDeclined = outcome == OrderOutcome.declined;
    final String key = isDeclined
        ? 'declined_dialog|$normalizedId'
        : 'finished_dialog|$normalizedId';
    final Duration ttl = isDeclined
        ? const Duration(minutes: 2)
        : const Duration(minutes: 30);

    if (!NotificationCenter.instance.shouldNotify(key, ttl: ttl)) {
      return;
    }

    final bool shown = await FinishedOrderDialog.show(
      orderCode: orderCode,
      orderId: normalizedId,
      outcome: outcome,
      reason: reason,
    );

    // Kung hindi pa ready ang navigator/dialog, huwag sayangin ang dedupe key
    // para may chance pang lumabas sa susunod na event/poll.
    if (!shown) NotificationCenter.instance.forget(key);
  }

  String _normalizeId(dynamic id) {
    final String raw = id?.toString().trim() ?? '';
    final String stripped =
        raw.replaceAll(RegExp(r'^#?BS-?', caseSensitive: false), '').trim();
    final int? numeric = int.tryParse(stripped);
    return numeric?.toString() ?? stripped.toUpperCase();
  }

  String _pickString(List<dynamic> values) {
    for (final dynamic value in values) {
      if (value == null) continue;
      final String text = value.toString().trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return '';
  }
}
