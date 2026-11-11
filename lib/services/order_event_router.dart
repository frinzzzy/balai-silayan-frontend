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
/// 2. Mag-pop-up ng "Finished Order" LANG kung ang na-finish na ticket ay
///    konektado sa kasalukuyang ginagawa/tinitingnan ng customer.
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
    if (_terminalStatuses.contains(normalized)) {
      if (OrderContext.instance.isTicketRelevant(
        orderId,
        eventParentOrderId: parentOrderId,
      )) {
        _maybeShowFinishedDialog(displayCode, orderId);
      }
    }

    // 3. Refresh broadcast.
    OrderEventBus.instance.notifyRefresh();
  }

  void _maybeShowFinishedDialog(String orderCode, dynamic orderId) {
    final String key = 'finished_dialog|${_normalizeId(orderId)}';
    // Isang beses lang per ticket sa loob ng 30 minuto.
    if (!NotificationCenter.instance.shouldNotify(
      key,
      ttl: const Duration(minutes: 30),
    )) {
      return;
    }

    FinishedOrderDialog.show(
      orderCode: orderCode,
      orderId: _normalizeId(orderId),
    );
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
