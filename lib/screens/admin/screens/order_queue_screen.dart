import 'package:flutter/material.dart';
import '../models/admin_order_model.dart';

class OrderQueueScreen extends StatelessWidget {
  final List<AdminOrder> orders;
  final Function(int orderId, String targetStatus, {String? paymentMethod}) onActionTriggered;
  final VoidCallback onRefresh;

  const OrderQueueScreen({
    super.key,
    required this.orders,
    required this.onActionTriggered,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long_outlined, size: 64, color: Color(0xFF788078)),
            const SizedBox(height: 16),
            const Text(
              'No active orders in queue.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1B3B2B)),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B3B2B)),
              onPressed: onRefresh,
              child: const Text('Refresh Queue', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF1B3B2B),
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          Color statusColor;

          switch (order.status) {
            case 'PENDING':
              statusColor = const Color(0xFFFBBF24);
              break;
            case 'PREPARING':
              statusColor = const Color(0xFF3B82F6);
              break;
            case 'SERVED':
              statusColor = const Color(0xFF8B5CF6);
              break;
            case 'PAID':
              statusColor = const Color(0xFF10B981);
              break;
            case 'REJECTED':
              statusColor = const Color(0xFFEF4444);
              break;
            default:
              statusColor = const Color(0xFF788078);
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE5DFD3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Table #${order.tableNumber.toString().padLeft(2, '0')} • Order #${order.id}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1B3B2B)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        order.status,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  order.itemsDescription,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF4A5568)),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '₱${order.totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1B3B2B)),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Text('Payment: ', style: TextStyle(fontSize: 11, color: Color(0xFF788078))),
                            Text(
                              order.paymentMethod,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: order.paymentMethod == 'PAID' || order.paymentMethod == 'CASH' || order.paymentMethod == 'GCASH'
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFEF4444),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('• ${order.updatedAt}', style: const TextStyle(fontSize: 11, color: Color(0xFF788078))),
                          ],
                        ),
                      ],
                    ),
                    _buildActionButtonsForOrder(order),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionButtonsForOrder(AdminOrder order) {
    if (order.status == 'PENDING') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
              side: const BorderSide(color: Color(0xFFEF4444)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => onActionTriggered(order.id, 'REJECTED'),
            child: const Text('Reject', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B3B2B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => onActionTriggered(order.id, 'PREPARING'),
            child: const Text('Accept', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      );
    } else if (order.status == 'PREPARING') {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3B82F6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: () => onActionTriggered(order.id, 'SERVED'),
        child: const Text('Mark Served', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
      );
    } else if (order.status == 'SERVED' && order.paymentMethod == 'UNPAID') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => onActionTriggered(order.id, 'PAID', paymentMethod: 'CASH'),
            child: const Text('Pay Cash', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => onActionTriggered(order.id, 'PAID', paymentMethod: 'GCASH'),
            child: const Text('Pay GCash', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}
