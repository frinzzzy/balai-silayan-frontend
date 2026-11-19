import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/admin_order_model.dart';
import '../models/staff_user_model.dart';
import '../../../config/api_config.dart';

class AdminService {
  final String _baseUrl = ApiConfig.baseUrl;
  static String? staffAuthToken;
  static String? staffName;

  /// Huling error message mula sa status update (hal. checklist not finished).
  /// Ipinapakita ito sa snackbar para malinaw sa staff kung bakit na-block.
  static String? lastOrderStatusError;

  /// Ang naka-login na staff account (galing sa `/auth/login` o `/auth/me`).
  /// Ito ang source of truth para sa role-based UI.
  static StaffUser? currentUser;

  static bool get isAdmin => currentUser?.role == 'ADMIN';

  Map<String, String> get _authHeaders {
    final token = staffAuthToken;
    final Map<String, String> headers = {"Content-Type": "application/json"};
    if (token != null && token.isNotEmpty) {
      headers["Authorization"] = "Bearer $token";
    }
    return headers;
  }

  /// GET /api/v1/orders?all=true
  /// Returns `null` kapag bigo ang fetch (timeout, cold start, non-200) para
  /// hindi mapagkamalang "empty queue" at hindi mag-trigger ng maling seeding.
  Future<List<AdminOrder>?> fetchOrdersQueue({bool isApiConnected = false}) async {
    if (!isApiConnected) {
      await Future.delayed(const Duration(milliseconds: 300));
      return [
        AdminOrder(
          id: 101,
          tableNumber: 7,
          itemsDescription: "2x Bihon, 1x Chopsuey",
          totalAmount: 420.00,
          status: "PENDING",
          paymentMethod: "UNPAID",
          updatedAt: "12:15 PM • Today",
        ),
        AdminOrder(
          id: 102,
          tableNumber: 3,
          itemsDescription: "1x Crispy Pata, 3x Iced Tea",
          totalAmount: 850.00,
          status: "PREPARING",
          paymentMethod: "UNPAID",
          updatedAt: "12:20 PM • Today",
        ),
      ];
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/v1/orders?all=true'),
        headers: _authHeaders,
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List list = decoded['data'] ?? [];
        return list.map((o) => AdminOrder.fromJson(o)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching orders queue from API: $e');
    }
    return null;
  }

  /// GET /api/v1/reports/daily-sales
  Future<DailySalesStats> fetchDailySalesAnalytics({bool isApiConnected = false, String period = 'today', String? startDate, String? endDate}) async {
    if (!isApiConnected) {
      await Future.delayed(const Duration(milliseconds: 200));
      return DailySalesStats(
        totalSales: 84240.00,
        totalTransactions: 72,
        cashSales: 35100.00,
        gcashSales: 49140.00,
      );
    }

    try {
      String url = '$_baseUrl/api/v1/reports/daily-sales?period=$period';
      if (startDate != null && endDate != null) {
        url += '&start_date=$startDate&end_date=$endDate';
      }
      final response = await http.get(
        Uri.parse(url),
        headers: _authHeaders,
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final data = decoded['data'] ?? decoded;
        return DailySalesStats.fromJson(data);
      }
    } catch (e) {
      debugPrint('Error fetching daily sales from API: $e');
    }
    return DailySalesStats(totalSales: 0.0, totalTransactions: 0, cashSales: 0.0, gcashSales: 0.0);
  }

  Future<Map<String, dynamic>> fetchSalesAnalyticsWithBreakdown({String period = 'today', String? startDate, String? endDate}) async {
    try {
      String url = '$_baseUrl/api/v1/reports/daily-sales?period=$period';
      if (startDate != null && endDate != null) {
        url += '&start_date=$startDate&end_date=$endDate';
      }
      final response = await http.get(
        Uri.parse(url),
        headers: _authHeaders,
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final data = decoded['data'] ?? decoded;
        final stats = DailySalesStats.fromJson(data);

        // ✅ Tinitiyak na nasasalo ang chart breakdown mula sa API response[cite: 18]
        final List breakdown = data['chart_breakdown'] ?? data['breakdown'] ?? [];

        // Top-selling dishes based on actual paid/completed order items[cite: 18]
        final List topItemsRaw = (data['top_items'] ?? data['top_dishes'] ?? data['top_selling_items'] ?? data['best_sellers'] ?? data['top_menu_items'] ?? []) as List? ?? [];
        final List<TopDishItem> topDishes = topItemsRaw
            .whereType<Map>()
            .map((e) => TopDishItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();

        return {
          'stats': stats,
          'breakdown': breakdown,
          'top_items': topDishes,
        };
      }
    } catch (e) {
      debugPrint('Error fetching sales breakdown: $e');
    }
    return {
      'stats': DailySalesStats(totalSales: 0.0, totalTransactions: 0, cashSales: 0.0, gcashSales: 0.0),
      'breakdown': [],
      'top_items': <TopDishItem>[],
    };
  }

  /// Legal na status transitions ng order (mirror ng backend `ORDER_STATUS_FLOW`
  /// sa `orderService.js`). Pinapapagana lamang ito ang valid na next status.
  static bool isValidStatusTransition(String fromStatus, String toStatus) {
    final String from = fromStatus.trim().toUpperCase();
    final String to = toStatus.trim().toUpperCase();
    switch (from) {
      case 'PENDING':
      case 'NEW':
        return to == 'PREPARING' || to == 'DECLINED';
      case 'PREPARING':
        return to == 'READY' || to == 'DECLINED';
      case 'READY':
        return to == 'SERVED' || to == 'DECLINED';
      case 'SERVED':
        return to == 'PAID' || to == 'COMPLETED' || to == 'DECLINED';
      default:
        return false;
    }
  }

  /// ADMIN / WAITER / KITCHEN lang ang may sakop sa status updates
  /// (katulad ng backend route guard sa `/api/v1/orders/:id/status`).
  static bool canUpdateOrderStatus(String fromStatus, String toStatus, {String? role}) {
    if (!isValidStatusTransition(fromStatus, toStatus)) return false;
    final String normalizedRole = (role ?? '').trim().toUpperCase();
    return normalizedRole == 'ADMIN' ||
        normalizedRole == 'WAITER' ||
        normalizedRole == 'KITCHEN';
  }

  /// ADMIN / CASHIER lang ang may sakop sa payment processing.
  /// (Cashier ang pangunahing nag-aayos ng bayad; admin ang nagdadala ng
  /// contingency — hindi allowed ang waiter sa payment processing.)
  static bool canProcessPayment(String status, {String? role}) {
    final String normalizedRole = (role ?? '').trim().toUpperCase();
    final bool roleAllowed = normalizedRole == 'ADMIN' ||
        normalizedRole == 'CASHIER';
    if (!roleAllowed) return false;
    // Ang payment ay para sa orders na may outstanding balance; sa queue UI,
    // nakikita natin ang pay actions para sa SERVED na UNPAID orders.
    return status.trim().toUpperCase() == 'SERVED';
  }

  /// ADMIN / WAITER / KITCHEN lang ang pwedeng mag-check ng bawat order item.
  static bool canCheckOrderItems({String? role}) {
    final String normalizedRole = (role ?? '').trim().toUpperCase();
    return normalizedRole == 'ADMIN' ||
        normalizedRole == 'WAITER' ||
        normalizedRole == 'KITCHEN';
  }

  /// PATCH /api/v1/orders/:order_id/items/:item_id/check
  /// I-toggle ang checklist ng isang order item (kitchen marks done).
  Future<bool> setOrderItemChecked({
    required int orderId,
    required int itemId,
    required bool checked,
    bool isApiConnected = true,
  }) async {
    if (!isApiConnected) {
      await Future.delayed(const Duration(milliseconds: 120));
      return true;
    }

    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/api/v1/orders/$orderId/items/$itemId/check'),
        headers: _authHeaders,
        body: jsonEncode({"checked": checked}),
      ).timeout(const Duration(seconds: 15));
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error updating order item checklist via API: $e');
    }
    return false;
  }

