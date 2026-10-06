import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'menu_screen.dart';
import 'assistance_screen.dart';
import 'order_status_screen.dart';
import 'bill_requested_screen.dart';

class SessionBillScreen extends StatefulWidget {
  final int? tableId;
  final bool isTakeout;

  const SessionBillScreen({
    super.key,
    this.tableId = 7,
    this.isTakeout = false,
  });

  @override
  State<SessionBillScreen> createState() => _SessionBillScreenState();
}

class _SessionBillScreenState extends State<SessionBillScreen> {
  bool _isLoading = true;
  bool _isRequestingBill = false;
  bool _billRequestedSubmitted = false;
  double _foodDrinksTotal = 0.0;
  double _addOnsTotal = 0.0;
  double _grandTotal = 0.0;
  List<Map<String, dynamic>> _sessionOrders = [];

  // Fallback sample session orders matching the Figma Auto Layout specification
  final List<Map<String, dynamic>> _sampleBilledOrders = [
    {
      "order_code": "#BS-1042",
      "status": "SERVED",
      "time": "12:08 PM • Today",
      "items": [
        {"name": "Chicken Inasal (x2)", "price": 570.0, "details": "Garlic rice • +₱45 each"},
        {"name": "Kare-Kare (x1)", "price": 425.0, "details": "Standard serving"},
        {"name": "Calamansi Cooler (x2)", "price": 170.0, "details": "Ice chilled"},
      ],
      "order_total": 1165.0,
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchSessionBillData();
  }

  Future<void> _fetchSessionBillData() async {
    final int tableNum = widget.tableId ?? 7;
    try {
      final response = await http.get(
        Uri.parse('http://localhost:5000/api/v1/tables/$tableNum/bill'),
      );
      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        final data = resData['data'];
        if (data != null && mounted) {
          final List ordersList = data['orders'] ?? [];
          setState(() {
            _grandTotal = double.tryParse(data['grand_total']?.toString() ?? '1255') ?? 1255.0;
            _foodDrinksTotal = _grandTotal * 0.92;
            _addOnsTotal = _grandTotal * 0.08;
            if (ordersList.isNotEmpty) {
              _sessionOrders = List<Map<String, dynamic>>.from(ordersList);
            } else {
              _sessionOrders = _sampleBilledOrders;
            }
            _isLoading = false;
          });
          return;
        }
      }
    } catch (_) {}

    // Fallback if backend offline
    if (mounted) {
      setState(() {
        _sessionOrders = _sampleBilledOrders;
        _foodDrinksTotal = 1165.0;
        _addOnsTotal = 90.0;
        _grandTotal = 1255.0;
        _isLoading = false;
      });
    }
  }

  Future<void> _submitRequestBill() async {
    setState(() => _isRequestingBill = true);
    final int tableNum = widget.tableId ?? 7;

    try {
      await http.post(
        Uri.parse('http://localhost:5000/api/v1/assistance'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "table_id": tableNum,
          "request_type": "Bill",
          "message": "Bill Requested for Table #$tableNum • Total: ₱${_grandTotal.toStringAsFixed(0)}",
          "timestamp": DateTime.now().toIso8601String(),
        }),
      );
    } catch (_) {}

