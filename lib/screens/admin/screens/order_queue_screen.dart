import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/admin_order_model.dart';
import '../services/admin_service.dart';
import '../../../config/api_config.dart';
import 'receipt_ticket_dialog.dart';
import 'payment_dialog_widget.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/admin_tokens.dart';
import '../../../widgets/status_chip.dart';
import '../../../widgets/empty_state.dart';

class OrderQueueScreen extends StatefulWidget {
  final List<AdminOrder> orders;
  final Function(int orderId, String targetStatus, {String? paymentMethod, String? declineReason}) onActionTriggered;
  final Future<void> Function(int orderId)? onReopenBill;
  final VoidCallback onRefresh;
  final DailySalesStats? stats;

  const OrderQueueScreen({
    super.key,
    required this.orders,
    required this.onActionTriggered,
    this.onReopenBill,
    required this.onRefresh,
    this.stats,
  });

  @override
  State<OrderQueueScreen> createState() => _OrderQueueScreenState();
}

class _OrderQueueScreenState extends State<OrderQueueScreen> {
  String _selectedStatusFilter = 'All';
  int? _selectedTableFilter;
  String _searchQuery = '';
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

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
    _searchController.dispose();
    super.dispose();
  }

  void _showDeclineDialog(BuildContext context, int orderId) {
    final TextEditingController reasonController = TextEditingController();
    final List<String> presets = ["Item Out of Stock", "Kitchen Closed", "Invalid Order"];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AdminTheme.surfaceIvory,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AdminTheme.border),
          ),
          title: const Text('Decline Order', style: TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.textDark)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select a preset reason or type your custom message:', style: TextStyle(fontSize: 12, color: AdminTheme.mutedDark)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: presets.map((preset) => ActionChip(
                  label: Text(preset, style: const TextStyle(fontSize: 11)),
                  backgroundColor: AdminTheme.surfaceIvory,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                    side: const BorderSide(color: AdminTheme.border),
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
                  labelStyle: const TextStyle(color: AdminTheme.mutedDark),
                  hintText: 'e.g. Out of stock na po ang napiling ulam',
                  hintStyle: const TextStyle(color: AdminTheme.mutedDark),
                  filled: true,
                  fillColor: AdminTheme.surfaceIvory,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AdminTheme.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AdminTheme.border),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AdminTheme.mutedDark)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.danger,
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
        onPaymentConfirmed: (netTotal, paid, change, discountType, partySize, pwdCount, customerName, idNumber) async {
          try {
            final String? authToken = AdminService.staffAuthToken;

            final response = await http.post(
              Uri.parse('${ApiConfig.baseUrl}/api/v1/orders/${order.id}/pay'),
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
              partySize: partySize,
              pwdCount: pwdCount,
              customerName: customerName,
              idNumber: idNumber,
              cashierName: AdminService.staffName ?? 'Staff',
            ),
          );
        },
      ),
    );
  }

  void _showConfirmationDialog(BuildContext context, String title, String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminTheme.surfaceIvory,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.textDark)),
        content: Text(message, style: const TextStyle(fontSize: 13, color: AdminTheme.infoText)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AdminTheme.mutedGray)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.textDark),
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: const Text('Confirm', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String get _serviceLabel {
    final int hour = DateTime.now().hour;
    if (hour < 11) return 'BREAKFAST SERVICE';
    if (hour < 16) return 'LUNCH SERVICE';
    return 'DINNER SERVICE';
  }

  String get _dateLabel => '${DateTime.now().month}/${DateTime.now().day}/${DateTime.now().year}';

  Widget _buildKpiStrip() {
    final int activeCount = widget.orders.where((o) {
      final st = o.status.toUpperCase();
      return st != 'PAID' && st != 'COMPLETED' && st != 'DECLINED' && st != 'CANCELLED' && st != 'REJECTED';
    }).length;

    final double totalSales = widget.stats?.totalSales ?? 0;
    final int pendingCount = widget.orders.where((o) => o.status.toUpperCase() == 'PENDING').length;

    final List<Widget> kpis = [
      _buildKpiCard(
        icon: Icons.attach_money_rounded,
        label: 'GROSS SALES TODAY',
        value: '₱${totalSales.toStringAsFixed(2)}',
        iconBg: AdminTheme.successBg,
        iconFg: AdminTheme.successFg,
      ),
      _buildKpiCard(
        icon: Icons.receipt_long_rounded,
        label: 'ACTIVE ORDERS',
        value: '$activeCount',
        iconBg: AdminTheme.warningBg,
        iconFg: AdminTheme.bronzeGold,
      ),
      _buildKpiCard(
        icon: Icons.hourglass_top_rounded,
        label: 'PENDING',
        value: '$pendingCount',
        iconBg: AdminTheme.preparingBg,
        iconFg: AdminTheme.priorityFg,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 720) {
          return Row(
            children: [
              for (final kpi in kpis) Expanded(child: kpi),
            ],
          );
        }
        return Column(
          children: [for (final kpi in kpis) kpi],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required IconData icon,
    required String label,
    required String value,
    required Color iconBg,
    required Color iconFg,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminTheme.surfaceIvory,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 19, color: iconFg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: AdminTheme.mutedDark),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(fontFamily: 'Libre Baskerville', fontSize: 20, fontWeight: FontWeight.w400, color: AdminTheme.textDark),
                ),
              ],
            ),
          ),
        ],
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
      color: AdminTheme.background,
      child: Stack(
        children: [
          RefreshIndicator(
        color: AdminTheme.textDark,
        onRefresh: () async => widget.onRefresh(),
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              '$_serviceLabel • $_dateLabel',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AdminTheme.bronzeGold, letterSpacing: 1.2),
            ),
            const SizedBox(height: 6),
            const Text(
              'Order queue',
              style: TextStyle(fontFamily: 'Libre Baskerville', fontSize: 28, fontWeight: FontWeight.w400, color: AdminTheme.textDark),
            ),
            const SizedBox(height: 4),
            const Text(
              'Review requests and keep every table moving with care.',
              style: TextStyle(fontSize: 14, color: AdminTheme.mutedDark, height: 1.5),
            ),
            const SizedBox(height: 16),

            _buildKpiStrip(),

            if (priorityTop3.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AdminTheme.textDark,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.stars_rounded, color: AdminTheme.goldAccent, size: 18),
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
              const Divider(height: 32, thickness: 1.5, color: AdminTheme.border),
            ],

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              height: 48,
              decoration: BoxDecoration(
                color: AdminTheme.surfaceIvory,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AdminTheme.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 20, color: AdminTheme.mutedDark),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: const TextStyle(fontSize: 13, color: AdminTheme.textDark),
                      decoration: InputDecoration(
                        hintText: 'Search code, table or dish',
                        hintStyle: const TextStyle(fontSize: 13, color: AdminTheme.mutedDark),
                        border: InputBorder.none,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.close, size: 16, color: AdminTheme.mutedDark),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        ),
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
                      selectedColor: AdminTheme.deepGreen,
                      backgroundColor: AdminTheme.surfaceIvory,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : AdminTheme.mutedDark,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                        side: BorderSide(color: isSelected ? AdminTheme.deepGreen : AdminTheme.border),
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
                color: AdminTheme.surfaceIvory,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AdminTheme.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.table_restaurant, size: 18, color: AdminTheme.mutedDark),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        value: _selectedTableFilter,
                        isExpanded: true,
                        style: const TextStyle(fontSize: 13, color: AdminTheme.textDark),
                        dropdownColor: AdminTheme.surfaceIvory,
                        hint: const Text('All tables', style: TextStyle(fontSize: 13, color: AdminTheme.textDark, fontWeight: FontWeight.w600)),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('All tables', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AdminTheme.textDark)),
                          ),
                          ...List.generate(15, (index) {
                            final tableNum = index + 1;
                            return DropdownMenuItem<int?>(
                              value: tableNum,
                              child: Text('Table ${tableNum.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 13, color: AdminTheme.textDark)),
                            );
                          }),
                        ],
                        onChanged: (val) => setState(() => _selectedTableFilter = val),
                      ),
                    ),
                  ),
                  if (_selectedTableFilter != null)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 16, color: AdminTheme.mutedDark),
                      onPressed: () => setState(() => _selectedTableFilter = null),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AdminTheme.warningBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(Icons.warning_amber_rounded, size: 18, color: AdminTheme.bronzeGold),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Requests await review. Pending does not mean accepted; kitchen and payment states are separate.',
                      style: TextStyle(fontSize: 12, height: 1.5, color: AdminTheme.warningFg),
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
                  style: const TextStyle(fontFamily: 'Libre Baskerville', fontSize: 18, color: AdminTheme.textDark),
                ),
                const Text(
                  'Pending first ↓',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AdminTheme.mutedDark),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (sortedOrders.isEmpty)
              const EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No additional orders match current filter.',
              )
            else
              ...sortedOrders.map((order) => _buildOrderCard(context, order)),

            const SizedBox(height: 20),
          ],
        ),
          ),
          // TEMP DISABLED (Bill Request feature on hold)
          // Positioned(
          //   left: 16,
          //   right: 16,
          //   bottom: 16,
          //   child: Material(
          //     color: AdminTheme.priorityFg,
          //     borderRadius: BorderRadius.circular(14),
          //     child: InkWell(
          //       onTap: () => setState(() => _selectedStatusFilter = 'Bill Requested'),
          //       borderRadius: BorderRadius.circular(14),
          //       child: Container(
          //         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          //         child: Row(
          //           children: [
          //             const Icon(Icons.receipt_long, color: Colors.white, size: 22),
          //             const SizedBox(width: 12),
          //             Expanded(
          //               child: Column(
          //                 crossAxisAlignment: CrossAxisAlignment.start,
          //                 children: [
          //                   Text(
          //                     'BILL REQUESTED • ${billRequestedOrders.length}',
          //                     style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          //                   ),
          //                   Text(
          //                     'Tables waiting for bill settlement / payment',
          //                     style: const TextStyle(color: Colors.white70, fontSize: 11),
          //                   ),
          //                 ],
          //               ),
          //             ),
          //             const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
          //           ],
          //         ),
          //       ),
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
      case 'NEW':
        return AdminTokens.warning;
      case 'PREPARING':
        return AdminTheme.infoText;
      case 'READY':
      case 'SERVED':
      case 'PAID':
      case 'COMPLETED':
        return AdminTokens.success;
      case 'REJECTED':
      case 'DECLINED':
      case 'CANCELLED':
        return AdminTokens.danger;
      default:
        return AdminTheme.mutedGray;
    }
  }

  Widget _buildOrderCard(BuildContext context, AdminOrder order, {int? priorityRank}) {
    Color cardBg = AdminTheme.surfaceIvory;

    bool isPriority = priorityRank != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPriority ? AdminTheme.goldAccent : AdminTheme.border,
          width: isPriority ? 2.0 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 44,
            decoration: BoxDecoration(
              color: _statusColor(order.status),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 12),
          // TEMP DISABLED (Bill Request feature on hold)
          // if (isBillRequested) ...[
          //   Container(
          //     width: double.infinity,
          //     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          //     margin: const EdgeInsets.only(bottom: 10),
          //     decoration: BoxDecoration(
          //       color: AdminTheme.warningBg,
          //       borderRadius: BorderRadius.circular(6),
          //       border: Border.all(color: AdminTheme.bronzeGold),
          //     ),
          //     child: const Row(
          //       children: [
          //         Icon(Icons.receipt_long, size: 14, color: AdminTheme.warningFg),
          //         SizedBox(width: 6),
          //         Text(
          //           '🧾 BILL REQUESTED BY CUSTOMER',
          //           style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AdminTheme.warningFg, letterSpacing: 0.8),
          //         ),
          //       ],
          //     ),
          //   ),
          // ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isPriority ? 'PRIORITY #$priorityRank • EARLIEST UNSETTLED' : 'SELECTED FOR REVIEW',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isPriority ? AdminTheme.priorityFg : AdminTheme.mutedDark,
                  letterSpacing: 0.8,
                ),
              ),
              if (isPriority)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AdminTheme.goldAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'PINNED TOP $priorityRank',
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AdminTheme.priorityFg),
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
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AdminTheme.textDark),
              ),
              StatusChip(status: order.status),
            ],
          ),
          if (order.hasPendingBillRequest) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF7E8CE),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AdminTheme.goldAccent),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long, size: 16, color: AdminTheme.priorityFg),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'BILL REQUESTED • Awaiting bill settlement / payment',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AdminTheme.priorityFg),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '₱${order.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AdminTheme.textDark),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: widget.onReopenBill == null
                    ? null
                    : () => widget.onReopenBill!(order.id),
                icon: const Icon(Icons.lock_open, size: 14),
                label: const Text('Reopen Ordering', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AdminTheme.priorityFg,
                  side: const BorderSide(color: AdminTheme.goldAccent),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'Table ${order.tableNumber.toString().padLeft(2, '0')} • Dine-in',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AdminTheme.textDark),
          ),
          const SizedBox(height: 8),
          Text(
            order.itemsDescription,
            style: const TextStyle(fontSize: 13, color: AdminTheme.infoText),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${order.updatedAt} • Live sync',
                style: const TextStyle(fontSize: 11, color: AdminTheme.mutedDark),
              ),
              Text(
                '₱${order.totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AdminTheme.textDark),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildActionButtonsForOrder(context, order),
          const SizedBox(height: 8),
          const Text(
            'Received, not accepted - Decline with a reason in review.',
            style: TextStyle(fontSize: 11, color: AdminTheme.mutedDark),
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
                foregroundColor: AdminTheme.danger,
                side: const BorderSide(color: AdminTheme.border),
                backgroundColor: AdminTheme.surfaceIvory,
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
                backgroundColor: AdminTheme.textDark,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => _showConfirmationDialog(
                context,
                'Accept Order #${order.id}?',
                'Are you sure you want to accept and start preparing this order for Table #${order.tableNumber}?',
                () => widget.onActionTriggered(order.id, 'PREPARING'),
              ),
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
            backgroundColor: AdminTheme.textDark,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onPressed: () => _showConfirmationDialog(
            context,
            'Mark Order #${order.id} as Served?',
            'Confirm that this order has been served to Table #${order.tableNumber}?',
            () => widget.onActionTriggered(order.id, 'SERVED'),
          ),
          child: const Text('Mark as Served', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ),
      );
    } else if (order.status.toUpperCase() == 'SERVED' && order.paymentMethod.toUpperCase() == 'UNPAID') {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.textDark,
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
                backgroundColor: AdminTheme.surfaceIvory,
                foregroundColor: AdminTheme.textDark,
                elevation: 0,
                side: const BorderSide(color: AdminTheme.border),
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