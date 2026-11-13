import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../user_session.dart';

enum OrderingGateKind { allowed, billLocked, statusBlocked }

class OrderingGateResult {
  const OrderingGateResult(this.kind, {this.ticketStatus});

  final OrderingGateKind kind;
  final String? ticketStatus;

  bool get allowed => kind == OrderingGateKind.allowed;
  bool get isBillLocked => kind == OrderingGateKind.billLocked;
  bool get isStatusBlocked => kind == OrderingGateKind.statusBlocked;
}

/// Sentral na gate bago magdagdag ng items sa isang additional order.
///
/// Ginagamit ito ng `MenuScreen` para pareho ang rules sa Order Type Selection:
/// - bawal kapag naka-request na ang bill ng parent ticket
/// - bawal kapag PREPARING / READY / SERVED / PAID / COMPLETED / DONE na ito
class OrderingGate {
  OrderingGate._();

  /// Kapareho ng listahan sa `OrderTypeSelectionScreen`.
  static const Set<String> blockedAdditionalStatuses = <String>{
    'PREPARING',
    'READY',
    'SERVED',
    'PAID',
    'COMPLETED',
    'DONE',
  };

  static const Duration _cacheTtl = Duration(seconds: 3);
  static final Map<String, _GateCacheEntry> _cache =
      <String, _GateCacheEntry>{};

  static Future<OrderingGateResult> evaluate({
    required int tableId,
    required dynamic parentOrderId,
  }) async {
    if (parentOrderId == null) {
      return const OrderingGateResult(OrderingGateKind.allowed);
    }

    final String parent = parentOrderId.toString().trim();
    if (parent.isEmpty || parent == 'null') {
      return const OrderingGateResult(OrderingGateKind.allowed);
    }

    // Mabilis na local check bago pa mag-request sa backend.
    if (UserSession.isTicketBillRequested(parent)) {
      return const OrderingGateResult(OrderingGateKind.billLocked);
    }

    final String cacheKey = '$tableId|$parent';
    final _GateCacheEntry? cached = _cache[cacheKey];
    if (cached != null && DateTime.now().difference(cached.at) < _cacheTtl) {
      return cached.result;
    }

    OrderingGateResult result = const OrderingGateResult(
      OrderingGateKind.allowed,
    );

    try {
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/api/v1/orders/unfinished')
                .replace(queryParameters: <String, String>{
              'table_id': tableId.toString(),
            }),
            headers: UserSession.authHeaders,
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        final List<dynamic> orders = decoded is Map
            ? (decoded['orders'] ?? decoded['data'] ?? <dynamic>[])
                as List<dynamic>
            : <dynamic>[];

        bool foundParent = false;
        for (final dynamic raw in orders) {
          if (raw is! Map) continue;
          final dynamic rawId = raw['order_id'] ?? raw['id'];
          if (rawId == null || rawId.toString() != parent) continue;

          foundParent = true;
          final dynamic requestedAt = raw['bill_requested_at'];
          if (requestedAt != null) {
            UserSession.setTicketBillRequested(parent, requestedAt);
            result = const OrderingGateResult(OrderingGateKind.billLocked);
            break;
          }

          final String status =
              (raw['status'] ?? raw['order_status'] ?? '').toString().toUpperCase();
          if (blockedAdditionalStatuses.contains(status)) {
            result = OrderingGateResult(
              OrderingGateKind.statusBlocked,
              ticketStatus: status,
            );
          }
          break;
        }

        // Wala na sa "unfinished" list = malamang PAID/COMPLETED na — hindi na
        // dapat tanggap ng additional items. Ipaalam sa customer at hayaang
        // pumili kung brand-new order ang gusto.
        if (!foundParent) {
          result = const OrderingGateResult(
            OrderingGateKind.statusBlocked,
            ticketStatus: 'COMPLETED',
          );
        }
      }
    } catch (_) {
      // Best-effort: kung offline, huwag harangin ang customer. Sasaluhin ng
      // backend validation sa checkout kung may conflict.
    }

    _cache[cacheKey] = _GateCacheEntry(result, DateTime.now());
    return result;
  }

  /// Puwersahing i-refetch sa susunod na tsek (hal. pagkatapos mag-order).
  static void invalidate() => _cache.clear();
}

class _GateCacheEntry {
  const _GateCacheEntry(this.result, this.at);

  final OrderingGateResult result;
  final DateTime at;
}
