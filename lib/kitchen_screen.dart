import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'dart:convert';

class KitchenScreen extends StatefulWidget {
  final String? authToken;
  const KitchenScreen({super.key, this.authToken});

  @override
  State<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends State<KitchenScreen> {
  List<Map<String, dynamic>> _kitchenOrders = [];
  bool _isLoading = true;
  late io.Socket _socket;

  @override
  void initState() {
    super.initState();
    _fetchActiveOrders();
    _initSocketListener();
  }

  void _initSocketListener() {
    _socket = io.io('http://localhost:5000', io.OptionBuilder().setTransports(['websocket']).disableAutoConnect().build());
    _socket.connect();

    _socket.on('new_order', (_) {
      if (mounted) _fetchActiveOrders();
    });

    _socket.on('order_status_updated', (_) {
      if (mounted) _fetchActiveOrders();
    });
  }

  @override
  void dispose() {
    _socket.disconnect();
    _socket.dispose();
    super.dispose();
  }

  Future<void> _fetchActiveOrders() async {
    try {
      final headers = <String, String>{};
      if (widget.authToken != null && widget.authToken!.isNotEmpty) {
        headers['Authorization'] = 'Bearer ${widget.authToken}';
      }

      final response = await http.get(
        Uri.parse('http://localhost:5000/api/v1/orders'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        final List<dynamic> list = resData['data'] ?? [];
        setState(() {
          _kitchenOrders = List<Map<String, dynamic>>.from(list);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateOrderStatus(int orderId, String newStatus) async {
    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (widget.authToken != null && widget.authToken!.isNotEmpty) {
        headers['Authorization'] = 'Bearer ${widget.authToken}';
      }

      final response = await http.patch(
        Uri.parse('http://localhost:5000/api/v1/orders/$orderId/status'),
        headers: headers,
        body: jsonEncode({
          'status': newStatus,
          if (newStatus == 'DECLINED') 'decline_reason': 'Kitchen busy / Out of stock'
        }),
      );

      if (response.statusCode == 200) {
        _fetchActiveOrders();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ticket #$orderId updated to $newStatus')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update ticket status: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Kitchen Display System (KDS)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF00CEC9)),
            onPressed: _fetchActiveOrders,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD67D41)))
          : _kitchenOrders.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_outlined, size: 64, color: Colors.white24),
            SizedBox(height: 16),
            Text('No pending kitchen orders.', style: TextStyle(color: Colors.white60, fontSize: 16)),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _kitchenOrders.length,
        itemBuilder: (context, idx) {
          final order = _kitchenOrders[idx];
          final int orderId = order['order_id'] ?? order['id'] ?? 0;
          final int tableNum = order['table_number'] ?? order['table_id'] ?? 0;
          final String status = (order['order_status'] ?? 'PENDING').toString().toUpperCase();
          final List items = order['items'] ?? [];

          Color badgeColor = const Color(0xFFEAB308);
          if (status == 'PREPARING') badgeColor = const Color(0xFF3B82F6);
          if (status == 'READY' || status == 'SERVED') badgeColor = const Color(0xFF22C55E);

          return Card(
            color: const Color(0xFF1E293B),
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.white10)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Ticket #$orderId  •  Table #$tableNum',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                        child: Text(
                          status,
                          style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      )
                    ],
                  ),
                  const Divider(color: Colors.white10, height: 24),
                  ...items.map((item) {
                    final String name = item['name'] ?? 'Item';
                    final int qty = item['quantity'] ?? item['qty'] ?? 1;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFD67D41), borderRadius: BorderRadius.circular(6)),
                            child: Text('${qty}x', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(name, style: const TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w500)),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      if (status == 'PENDING')
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.soup_kitchen, color: Colors.white, size: 18),
                            label: const Text('Start Preparing', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD67D41),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => _updateOrderStatus(orderId, 'PREPARING'),
                          ),
                        ),
                      if (status == 'PREPARING')
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                            label: const Text('Mark Served / Ready', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF22C55E),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => _updateOrderStatus(orderId, 'SERVED'),
                          ),
                        ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.cancel_outlined, color: Color(0xFFFF7675)),
                        onPressed: () => _updateOrderStatus(orderId, 'DECLINED'),
                      )
                    ],
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
