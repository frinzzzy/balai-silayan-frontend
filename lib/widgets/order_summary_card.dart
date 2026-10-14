import 'package:flutter/material.dart';

class OrderSummaryCard extends StatelessWidget {
  final String orderCode;
  final String tableString;
  final String statusBadgeLabel;
  final String timestamp;
  final List<dynamic> items;
  final double grandTotal; // Trusting backend grand_total

  const OrderSummaryCard({
    super.key,
    required this.orderCode,
    required this.tableString,
    required this.statusBadgeLabel,
    required this.timestamp,
    required this.items,
    required this.grandTotal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDFA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5DFD3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEEE7D9),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.access_time, size: 13, color: Color(0xFFA47C3D)),
                const SizedBox(width: 6),
                Text(
                  statusBadgeLabel,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFA47C3D)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'TABLE SESSION RECEIPT',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFA47C3D), letterSpacing: 1.1),
          ),
          const SizedBox(height: 2),
          Text(
            orderCode,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF203F35)),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Table', style: TextStyle(fontSize: 12, color: Color(0xFF788078))),
              Text(tableString, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF203F35))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Submitted', style: TextStyle(fontSize: 12, color: Color(0xFF788078))),
              Text(timestamp, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF203F35))),
            ],
          ),
          if (items.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10.0),
              child: Divider(height: 1, color: Color(0xFFE5DFD3)),
            ),
            ...items.map((item) {
              final String name = item['name'] ?? item['item_name'] ?? 'Item';
              final int qty = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
              final double unitPrice = double.tryParse(item['unit_price']?.toString() ?? item['price']?.toString() ?? '0') ?? 0.0;
              final double lineTotal = double.tryParse(item['line_total']?.toString() ?? '') ?? (unitPrice * qty);

              return Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '$qty x $name',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF24382F)),
                      ),
                    ),
                    Text(
                      '₱${lineTotal.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF203F35)),
                    ),
                  ],
                ),
              );
            }),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14.0),
            child: Divider(height: 1, color: Color(0xFFE5DFD3)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Session Grand Total',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF24382F)),
              ),
              Text(
                '₱${grandTotal.toStringAsFixed(2)}', // Trusted backend grand_total
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF203F35)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
