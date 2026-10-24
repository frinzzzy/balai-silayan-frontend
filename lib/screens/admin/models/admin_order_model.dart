class AdminOrder {
  final int id;
  final int tableNumber;
  final String itemsDescription;
  final double totalAmount;
  String status; // PENDING, PREPARING, SERVED, PAID, REJECTED
  String paymentMethod; // UNPAID, CASH, GCASH
  String updatedAt;

  AdminOrder({
    required this.id,
    required this.tableNumber,
    required this.itemsDescription,
    required this.totalAmount,
    required this.status,
    required this.paymentMethod,
    required this.updatedAt,
  });

  factory AdminOrder.fromJson(Map<String, dynamic> json) {
    return AdminOrder(
      id: json['id'] ?? json['order_id'] ?? 100,
      tableNumber: json['table_number'] ?? json['table_id'] ?? 1,
      itemsDescription: _parseItems(json['items']),
      totalAmount: double.tryParse(json['total_amount']?.toString() ?? '0') ?? 0.0,
      status: (json['order_status'] ?? json['status'] ?? 'PENDING').toString().toUpperCase(),
      paymentMethod: (json['payment_method'] ?? 'UNPAID').toString().toUpperCase(),
      updatedAt: _formatTime(json['updated_at'] ?? json['created_at']),
    );
  }

  static String _parseItems(dynamic items) {
    if (items is List && items.isNotEmpty) {
      return items.map((i) => '${i['quantity'] ?? 1}x ${i['name'] ?? i['item_name'] ?? 'Dish'}').join(', ');
    }
    return 'Heritage Dish Selection';
  }

  static String _formatTime(dynamic rawDate) {
    try {
      final dt = DateTime.parse(rawDate.toString()).toLocal();
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final min = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$min $ampm • Today';
    } catch (_) {
      return 'Just now • Today';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      "status": status,
      "payment_method": paymentMethod,
      "updated_at": DateTime.now().toIso8601String(),
    };
  }
}

class DailySalesStats {
  final double totalSales;
  final int totalTransactions;
  final double cashSales;
  final double gcashSales;

  DailySalesStats({
    required this.totalSales,
    required this.totalTransactions,
    required this.cashSales,
    required this.gcashSales,
  });

  factory DailySalesStats.fromJson(Map<String, dynamic> json) {
    return DailySalesStats(
      totalSales: double.tryParse(json['gross_sales']?.toString() ?? json['total_sales']?.toString() ?? '0') ?? 0.0,
      totalTransactions: int.tryParse(json['total_transactions']?.toString() ?? '0') ?? 0,
      cashSales: double.tryParse(json['cash_sales']?.toString() ?? '0') ?? 0.0,
      gcashSales: double.tryParse(json['gcash_sales']?.toString() ?? '0') ?? 0.0,
    );
  }
}
