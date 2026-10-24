import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/admin_order_model.dart';
import '../../../config/api_config.dart';

class AdminService {
  final String _baseUrl = ApiConfig.baseUrl;
  static String? staffAuthToken;

  Map<String, String> get _authHeaders {
    final token = staffAuthToken;
    final Map<String, String> headers = {"Content-Type": "application/json"};
    if (token != null && token.isNotEmpty) {
      headers["Authorization"] = "Bearer $token";
    }
    return headers;
  }

  /// GET /api/v1/orders?all=true
  Future<List<AdminOrder>> fetchOrdersQueue({bool isApiConnected = false}) async {
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
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List list = decoded['data'] ?? [];
        return list.map((o) => AdminOrder.fromJson(o)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching orders queue from API: $e');
    }
    return [];
  }

  /// GET /api/v1/reports/daily-sales
  Future<DailySalesStats> fetchDailySalesAnalytics({bool isApiConnected = false}) async {
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
      final response = await http.get(
        Uri.parse('$_baseUrl/api/v1/reports/daily-sales'),
        headers: _authHeaders,
      );
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
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error updating order status via API: $e');
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
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error processing payment via API: $e');
    }
    return false;
  }
}