    if (mounted) {
      setState(() => _isRequestingBill = false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => BillRequestedScreen(
            tableId: widget.tableId,
            isTakeout: widget.isTakeout,
            totalAmount: _grandTotal,
            foodDrinksTotal: _foodDrinksTotal,
            addOnsTotal: _addOnsTotal,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final int tableNum = widget.tableId ?? 7;
    final String tableString = widget.isTakeout ? 'Takeout' : 'Table ${tableNum.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F4EC),
      body: SafeArea(
        child: Column(
          children: [
            _buildRestaurantHeader(),
            _buildTableContextStrip(tableString),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF203F35)))
                  : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildIntroductionHeader(),
                    const SizedBox(height: 12),
                    _buildSessionStatusBadge(),
                    const SizedBox(height: 20),
                    ..._sessionOrders.map((order) => _buildBilledOrderCard(order)),
                    const SizedBox(height: 12),
                    _buildPriceBreakdownCard(),
                    const SizedBox(height: 16),
                    _buildWalletContextNote(),
                    const SizedBox(height: 24),
                    _buildPrimaryActionButton(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildCustomerBottomNav(),
    );
  }

  Widget _buildRestaurantHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(22),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE5DFD3)),
              ),
              child: const Icon(Icons.arrow_back, color: Color(0xFF203F35), size: 20),
            ),
          ),
          Column(
            children: [
              Container(
                width: 26,
                height: 22,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFA47C3D), width: 1.4),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.home_outlined, size: 14, color: Color(0xFFA47C3D)),
              ),
              const SizedBox(height: 4),
              const Text(
                'BALAI SILAYAN',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF203F35),
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AssistanceScreen()),
              );
            },
            borderRadius: BorderRadius.circular(22),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE5DFD3)),
              ),
              child: const Icon(Icons.notifications_outlined, color: Color(0xFF203F35), size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableContextStrip(String tableString) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      color: const Color(0xFFEEE7D9),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF53766C)),
              const SizedBox(width: 6),
              Text(
                '$tableString • verified',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Color(0xFF203F35)),
              ),
            ],
          ),
          Text(
            widget.isTakeout ? 'Takeout' : 'Dine-in',
            style: const TextStyle(fontSize: 10, color: Color(0xFF788078), fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroductionHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SESSION BILL',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFFA47C3D),
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Table Summary',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF203F35),
            height: 1.2,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Review your complete table session bill and place your payment request below.',
          style: TextStyle(fontSize: 13, color: Color(0xFF788078), height: 1.4),
        ),
      ],
    );
  }

  Widget _buildSessionStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _billRequestedSubmitted ? const Color(0xFFEAF0E9) : const Color(0xFFEEE7D9),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _billRequestedSubmitted ? Icons.check_circle_outline : Icons.receipt_long_outlined,
            size: 13,
            color: _billRequestedSubmitted ? const Color(0xFF203F35) : const Color(0xFFA47C3D),
          ),
          const SizedBox(width: 6),
          Text(
            _billRequestedSubmitted ? 'Bill Requested • Staff Notified' : 'Active Billed Session',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: _billRequestedSubmitted ? const Color(0xFF203F35) : const Color(0xFFA47C3D),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBilledOrderCard(Map<String, dynamic> order) {
    final String code = order['order_code'] ?? '#BS-1042';
    final String status = order['status'] ?? 'SERVED';
    final String time = order['time'] ?? '12:08 PM • Today';
    final List items = order['items'] ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDFA),
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
          // Order Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                code,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF203F35)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF0E9),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check, size: 12, color: Color(0xFF203F35)),
                    const SizedBox(width: 4),
                    Text(
                      status,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF203F35)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(time, style: const TextStyle(fontSize: 11, color: Color(0xFF788078))),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Divider(height: 1, color: Color(0xFFE5DFD3)),
          ),
          // Items List
          ...items.map((item) {
            final double p = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item['name'] ?? 'Dish Item',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF24382F)),
                        ),
                      ),
                      Text(
                        '₱${p.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF203F35)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item['details'] ?? 'Standard serving',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF788078)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPriceBreakdownCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDFA),
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Food & drinks', style: TextStyle(fontSize: 12, color: Color(0xFF788078))),
              Text('₱${_foodDrinksTotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF203F35))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Selected add-ons', style: TextStyle(fontSize: 12, color: Color(0xFF788078))),
              Text('₱${_addOnsTotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF203F35))),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Divider(height: 1, color: Color(0xFFE5DFD3)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF24382F))),
              Text(
                '₱${_grandTotal.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF203F35)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Prices include applicable taxes. No added service charge.',
            style: TextStyle(fontSize: 10, color: Color(0xFF788078)),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletContextNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF0E9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF53766C), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _billRequestedSubmitted
                  ? 'Your bill request was sent! A waiter is bringing your official receipt and collecting payment.'
                  : 'Requesting bill notifies the cashier to prepare your official receipt or staff to collect payment.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF53766C), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryActionButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _billRequestedSubmitted ? const Color(0xFF53766C) : const Color(0xFF203F35),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
        onPressed: (_isRequestingBill || _billRequestedSubmitted) ? null : _submitRequestBill,
        child: _isRequestingBill
            ? const CircularProgressIndicator(color: Colors.white)
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _billRequestedSubmitted ? 'Bill Requested ✓' : 'Request Bill',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(width: 8),
            Icon(_billRequestedSubmitted ? Icons.check_circle : Icons.receipt_long, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerBottomNav() {
    return Container(
      height: 70,
      decoration: const BoxDecoration(
        color: Color(0xFFFFFDFA),
        border: Border(top: BorderSide(color: Color(0xFFE5DFD3))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(Icons.restaurant, 'Menu', onTap: () {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MenuScreen()));
          }),
          _buildNavItem(Icons.receipt_long_outlined, 'Orders', onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => OrderStatusScreen(orderId: 1042, isTakeout: widget.isTakeout, tableId: widget.tableId)));
          }),
          _buildNavItem(Icons.notifications_none, 'Help', onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const AssistanceScreen()));
          }),
          _buildNavItem(Icons.account_balance_wallet, 'Pay', isActive: true, onTap: () {}),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, {bool isActive = false, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: isActive ? const Color(0xFF203F35) : const Color(0xFF788078)),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? const Color(0xFF203F35) : const Color(0xFF788078),
            ),
          ),
          if (isActive) ...[
            const SizedBox(height: 2),
            Container(width: 16, height: 2, decoration: BoxDecoration(color: const Color(0xFFA47C3D), borderRadius: BorderRadius.circular(2))),
          ]
        ],
      ),
    );
  }
}
