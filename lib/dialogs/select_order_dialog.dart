import 'package:flutter/material.dart';
import '../models/user_session.dart';

class SelectOrderDialog extends StatelessWidget {
  final List<dynamic> unfinishedOrders;

  const SelectOrderDialog({
    super.key,
    required this.unfinishedOrders,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFFFFFDFA),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text(
        'Select Order to Add Items',
        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF203F35)),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: unfinishedOrders.length,
          itemBuilder: (context, index) {
            final order = unfinishedOrders[index];
            final orderId = order['id'] ?? order['order_id'];
            final formattedCode = UserSession.formatOrderCode(orderId);
            final total = order['total_amount'] ?? order['grand_total'] ?? '0.00';
            final status = order['order_status'] ?? order['status'] ?? 'PENDING';

            return Card(
              color: const Color(0xFFF8F4EC),
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFE5DFD3)),
              ),
              child: ListTile(
                title: Text('$formattedCode ($status)', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF203F35))),
                subtitle: Text('Total: ₱$total', style: const TextStyle(color: Color(0xFF788078))),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFFA47C3D)),
                onTap: () => Navigator.pop(context, order),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel', style: TextStyle(color: Color(0xFF788078))),
        ),
      ],
    );
  }
}
