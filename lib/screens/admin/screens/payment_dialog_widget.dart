import 'package:flutter/material.dart';
import '../models/admin_order_model.dart';
import '../../../theme/app_theme.dart';

class PaymentDialog extends StatefulWidget {
  final AdminOrder order;
  final String paymentMethod;
  final void Function(double netTotal, double paid, double change, String discountType, int partySize, int pwdCount, String customerName, String idNumber) onPaymentConfirmed;

  const PaymentDialog({
    super.key,
    required this.order,
    required this.paymentMethod,
    required this.onPaymentConfirmed,
  });

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  late TextEditingController amountPaidController;
  late TextEditingController partySizeController;
  late TextEditingController pwdCountController;
  late TextEditingController customerNameController;
  late TextEditingController idNumberController;

  String selectedDiscount = 'NONE';

  @override
  void initState() {
    super.initState();
    amountPaidController = TextEditingController();
    partySizeController = TextEditingController(text: '1');
    pwdCountController = TextEditingController(text: '0');
    customerNameController = TextEditingController();
    idNumberController = TextEditingController();
  }

  @override
  void dispose() {
    amountPaidController.dispose();
    partySizeController.dispose();
    pwdCountController.dispose();
    customerNameController.dispose();
    idNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double grossTotal = widget.order.totalAmount;
    double paid = double.tryParse(amountPaidController.text) ?? 0.0;
    int totalParty = int.tryParse(partySizeController.text) ?? 1;
    int pwdCount = int.tryParse(pwdCountController.text) ?? 0;

    // Compute Discount based on Party Share
    double discountAmount = 0.0;
    if (selectedDiscount != 'NONE' && totalParty > 0 && pwdCount > 0) {
      double shareRatio = pwdCount / totalParty;
      double applicableGross = grossTotal * shareRatio;
      double vatExemptSales = applicableGross / 1.12;
      discountAmount = vatExemptSales * 0.20;
    }

    double netTotal = grossTotal - discountAmount;
    double change = paid - netTotal;

    return AlertDialog(
      backgroundColor: AdminTheme.surfaceIvory,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Process Payment #${widget.order.id} (${widget.paymentMethod})',
        style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.textDark),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gross Total: ₱${grossTotal.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AdminTheme.textDark),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: selectedDiscount,
              style: const TextStyle(color: AdminTheme.textDark, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Discount Type',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              items: const [
                DropdownMenuItem(value: 'NONE', child: Text('No Discount', style: TextStyle(color: AdminTheme.textDark))),
                DropdownMenuItem(value: 'SENIOR_CITIZEN', child: Text('Senior Citizen', style: TextStyle(color: AdminTheme.textDark))),
                DropdownMenuItem(value: 'PWD', child: Text('PWD', style: TextStyle(color: AdminTheme.textDark))),
              ],
              onChanged: (val) => setState(() => selectedDiscount = val ?? 'NONE'),
            ),
            if (selectedDiscount != 'NONE') ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: partySizeController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: AdminTheme.textDark, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Total Party Size',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: pwdCountController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: AdminTheme.textDark, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'PWD/Senior Count',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: customerNameController,
                style: const TextStyle(color: AdminTheme.textDark, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Customer Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: idNumberController,
                style: const TextStyle(color: AdminTheme.textDark, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'ID Number',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: amountPaidController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AdminTheme.textDark, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Amount Paid (₱)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Text(
              'Net Amount Due: ₱${netTotal.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.textDark),
            ),
            Text(
              'Change: ₱${change >= 0 ? change.toStringAsFixed(2) : "0.00"}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: change >= 0 ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.textDark),
          onPressed: paid >= netTotal
              ? () {
                  Navigator.pop(context);
                  widget.onPaymentConfirmed(netTotal, paid, change, selectedDiscount, totalParty, pwdCount, customerNameController.text.trim(), idNumberController.text.trim());
                }
              : null,
          child: const Text('Approve & Generate Ticket', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
