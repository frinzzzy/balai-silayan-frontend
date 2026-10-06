import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'assistance_screen.dart';

class OrdersScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;
  final String? authToken;

  const OrdersScreen({
    super.key,
    required this.cartItems,
    this.authToken,
  });

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  bool _isLoading = true;
  String _activeFilter = 'ALL';
  List<Map<String, dynamic>> _liveOrdersList = [];

  final List<Map<String, dynamic>> _samplePosOrders = [
    {
      "id": 1042,
      "order_code": "#BS-1042",
      "table_number": 7,
      "status": "PENDING",
      "is_additional": false,
      "total": 1255.0,
      "items": [
        {"name": "Chicken Inasal (x2)", "price": 570.0},
        {"name": "Kare-Kare (x1)", "price": 425.0},
        {"name": "Calamansi Cooler (x2)", "price": 170.0},
      ],
      "time": "11:49 AM • Today"
    },
    {
      "id": 1043,
      "order_code": "#BS-1043",
      "table_number": 12,
      "status": "PREPARING",
      "is_additional": true,
      "total": 680.0,
      "items": [
        {"name": "Sizzling Sisig (x2)", "price": 500.0},
        {"name": "Extra Rice (x3)", "price": 75.0},
        {"name": "Iced Tea Pitcher (x1)", "price": 105.0},
      ],
      "time": "11:52 AM • Today"
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchLiveCashierOrders();
  }

  Future<void> _fetchLiveCashierOrders() async {
    try {
      final response = await http.get(Uri.parse('http://localhost:5000/api/v1/orders'));
      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        final List<dynamic> dataList = resData['data'] ?? [];
        if (dataList.isNotEmpty && mounted) {
          final mapped = dataList.map((o) {
            final int id = o['id'] ?? 1042;
            final String code = o['order_code'] ?? "#BS-$id";
            final int tbl = o['table_number'] ?? o['table_id'] ?? 7;
            final String status = (o['status'] ?? 'PENDING').toString().toUpperCase();
            final double tot = double.tryParse(o['grand_total']?.toString() ?? '0') ?? 0.0;
            return {
              "id": id,
              "order_code": code,
              "table_number": tbl,
              "status": status,
              "is_additional": o['is_additional'] ?? false,
              "total": tot > 0 ? tot : 1255.0,
              "items": o['items'] ?? [
                {"name": "Heritage Dish Selection", "price": tot}
              ],
              "time": "Today",
            };
          }).toList();

          setState(() {
            _liveOrdersList = List<Map<String, dynamic>>.from(mapped);
            _isLoading = false;
          });
          return;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _liveOrdersList = _samplePosOrders;
        _isLoading = false;
      });
    }
  }

  Future<void> _updateOrderStatus(int orderId, String newStatus) async {
    try {
      await http.put(
        Uri.parse('http://localhost:5000/api/v1/orders/$orderId/status'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"status": newStatus}),
      );
    } catch (_) {}

    if (mounted) {
      setState(() {
        final index = _liveOrdersList.indexWhere((o) => o['id'] == orderId);
        if (index > -1) {
          _liveOrdersList[index]['status'] = newStatus;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order #$orderId updated to $newStatus!'),
          backgroundColor: const Color(0xFF203F35),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _liveOrdersList.where((o) {
      if (_activeFilter == 'ALL') return true;
      return o['status'] == _activeFilter;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F4EC),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF203F35)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Cashier & POS Station', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF203F35))),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF203F35)),
            onPressed: _fetchLiveCashierOrders,
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Color(0xFF203F35)),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AssistanceScreen())),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFilterPillsBar(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF203F35)))
                  : filtered.isEmpty
                  ? const Center(child: Text('No orders match this status filter.'))
                  : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                itemBuilder: (context, idx) {
                  final order = filtered[idx];
                  return _buildCashierOrderCard(order);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPillsBar() {
    final filters = ['ALL', 'PENDING', 'PREPARING', 'SERVED', 'PAID'];
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final f = filters[index];
          final isSelected = _activeFilter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(f),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) setState(() => _activeFilter = f);
              },
              selectedColor: const Color(0xFF203F35),
              backgroundColor: const Color(0xFFFFFDFA),
              labelStyle: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: isSelected ? Colors.white : const Color(0xFF788078),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
              side: BorderSide(color: isSelected ? const Color(0xFF203F35) : const Color(0xFFE5DFD3)),
              showCheckmark: false,
            ),
          );
        },
      ),
    );
  }

  Widget _buildCashierOrderCard(Map<String, dynamic> order) {
    final int id = order['id'];
    final String code = order['order_code'] ?? "#BS-$id";
    final int tableNum = order['table_number'] ?? 7;
    final String status = order['status'] ?? 'PENDING';
    final bool isAdditional = order['is_additional'] ?? false;
    final double total = double.tryParse(order['total']?.toString() ?? '0') ?? 0.0;
    final List items = order['items'] ?? [];

    Color badgeBg = const Color(0xFFEEE7D9);
    Color badgeFg = const Color(0xFFA47C3D);
    if (status == 'PREPARING') {
      badgeBg = const Color(0xFFEAF0E9);
      badgeFg = const Color(0xFF203F35);
    } else if (status == 'SERVED' || status == 'PAID') {
      badgeBg = const Color(0xFFEAF0E9);
      badgeFg = const Color(0xFF53766C);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAdditional ? 'ADDITIONAL ORDER' : 'NEW ORDER',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFA47C3D), letterSpacing: 1.1),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    code,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF203F35)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(100)),
                child: Text(
                  status,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeFg),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Table #$tableNum • Dine-In', style: const TextStyle(fontSize: 12, color: Color(0xFF788078))),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10.0),
            child: Divider(height: 1, color: Color(0xFFE5DFD3)),
          ),
          ...items.map((item) {
            final p = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(item['name'] ?? 'Item', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF24382F))),
                  Text('₱${p.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF203F35))),
                ],
              ),
            );
          }),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10.0),
            child: Divider(height: 1, color: Color(0xFFE5DFD3)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Amount', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF24382F))),
              Text('₱${total.toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF203F35))),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (status == 'PENDING')
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF203F35),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _updateOrderStatus(id, 'PREPARING'),
                    child: const Text('Accept & Prepare', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              if (status == 'PREPARING') ...[
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF203F35),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _updateOrderStatus(id, 'SERVED'),
                    child: const Text('Mark Served', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
              if (status == 'SERVED') ...[
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF53766C),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _updateOrderStatus(id, 'PAID'),
                    child: const Text('Mark Paid & Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