  /// PATCH /api/v1/orders/:id/status
  Future<bool> updateOrderStatus({
    required int orderId,
    required String status,
    required String paymentMethod,
    String? declineReason,
    bool isApiConnected = false,
  }) async {
    if (!isApiConnected) {
      await Future.delayed(const Duration(milliseconds: 150));
      return true;
    }

    try {
      final Map<String, dynamic> body = {
        "status": status.toUpperCase(),
      };
      if (declineReason != null && declineReason.isNotEmpty) {
        body["decline_reason"] = declineReason;
      }

      final response = await http.patch(
        Uri.parse('$_baseUrl/api/v1/orders/$orderId/status'),
        headers: _authHeaders,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        lastOrderStatusError = null;
        return true;
      }

      try {
        final dynamic decoded = jsonDecode(response.body);
        lastOrderStatusError = decoded is Map
            ? (decoded['message'] ?? decoded['error'])?.toString()
            : null;
      } catch (_) {
        lastOrderStatusError = null;
      }
      return false;
    } catch (e) {
      debugPrint('Error updating order status via API: $e');
      lastOrderStatusError = 'Connection error. Please try again.';
    }
    return false;
  }

  /// POST /api/v1/orders/:id/bill/reopen
  /// Binubuksan muli ang ordering para sa isang ticket na nag-request na ng bill.
  Future<bool> reopenOrderBill({
    required int orderId,
    bool isApiConnected = false,
  }) async {
    if (!isApiConnected) {
      await Future.delayed(const Duration(milliseconds: 150));
      return true;
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/orders/$orderId/bill/reopen'),
        headers: _authHeaders,
        body: jsonEncode(<String, dynamic>{}),
      ).timeout(const Duration(seconds: 15));
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error reopening order bill via API: $e');
    }
    return false;
  }

  /// POST /api/v1/orders/:id/pay
  Future<bool> processPayment({
    required int orderId,
    required String paymentMethod,
    required double amountPaid,
    bool isApiConnected = false,
  }) async {
    if (!isApiConnected) {
      await Future.delayed(const Duration(milliseconds: 150));
      return true;
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/orders/$orderId/pay'),
        headers: _authHeaders,
        body: jsonEncode({
          "payment_method": paymentMethod.toUpperCase(),
          "amount_paid": amountPaid > 0 ? amountPaid : 1000.0,
          "discount_type": "NONE"
        }),
      ).timeout(const Duration(seconds: 30));
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error processing payment via API: $e');
    }
    return false;
  }

  /// GET /api/v1/menu
  Future<List<Map<String, dynamic>>> fetchMenuInventory() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/v1/menu'),
        headers: _authHeaders,
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List list = decoded['data'] ?? decoded['items'] ?? [];
        return list.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching menu inventory: $e');
    }
    return [];
  }

  /// GET /api/v1/categories
  /// Ginagamit para makuha ang totoong menu categories ng DB (parehong source
  /// ng customer menu) para hindi hardcoded ang category filters.
  Future<List<Map<String, dynamic>>> fetchMenuCategories() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/v1/categories'),
        headers: _authHeaders,
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List list = decoded['data'] ?? decoded['categories'] ?? [];
        return list.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching menu categories: $e');
    }
    return [];
  }

  /// PATCH /api/v1/menu/:id/stock
  Future<bool> updateItemStock({required int itemId, required int stockQuantity, String adjustmentType = 'RESTOCK'}) async {
    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/api/v1/menu/$itemId/stock'),
        headers: _authHeaders,
        body: jsonEncode({
          "stock_quantity": stockQuantity,
          "adjustment_type": adjustmentType,
        }),
      ).timeout(const Duration(seconds: 15));
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error updating item stock: $e');
    }
    return false;
  }
}