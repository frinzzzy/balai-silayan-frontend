import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/admin_order_model.dart';

class AdminService {
  final String _baseUrl = 'http://localhost:5000';

  /// GET /api/v1/orders?all=true
  Future<List<AdminOrder>> fetchOrdersQueue({bool isApiConnected = false}) async {
    if (!isApiConnected) {
      // Return Mock Data Queue
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
        AdminOrder(
          id: 103,
          tableNumber: 12,
          itemsDescription: "1x Kare-Kare, 2x Plain Rice",
          totalAmount: 510.00,
          status: "SERVED",
          paymentMethod: "UNPAID",
          updatedAt: "12:28 PM • Today",
        ),
        AdminOrder(
          id: 104,
          tableNumber: 5,
          itemsDescription: "1x Halo-Halo, 2x Carbonara",
          totalAmount: 370.00,
          status: "PAID",
          paymentMethod: "GCASH",
          updatedAt: "12:35 PM • Today",
        ),
      ];
    }

    try {
      /*
      TODO: Implement REST API call to fetch live orders queue
      Endpoint: GET /api/v1/orders?all=true
      Headers: { "Authorization": "Bearer <staff_token>" }
      */
      final response = await http.get(Uri.parse('$_baseUrl/api/v1/orders?all=true'));
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
      // Return Mock Daily Sales KPI Stats
      await Future.delayed(const Duration(milliseconds: 200));
      return DailySalesStats(
        totalSales: 84240.00,
        totalTransactions: 72,
        cashSales: 35100.00,
        gcashSales: 49140.00,
      );
    }

    try {
      /*
      TODO: Implement REST API call to fetch daily sales analytics
      Endpoint: GET /api/v1/reports/daily-sales
      Headers: { "Authorization": "Bearer <staff_token>" }
      */
      final response = await http.get(Uri.parse('$_baseUrl/api/v1/reports/daily-sales'));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final data = decoded['data'] ?? decoded;
        return DailySalesStats.fromJson(data);
      }
    } catch (e) {
      debugPrint('Error fetching daily sales from API: $e');
    }
    return DailySalesStats(totalSales: 84240.0, totalTransactions: 72, cashSales: 35100.0, gcashSales: 49140.0);
  }

  /// PATCH /api/v1/orders/:id/status
  Future<bool> updateOrderStatus({
    required int orderId,
    required String status,
    required String paymentMethod,
    bool isApiConnected = false,
  }) async {
    if (!isApiConnected) {
      await Future.delayed(const Duration(milliseconds: 150));
      return true;
    }

    try {
      /*
      TODO: Implement PATCH request to update order status and payment method
      Endpoint: PATCH /api/v1/orders/:id/status
      Payload: { "status": status, "payment_method": paymentMethod, "updated_at": DateTime.now().toIso8601String() }
      */
      final response = await http.patch(
        Uri.parse('$_baseUrl/api/v1/orders/$orderId/status'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "status": status,
          "payment_method": paymentMethod,
          "updated_at": DateTime.now().toIso8601String(),
        }),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error updating order status via API: $e');
    }
    return false;
  }
}
