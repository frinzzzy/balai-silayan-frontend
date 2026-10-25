import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'dart:convert';

import 'assistance_screen.dart';
import 'config/api_config.dart';

class OrdersScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;
  final String? authToken;

  const OrdersScreen({super.key, required this.cartItems, this.authToken});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  bool _isLoading = true;
  String _activeFilter = 'ALL';
  List<Map<String, dynamic>> _liveOrdersList = [];
  final List<Map<String, dynamic>> _recentPaidOrders = [];
  late io.Socket _socket;

  String get _baseUrl => ApiConfig.baseUrl;

  @override
  void initState() {
    super.initState();
    _fetchLiveCashierOrders();
    _connectLiveMonitoring();
  }

  void _connectLiveMonitoring() {
    _socket = io.io(
      _baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .build(),
    );
    _socket.onConnect((_) {
      _socket.emit('join_room', 'admin_live_monitoring');
    });
    _socket.on('order_updated', _handleLiveMonitoringUpdate);
    _socket.connect();
  }

  void _handleLiveMonitoringUpdate(dynamic event) {
    if (!mounted || event is! Map) return;
    final String status = (event['status'] ?? event['order_status'] ?? '')
        .toString()
        .toUpperCase();
    if (status == 'COMPLETED') {
      final int? id = int.tryParse(
        (event['order_id'] ?? event['id'] ?? '').toString(),
      );
      if (id == null) return;
      setState(() {
        _recentPaidOrders.removeWhere((order) => order['id'] == id);
        _recentPaidOrders.insert(0, {
          'id': id,
          'order_code': '#BS-$id',
          'table_number': event['table_number'] ?? event['table_id'] ?? 0,
          'status': 'PAID',
          'total':
              double.tryParse(event['total_amount']?.toString() ?? '0') ?? 0.0,
          'items': event['items'] is List ? event['items'] : [],
          'time': 'Just now',
        });
        if (_recentPaidOrders.length > 10) _recentPaidOrders.removeLast();
        _liveOrdersList = [
          ..._recentPaidOrders,
          ..._liveOrdersList.where((order) => order['id'] != id),
        ];
      });
      return;
    }
    _fetchLiveCashierOrders();
  }

  @override
  void dispose() {
    _socket.disconnect();
    _socket.dispose();
    super.dispose();
  }

  Future<void> _fetchLiveCashierOrders() async {
    try {
      final headers = <String, String>{};
      if (widget.authToken != null && widget.authToken!.isNotEmpty) {
        headers['Authorization'] = 'Bearer ${widget.authToken}';
      }
      final response = await http.get(
        Uri.parse('$_baseUrl/api/v1/orders'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        final List<dynamic> dataList = resData['data'] ?? [];
        if (mounted) {
          final mapped = dataList.map((o) {
            final int id = o['order_id'] ?? o['id'] ?? 0;
            final String code = o['order_code'] ?? "#BS-$id";
            final int tbl = o['table_number'] ?? o['table_id'] ?? 7;
            final String status =
                (o['order_status'] ?? o['status'] ?? 'PENDING')
                    .toString()
                    .toUpperCase();
            final double tot =
                double.tryParse(
                  (o['total_amount'] ?? o['grand_total'])?.toString() ?? '0',
                ) ??
                0.0;
            final List items = (o['items'] as List? ?? []).map((item) {
              final int quantity =
                  int.tryParse(item['quantity']?.toString() ?? '') ?? 1;
              final double unitPrice =
                  double.tryParse(item['unit_price']?.toString() ?? '0') ?? 0.0;
              final double addonTotal =
                  double.tryParse(item['addon_total']?.toString() ?? '0') ??
                  0.0;
              final double lineTotal =
                  double.tryParse(item['line_total']?.toString() ?? '') ??
                  (unitPrice + addonTotal) * quantity;
              return {
                ...Map<String, dynamic>.from(item as Map),
                'name': '${item['name'] ?? 'Item'} (x$quantity)',
                'price': unitPrice * quantity,
                'line_total': lineTotal,
              };
            }).toList();
            return {
              "id": id,
              "order_code": code,
              "table_number": tbl,
              "status": status,
              "total": tot,
              "items": items,
              "time": "Today",
            };
          }).toList();
          final List<Map<String, dynamic>> visibleOrders = [
            ..._recentPaidOrders.where(
              (paid) => !mapped.any((order) => order['id'] == paid['id']),
            ),
            ...mapped,
          ];

          setState(() {
            _liveOrdersList = List<Map<String, dynamic>>.from(visibleOrders);
            _isLoading = false;
          });
          return;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _liveOrdersList = List<Map<String, dynamic>>.from(_recentPaidOrders);
        _isLoading = false;
      });
    }
  }

  Future<void> _updateOrderStatus(int orderId, String newStatus) async {
    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/api/v1/orders/$orderId/status'),
        headers: {
          "Content-Type": "application/json",
          if (widget.authToken != null && widget.authToken!.isNotEmpty)
            'Authorization': 'Bearer ${widget.authToken}',
        },
        body: jsonEncode({"status": newStatus}),
      );
      if (response.statusCode != 200) {
        throw Exception('Status update failed (${response.statusCode}).');
      }
      await _fetchLiveCashierOrders();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update order: $error')),
        );
      }
      return;
    }

    if (mounted) {
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
        title: const Text(
          'Cashier & POS Station',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF203F35),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF203F35)),
            onPressed: _fetchLiveCashierOrders,
          ),
          IconButton(
            icon: const Icon(
              Icons.notifications_outlined,
              color: Color(0xFF203F35),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AssistanceScreen()),
            ),
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
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF203F35),
                      ),
                    )
                  : filtered.isEmpty
                  ? const Center(
                      child: Text('No orders match this status filter.'),
                    )
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
              side: BorderSide(
                color: isSelected
                    ? const Color(0xFF203F35)
                    : const Color(0xFFE5DFD3),
              ),
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
    final double total =
        double.tryParse(order['total']?.toString() ?? '0') ?? 0.0;
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
                    'TABLE SESSION RECEIPT',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF53766C),
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    code,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF203F35),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: badgeFg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Table #$tableNum • Dine-In',
            style: const TextStyle(fontSize: 12, color: Color(0xFF788078)),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10.0),
            child: Divider(height: 1, color: Color(0xFFE5DFD3)),
          ),
          ...items.map((item) {
            final double p =
                double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
            final List addons = item['addons'] is List
                ? item['addons'] as List
                : const [];
            final int quantity =
                int.tryParse(item['quantity']?.toString() ?? '') ?? 1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item['name'] ?? 'Item',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF24382F),
                          ),
                        ),
                      ),
                      Text(
                        '₱${p.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF203F35),
                        ),
                      ),
                    ],
                  ),
                  ...addons.map((addon) {
                    final double addonPrice =
                        double.tryParse(addon['price']?.toString() ?? '0') ??
                        0.0;
                    return Padding(
                      padding: const EdgeInsets.only(left: 8, top: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '+ ${addon['name'] ?? 'Add-on'}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF53766C),
                              ),
                            ),
                          ),
                          Text(
                            '₱${(addonPrice * quantity).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF53766C),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
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
              const Text(
                'Total Amount',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF24382F),
                ),
              ),
              Text(
                '₱${total.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF203F35),
                ),
              ),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => _updateOrderStatus(id, 'PREPARING'),
                    child: const Text(
                      'Accept & Prepare',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              if (status == 'PREPARING')
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF203F35),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => _updateOrderStatus(id, 'SERVED'),
                    child: const Text(
                      'Mark Served',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              if (status == 'SERVED')
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF53766C),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => _updateOrderStatus(id, 'PAID'),
                    child: const Text(
                      'Mark Paid & Close',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
