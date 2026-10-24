import 'package:flutter/material.dart';
import '../models/admin_order_model.dart';

class ReceiptTicketDialog extends StatelessWidget {
  final AdminOrder order;
  final double grossTotal;
  final double discountAmount;
  final double netTotal;
  final double paid;
  final double change;
  final String discountType;
  final String paymentMethod;

  const ReceiptTicketDialog({
    super.key,
    required this.order,
    required this.grossTotal,
    required this.discountAmount,
    required this.netTotal,
    required this.paid,
    required this.change,
    required this.discountType,
    required this.paymentMethod,
  });

  @override
  Widget build(BuildContext context) {
    final String timeStr = TimeOfDay.now().format(context);

    // Wastong pagkuwenta ng VAT breakdown batay sa net total o kung may discount
    final double vatableSales = (discountType == 'NONE') ? (netTotal / 1.12) : (netTotal / 1.12);
    final double vatAmount = (discountType == 'NONE') ? (netTotal - vatableSales) : (netTotal * 0.12);
    final double vatExemptSales = (discountType != 'NONE') ? netTotal : 0.0;

    return AlertDialog(
      backgroundColor: const Color(0xFFFFFDFA),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.all(20),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'BALAI SILAYAN',
              style: TextStyle(
                fontFamily: 'Libre Baskerville',
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Color(0xFF203F35),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Heritage Restaurant & Cafe',
              style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF687368)),
            ),
            const Text(
              'Nagcarlan, Laguna • TIN: 123-456-789-000',
              style: TextStyle(fontSize: 10, color: Color(0xFF687368)),
            ),
            const SizedBox(height: 8),
            const Text('--------------------------------------------------', style: TextStyle(color: Colors.grey, fontSize: 10)),
            const Text(
              'OFFICIAL ORDER TICKET',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Color(0xFF203F35)),
            ),
            const Text('--------------------------------------------------', style: TextStyle(color: Colors.grey, fontSize: 10)),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Date: 08 OCT 2026', style: TextStyle(fontSize: 11, color: Color(0xFF4A5568))),
                Text('Time: $timeStr', style: const TextStyle(fontSize: 11, color: Color(0xFF4A5568))),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Order Code: #BS-${order.id}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF203F35))),
                Text('Table: ${order.tableNumber.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF203F35))),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(thickness: 1, color: Color(0xFFE5DFD3)),

            Align(
              alignment: Alignment.centerLeft,
              child: Text('ITEMS ORDERED:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[700])),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(order.itemsDescription, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF203F35)))),
                Text('₱${grossTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(thickness: 1, color: Color(0xFFE5DFD3)),

            _buildReceiptRow('Subtotal (Gross)', '₱${grossTotal.toStringAsFixed(2)}'),
            if (discountType != 'NONE')
              _buildReceiptRow('Discount ($discountType)', '-₱${discountAmount.toStringAsFixed(2)}', isHighlight: true),
            const SizedBox(height: 4),
            _buildReceiptRow('VATable Sales', '₱${vatableSales.toStringAsFixed(2)}', isSmall: true),
            _buildReceiptRow('VAT Exempt Sales', '₱${vatExemptSales.toStringAsFixed(2)}', isSmall: true),
            _buildReceiptRow('12% VAT', '₱${vatAmount.toStringAsFixed(2)}', isSmall: true),
            const Divider(thickness: 1, color: Color(0xFFE5DFD3)),

            _buildReceiptRow('TOTAL AMOUNT DUE', '₱${netTotal.toStringAsFixed(2)}', isBold: true, fontSize: 15),
            _buildReceiptRow('Amount Paid ($paymentMethod)', '₱${paid.toStringAsFixed(2)}'),
            _buildReceiptRow('Change', '₱${change.toStringAsFixed(2)}', isBold: true, isHighlight: true),

            const SizedBox(height: 16),
            const Text('--------------------------------------------------', style: TextStyle(color: Colors.grey, fontSize: 10)),
            const SizedBox(height: 4),
            const Text(
              'Salamat po sa pagtangkilik sa Balai Silayan!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic, color: Color(0xFF203F35)),
            ),
            const SizedBox(height: 4),
            const Text(
              'THIS RECEIPT SERVES AS AN OFFICIAL TICKET.\nPLEASE RETAIN THIS FOR TABLE SERVICE VALIDATION.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 9, color: Color(0xFF687368), height: 1.3),
            ),
          ],
        ),
      ),
      actions: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC3AA7F),
                foregroundColor: const Color(0xFF203F35),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.print_outlined, size: 18),
              label: const Text('Print Receipt / Export PDF', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sending to thermal printer...'), backgroundColor: Color(0xFF203F35)),
                );
              },
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close & Complete', style: TextStyle(color: Color(0xFF687368), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReceiptRow(String title, String value, {bool isBold = false, bool isHighlight = false, bool isSmall = false, double fontSize = 12}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: isSmall ? 10 : fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: isHighlight ? Colors.green[800] : (isSmall ? Colors.grey[600] : const Color(0xFF203F35)))),
          Text(value, style: TextStyle(fontSize: isSmall ? 10 : fontSize, fontWeight: isBold || isHighlight ? FontWeight.bold : FontWeight.normal, color: isHighlight ? Colors.green[800] : (isSmall ? Colors.grey[600] : const Color(0xFF203F35)))),
        ],
      ),
    );
  }
}