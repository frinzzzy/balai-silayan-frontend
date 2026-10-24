import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/admin_order_model.dart';
import '../services/admin_service.dart';
import 'receipt_ticket_dialog.dart';
import 'payment_dialog_widget.dart';

class OrderQueueScreen extends StatefulWidget {
  final List<AdminOrder> orders;
  final Function(int orderId, String targetStatus, {String? paymentMethod, String? declineReason}) onActionTriggered;
  final VoidCallback onRefresh;

  const OrderQueueScreen({
    super.key,
    required this.orders,
    required this.onActionTriggered,
    required this.onRefresh,
  });

  @override
  State<OrderQueueScreen> createState() => _OrderQueueScreenState();
}

class _OrderQueueScreenState extends State<OrderQueueScreen> {
  String _selectedStatusFilter = 'All';
  int? _selectedTableFilter;
  String _searchQuery = '';
  final ScrollController _scrollController = ScrollController();

  int _getStatusPriority(String status) {
    switch (status.toUpperCase()) {
      case 'NEW':
      case 'PENDING':
        return 1;
      case 'PREPARING':
        return 2;
      case 'READY':
      case 'SERVED':
        return 3;
      case 'PAID':
      case 'COMPLETED':
        return 4;
      case 'REJECTED':
      case 'DECLINED':
      case 'CANCELLED':
        return 5;
      default:
        return 6;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _showDeclineDialog(BuildContext context, int orderId) {
    final TextEditingController reasonController = TextEditingController();
    final List<String> presets = ["Item Out of Stock", "Kitchen Closed", "Invalid Order"];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFFFFFDFA),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE5DFD3)),
          ),
          title: const Text('Decline Order', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF203F35))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select a preset reason or type your custom message:', style: TextStyle(fontSize: 12, color: Color(0xFF687368))),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: presets.map((preset) => ActionChip(
                  label: Text(preset, style: const TextStyle(fontSize: 11)),
                  backgroundColor: const Color(0xFFFFFDFA),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                    side: const BorderSide(color: Color(0xFFE5DFD3)),
                  ),
                  onPressed: () {
                    reasonController.text = preset;
                    setDialogState(() {});
                  },
                )).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Decline Reason',
                  labelStyle: const TextStyle(color: Color(0xFF687368)),
                  hintText: 'e.g. Out of stock na po ang napiling ulam',
                  hintStyle: const TextStyle(color: Color(0xFF687368)),
                  filled: true,
                  fillColor: const Color(0xFFFFFDFA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE5DFD3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE5DFD3)),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF687368))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8E5136),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                final reason = reasonController.text.trim();
                Navigator.pop(ctx);
                widget.onActionTriggered(
                  orderId,
                  'DECLINED',
                  declineReason: reason.isNotEmpty ? reason : 'Item Out of Stock',
                );
              },
              child: const Text('Confirm Decline', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // PAYMENT DIALOG INTEGRATION WITH PAYMENT WIDGET & RECEIPT TICKET
  // -------------------------------------------------------------
  void _showPaymentDialog(BuildContext context, AdminOrder order, String paymentMethod) {
    showDialog(
      context: context,
      builder: (ctx) => PaymentDialog(
        order: order,
        paymentMethod: paymentMethod,
        onPaymentConfirmed: (netTotal, paid, change, discountType) async {
          try {
            final String? authToken = AdminService.staffAuthToken;

            final response = await http.post(
              Uri.parse('http://localhost:5000/api/v1/orders/${order.id}/pay'),
              headers: {
                'Content-Type': 'application/json',
                if (authToken != null) 'Authorization': 'Bearer $authToken',
              },
              body: jsonEncode({
                'payment_method': paymentMethod.toUpperCase(),
                'amount_paid': paid,
                'discount_type': discountType,
              }),
            );

            if (response.statusCode == 200) {
              widget.onRefresh();
            } else {
              final errData = jsonDecode(response.body);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(errData['message'] ?? 'Payment error')),
                );
              }
            }
          } catch (e) {
            widget.onActionTriggered(order.id, 'PAID', paymentMethod: paymentMethod);
          }

          if (!context.mounted) return;
          showDialog(
            context: context,
            builder: (dialogContext) => ReceiptTicketDialog(
              order: order,
              grossTotal: order.totalAmount,
              discountAmount: order.totalAmount - netTotal,
              netTotal: netTotal,
              paid: paid,
              change: change,
              discountType: discountType,
              paymentMethod: paymentMethod,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<AdminOrder> activeOrders = widget.orders.where((o) {
      final st = o.status.toUpperCase();
      return st != 'PAID' && st != 'COMPLETED' && st != 'DECLINED' && st != 'CANCELLED' && st != 'REJECTED';
    }).toList();

    activeOrders.sort((a, b) => a.id.compareTo(b.id));

    List<AdminOrder> priorityTop3 = activeOrders.take(3).toList();
    Set<int> priorityIds = priorityTop3.map((o) => o.id).toSet();

    List<AdminOrder> filteredOrders = widget.orders.where((o) {
      if (priorityIds.contains(o.id)) return false;

      bool matchesStatus = _selectedStatusFilter == 'All' || o.status.toUpperCase() == _selectedStatusFilter.toUpperCase();
      bool matchesTable = _selectedTableFilter == null || o.tableNumber == _selectedTableFilter;
      bool matchesSearch = _searchQuery.isEmpty ||
          o.id.toString().contains(_searchQuery) ||
          o.tableNumber.toString().contains(_searchQuery) ||
          o.itemsDescription.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesStatus && matchesTable && matchesSearch;
    }).toList();

    List<AdminOrder> sortedOrders = List.from(filteredOrders);
    sortedOrders.sort((a, b) {
      final pA = _getStatusPriority(a.status);
      final pB = _getStatusPriority(b.status);
      if (pA != pB) return pA.compareTo(pB);
      return b.id.compareTo(a.id);
    });

    return Container(
      color: const Color(0xFFF8F4EC),
      child: RefreshIndicator(
        color: const Color(0xFF203F35),
        onRefresh: () async => widget.onRefresh(),
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'LUNCH SERVICE • 8 OCT 2026',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFA47C3D), letterSpacing: 1.2),
            ),
            const SizedBox(height: 6),
            const Text(
              'Order queue',
              style: TextStyle(fontFamily: 'Libre Baskerville', fontSize: 28, fontWeight: FontWeight.w400, color: Color(0xFF203F35)),
            ),
            const SizedBox(height: 4),
            const Text(
              'Review requests and keep every table moving with care.',
              style: TextStyle(fontSize: 14, color: Color(0xFF687368), height: 1.5),
            ),
            const SizedBox(height: 16),

            if (priorityTop3.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF203F35),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.stars_rounded, color: Color(0xFFC3AA7F), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'TOP PRIORITY • EARLIEST ACTIVE ORDERS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ...priorityTop3.asMap().entries.map((entry) {
                int rank = entry.key + 1;
                AdminOrder order = entry.value;
                return _buildOrderCard(context, order, priorityRank: rank);
              }),
              const Divider(height: 32, thickness: 1.5, color: Color(0xFFE5DFD3)),
            ],

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFFFFDFA),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5DFD3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 20, color: Color(0xFF687368)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: const InputDecoration(
                        hintText: 'Search code, table or dish',
                        hintStyle: TextStyle(fontSize: 13, color: Color(0xFF687368)),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['All', 'Pending', 'Preparing', 'Ready', 'Served', 'Completed', 'Declined'].map((filter) {
                  final isSelected = _selectedStatusFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: isSelected,
                      onSelected: (selected) => setState(() => _selectedStatusFilter = filter),
                      selectedColor: const Color(0xFF203F35),
                      backgroundColor: const Color(0xFFFFFDFA),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : const Color(0xFF687368),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                        side: const BorderSide(color: Color(0xFFE5DFD3)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFDFA),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5DFD3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.table_restaurant, size: 18, color: Color(0xFF687368)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        value: _selectedTableFilter,
                        isExpanded: true,
                        hint: const Text('All tables', style: TextStyle(fontSize: 13, color: Color(0xFF203F35), fontWeight: FontWeight.w600)),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('All tables', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          ),
                          ...List.generate(15, (index) {
                            final tableNum = index + 1;
                            return DropdownMenuItem<int?>(
                              value: tableNum,
                              child: Text('Table ${tableNum.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 13)),
                            );
                          }),
                        ],
                        onChanged: (val) => setState(() => _selectedTableFilter = val),
                      ),
                    ),
                  ),
                  if (_selectedTableFilter != null)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 16, color: Color(0xFF687368)),
                      onPressed: () => setState(() => _selectedTableFilter = null),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF5EBD7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFA47C3D)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Requests await review. Pending does not mean accepted; kitchen and payment states are separate.',
                      style: TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF846228)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'All Orders (${sortedOrders.length})',
                  style: const TextStyle(fontFamily: 'Libre Baskerville', fontSize: 18, color: Color(0xFF203F35)),
                ),
                const Text(
                  'Pending first ↓',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF687368)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (sortedOrders.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    const Icon(Icons.receipt_long_outlined, size: 48, color: Color(0xFF687368)),
                    const SizedBox(height: 12),
                    const Text('No additional orders match current filter.', style: TextStyle(color: Color(0xFF687368), fontWeight: FontWeight.bold)),
                  ],
                ),
              )
            else
              ...sortedOrders.map((order) => _buildOrderCard(context, order)),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, AdminOrder order, {int? priorityRank}) {
    Color cardBg = const Color(0xFFFFFDFA);
    Color statusBg = const Color(0xFFF5EBD7);
    Color statusFg = const Color(0xFFA47C3D);

    if (order.status.toUpperCase() == 'PREPARING') {
      statusBg = const Color(0xFFF7EAE4);
      statusFg = const Color(0xFF8E5136);
    } else if (order.status.toUpperCase() == 'READY' || order.status.toUpperCase() == 'SERVED' || order.status.toUpperCase() == 'PAID' || order.status.toUpperCase() == 'COMPLETED') {
      statusBg = const Color(0xFFEAF0E9);
      statusFg = const Color(0xFF53766C);
    }

    bool isPriority = priorityRank != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPriority ? const Color(0xFFC3AA7F) : const Color(0xFFE5DFD3),
          width: isPriority ? 2.0 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isPriority ? 'PRIORITY #$priorityRank • EARLIEST UNSETTLED' : 'SELECTED FOR REVIEW',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isPriority ? const Color(0xFF8A6D3B) : const Color(0xFF687368),
                  letterSpacing: 0.8,
                ),
              ),
              if (isPriority)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC3AA7F).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'PINNED TOP $priorityRank',
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF8A6D3B)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '#BS-${order.id}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF203F35)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  order.status,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusFg),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Table ${order.tableNumber.toString().padLeft(2, '0')} • Dine-in',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF24382F)),
          ),
          const SizedBox(height: 8),
          Text(
            order.itemsDescription,
            style: const TextStyle(fontSize: 13, color: Color(0xFF4A5568)),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${order.updatedAt} • Live sync',
                style: const TextStyle(fontSize: 11, color: Color(0xFF687368)),
              ),
              Text(
                '₱${order.totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF203F35)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildActionButtonsForOrder(context, order),
          const SizedBox(height: 8),
          const Text(
            'Received, not accepted - Decline with a reason in review.',
            style: TextStyle(fontSize: 11, color: Color(0xFF687368)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtonsForOrder(BuildContext context, AdminOrder order) {
    if (order.status.toUpperCase() == 'PENDING' || order.status.toUpperCase() == 'NEW') {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF8E5136),
                side: const BorderSide(color: Color(0xFFE5DFD3)),
                backgroundColor: const Color(0xFFFFFDFA),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => _showDeclineDialog(context, order.id),
              child: const Text('Decline', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF203F35),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => widget.onActionTriggered(order.id, 'PREPARING'),
              child: const Text('Review & accept', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      );
    } else if (order.status.toUpperCase() == 'PREPARING') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF203F35),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onPressed: () => widget.onActionTriggered(order.id, 'SERVED'),
          child: const Text('Mark as Served', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ),
      );
    } else if (order.status.toUpperCase() == 'SERVED' && order.paymentMethod.toUpperCase() == 'UNPAID') {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF203F35),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => _showPaymentDialog(context, order, 'CASH'),
              child: const Text('Pay Cash', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFFDFA),
                foregroundColor: const Color(0xFF203F35),
                elevation: 0,
                side: const BorderSide(color: Color(0xFFE5DFD3)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => _showPaymentDialog(context, order, 'GCASH'),
              child: const Text('Pay GCash', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}