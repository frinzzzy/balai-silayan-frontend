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
    // Huwag i-cache ang "hindi natin alam" (offline/5xx/stale auth): baka
    // maipit ang customer sa maling decision sa loob ng TTL.
    bool cacheable = false;

    try {
      final response = await _getWithAuthFallback(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/orders/unfinished')
            .replace(queryParameters: <String, String>{
          'table_id': tableId.toString(),
        }),
      );

      if (response.statusCode == 200) {
        cacheable = true;
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

        if (!foundParent) {
          // Wala sa "unfinished" list — posibleng settled na, pero posibleng
          // race lang ng list endpoint. I-verify muna by ID bago mag-block.
          final OrderingGateResult? byId = await _evaluateByOrderId(parent);
          if (byId != null) {
            result = byId;
          } else {
            // Hindi natin kayang i-confirm — huwag harangin at huwag i-cache.
            // Sasaluhin ng backend validation sa checkout.
            cacheable = false;
            result = const OrderingGateResult(OrderingGateKind.allowed);
          }
        }
      }
    } catch (_) {
      // Best-effort: kung offline, huwag harangin ang customer. Sasaluhin ng
      // backend validation sa checkout kung may conflict.
      cacheable = false;
    }

    if (cacheable) {
      _cache[cacheKey] = _GateCacheEntry(result, DateTime.now());
    }
    return result;
  }

  /// GET na may auth, pero kapag expired/401 ang token ay susubukan ulit nang
  /// walang auth header (public endpoints) bago sumuko.
  static Future<http.Response> _getWithAuthFallback(Uri uri) async {
    final http.Response response = await http
        .get(uri, headers: UserSession.authHeaders)
        .timeout(const Duration(seconds: 8));
    if (response.statusCode == 401 || response.statusCode == 403) {
      return http
          .get(uri)
          .timeout(const Duration(seconds: 8));
    }
    return response;
  }

  /// Kunin ang final status ng order by ID. `null` kapag hindi ma-confirm
  /// (offline, 5xx, o walang valid response) — huwag mag-assume ng COMPLETED.
  static Future<OrderingGateResult?> _evaluateByOrderId(String parent) async {
    try {
      final http.Response response = await _getWithAuthFallback(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/orders/$parent'),
      );
      if (response.statusCode == 404) {
        // Talagang wala na ang order — settled/cancelled na ito.
        return const OrderingGateResult(
          OrderingGateKind.statusBlocked,
          ticketStatus: 'COMPLETED',
        );
      }
      if (response.statusCode != 200) return null;

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      dynamic raw = decoded['data'] is Map ? decoded['data'] : decoded;
      if (raw is Map && raw['order'] is Map) raw = raw['order'];
      if (raw is! Map) return null;

      final dynamic requestedAt = raw['bill_requested_at'];
      if (requestedAt != null) {
        UserSession.setTicketBillRequested(parent, requestedAt);
        return const OrderingGateResult(OrderingGateKind.billLocked);
      }

      final String status =
          (raw['order_status'] ?? raw['status'] ?? '').toString().toUpperCase();
      if (blockedAdditionalStatuses.contains(status)) {
        return OrderingGateResult(
          OrderingGateKind.statusBlocked,
          ticketStatus: status,
        );
      }
      return const OrderingGateResult(OrderingGateKind.allowed);
    } catch (_) {
      return null;
    }
  }

  /// Puwersahing i-refetch sa susunod na tsek (hal. pagkatapos mag-order).
  static void invalidate() => _cache.clear();
}

class _GateCacheEntry {
  const _GateCacheEntry(this.result, this.at);

  final OrderingGateResult result;
  final DateTime at;
}
