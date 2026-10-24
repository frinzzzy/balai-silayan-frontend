import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'dart:convert';

import 'menu_screen.dart';
import 'assistance_screen.dart';
import 'order_status_screen.dart';
import 'bill_requested_screen.dart';
import 'user_session.dart';

class SessionBillScreen extends StatefulWidget {
  final int? tableId;
  final bool isTakeout;

  const SessionBillScreen({super.key, this.tableId, this.isTakeout = false});

  @override
  State<SessionBillScreen> createState() => _SessionBillScreenState();
}

class _SessionBillScreenState extends State<SessionBillScreen> {
  bool _isLoading = true;
  bool _isRequestingBill = false;
  bool _billRequestedSubmitted = false;
  String? _errorMessage;
  late io.Socket _socket;

  double _foodDrinksTotal = 0.0;
  double _addOnsTotal = 0.0;
  double _grandTotal = 0.0;
  List<Map<String, dynamic>> _sessionOrders = [];
  String _orderStatus = 'PENDING';
  String _sessionStatus = 'ACTIVE';

  String get _baseUrl {
    if (kIsWeb) return 'http://localhost:5000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5000';
    }
    return 'http://localhost:5000';
  }

  @override
  void initState() {
    super.initState();
    _fetchSessionBillData();
    _connectOrderUpdates();
  }

  void _connectOrderUpdates() {
    _socket = io.io(
      _baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );
    _socket.onConnect((_) {
      final int? sessionId =
          UserSession.activeSessionId ??
              int.tryParse(UserSession.sessionId ?? '');
      if (sessionId != null) _socket.emit('join_room', 'session_$sessionId');
    });
    _socket.on('order_updated', (event) {
      if (!mounted || event is! Map) return;
      final int? eventSessionId = int.tryParse(
        (event['session_id'] ?? '').toString(),
      );
      final int? activeSessionId =
          UserSession.activeSessionId ??
              int.tryParse(UserSession.sessionId ?? '');
      if (eventSessionId == activeSessionId) {
        _fetchSessionBillData(refresh: true);
      }
    });
    _socket.on('additional_items_added', (event) {
      if (!mounted || event is! Map) return;
      final int? eventSessionId = int.tryParse(
        (event['session_id'] ?? '').toString(),
      );
      final int? activeSessionId =
          UserSession.activeSessionId ??
              int.tryParse(UserSession.sessionId ?? '');
      if (eventSessionId == activeSessionId || eventSessionId == null) {
        _fetchSessionBillData(refresh: true);
      }
    });
    _socket.on('table_session_closed', (event) {
      if (!mounted || event is! Map) return;
      final int? eventSessionId = int.tryParse(
        (event['session_id'] ?? '').toString(),
      );
      final int? activeSessionId =
          UserSession.activeSessionId ??
              int.tryParse(UserSession.sessionId ?? '');
      if (eventSessionId == activeSessionId && mounted) {
        setState(() => _sessionStatus = 'CLOSED');
      }
    });
    _socket.connect();
  }

  @override
  void dispose() {
    _socket.disconnect();
    _socket.dispose();
    super.dispose();
  }

  double _parseDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) {
      return double.tryParse(val) ?? 0.0;
    }
    return 0.0;
  }

  // Kinukuwenta muli ang total batay lamang sa mga napiling (checked) tickets
  void _recalculateTotals() {
    double computedGrandTotal = 0.0;
    double computedFoodTotal = 0.0;
    double computedAddOnsTotal = 0.0;

    for (var order in _sessionOrders) {
      if (order['isSelected'] == true) {
        double orderTotal = _parseDouble(order['order_total']);
        computedGrandTotal += orderTotal;

        final List items = order['items'] ?? [];
        for (var item in items) {
          double unitPrice = _parseDouble(item['unit_price']);
          int qty = item['quantity'] ?? 1;
          double addonTotal = _parseDouble(item['addon_total']);

          computedFoodTotal += (unitPrice * qty);
          computedAddOnsTotal += (addonTotal * qty);
        }
      }
    }

    setState(() {
      _grandTotal = computedGrandTotal;
      _foodDrinksTotal = computedFoodTotal > 0 ? computedFoodTotal : computedGrandTotal;
      _addOnsTotal = computedAddOnsTotal;
    });
  }

  Future<void> _fetchSessionBillData({bool refresh = false}) async {
    final int tableNum = widget.tableId ?? UserSession.activeTableId ?? UserSession.activeTableNumber ?? 1;
    final Uri requestUri = Uri.parse('$_baseUrl/api/v1/tables/$tableNum/bill');

    setState(() {
      if (!refresh) _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http
          .get(requestUri, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        final data = resData['data'];

        if (data != null && mounted) {
          final List rawOrders = data['orders'] ?? [];
          final List rawSessionItems = data['items'] ?? [];

          List<Map<String, dynamic>> parsedOrders = [];

          for (var o in rawOrders) {
            double orderSum = 0.0;
            final String orderId = (o['id'] ?? o['order_id'] ?? '').toString();
            final List nestedItems = o['items'] is List ? o['items'] : [];
            List itemsList = nestedItems.isNotEmpty
                ? nestedItems
                : rawSessionItems
                .where(
                  (item) =>
              (item['order_id'] ?? '').toString() == orderId,
            )
                .toList();
            List<Map<String, dynamic>> parsedItems = [];

            if (itemsList.isNotEmpty) {
              for (var i in itemsList) {
                double rawPrice = _parseDouble(i['unit_price'] ?? i['price']);
                int qty = i['quantity'] ?? 1;
                double addonUnitTotal = _parseDouble(i['addon_total']);
                if (addonUnitTotal == 0 && i['addons'] is List) {
                  addonUnitTotal = (i['addons'] as List).fold<double>(
                    0,
                        (sum, addon) => sum + _parseDouble(addon['price']),
                  );
                }
                final double lineFoodTotal = rawPrice * qty;
                final double lineAddOnsTotal = addonUnitTotal * qty;
                double lineItemTotal = _parseDouble(i['subtotal']);
                if (lineItemTotal <= 0) {
                  lineItemTotal = lineFoodTotal + lineAddOnsTotal;
                }
                orderSum += lineItemTotal;

                parsedItems.add({
                  "name": i['name'] ?? 'Item',
                  "quantity": qty,
                  "unit_price": rawPrice,
                  "addon_total": addonUnitTotal,
                  "line_total": lineItemTotal,
                  "addons": i['addons'] is List ? i['addons'] : const [],
                  "details": i['details'] ?? "Standard serving",
                });
              }
            }

            double recordedOrderTotal = _parseDouble(
              o['total_amount'] ?? o['order_total'],
            );
            double finalOrderTotal = recordedOrderTotal > 0
                ? recordedOrderTotal
                : orderSum;

            String rawOrderCode =
            (o['client_order_id'] ?? o['id'] ?? o['order_id'] ?? 'ORD')
                .toString();
            String formattedCode = rawOrderCode.length > 8
                ? '#${rawOrderCode.substring(0, 8).toUpperCase()}'
                : '#ORD-$rawOrderCode';

            parsedOrders.add({
              "order_code": formattedCode,
              "status": o['order_status'] ?? o['status'] ?? "PENDING",
              "time": o['created_at'] != null
                  ? DateTime.parse(o['created_at'])
                  .toLocal()
                  .toString()
                  .substring(11, 16)
                  : "01:53",
              "items": parsedItems,
              "order_total": finalOrderTotal,
              "isSelected": true, // Naka-select by default ang bawat ticket
            });
          }

          setState(() {
            _sessionOrders = parsedOrders;
            _sessionStatus = (data['session_status'] ?? 'ACTIVE')
                .toString()
                .toUpperCase();
            _orderStatus = parsedOrders.isEmpty
                ? 'PENDING'
                : parsedOrders.first['status'].toString().toUpperCase();
            _isLoading = false;
          });

          // Kalkulahin ang kabuuang halaga batay sa mga napiling tickets
          _recalculateTotals();
          return;
        }
      }

      setState(() {
        _errorMessage = "Failed to load bill (Status: ${response.statusCode})";
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Could not connect to backend endpoint.";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _submitRequestBill() async {
    setState(() => _isRequestingBill = true);
    final int tableNum = widget.tableId ?? UserSession.activeTableId ?? 1;

    try {
      await http.get(
        Uri.parse('$_baseUrl/api/v1/tables/$tableNum/bill'),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isRequestingBill = false;
        _billRequestedSubmitted = true;
      });
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => BillRequestedScreen(
            tableId: tableNum,
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
    final int tableNum = widget.tableId ?? UserSession.activeTableId ?? 1;
    final String tableString = widget.isTakeout
        ? 'Takeout'
        : 'Table ${tableNum.toString().padLeft(2, '0')}';

    // Sinisigurong may naiwang selected o may laman para ma-enable ang button
    final bool hasSelectedOrders = _sessionOrders.any((o) => o['isSelected'] == true);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F4EC),
      body: SafeArea(
        child: Column(
          children: [
            _buildRestaurantHeader(),
            _buildTableContextStrip(tableString),
            Expanded(
              child: _isLoading
                  ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF203F35),
                ),
              )
                  : _errorMessage != null
                  ? _buildErrorView()
                  : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 16.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildIntroductionHeader(),
                    const SizedBox(height: 12),
                    _buildSessionStatusBadge(),
                    const SizedBox(height: 20),
                    if (_sessionOrders.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text(
                            "No active orders found in session.",
                            style: TextStyle(color: Color(0xFF788078)),
                          ),
                        ),
                      )
                    else
                      ..._sessionOrders.asMap().entries.map(
                            (entry) => _buildBilledOrderCard(entry.value, entry.key),
                      ),
                    const SizedBox(height: 12),
                    _buildPriceBreakdownCard(),
                    const SizedBox(height: 16),
                    _buildWalletContextNote(),
                    const SizedBox(height: 24),
                    _buildPrimaryActionButton(hasSelectedOrders),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildCustomerBottomNav(tableNum),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, size: 48, color: Color(0xFFA47C3D)),
          const SizedBox(height: 12),
          Text(
            _errorMessage ?? "Database connection error",
            style: const TextStyle(fontSize: 14, color: Color(0xFF203F35)),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF203F35),
            ),
            onPressed: _fetchSessionBillData,
            child: const Text(
              "Retry Connection",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
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
              child: const Icon(
                Icons.arrow_back,
                color: Color(0xFF203F35),
                size: 20,
              ),
            ),
          ),
          const Column(
            children: [
              Icon(Icons.home_outlined, size: 18, color: Color(0xFFA47C3D)),
              SizedBox(height: 4),
              Text(
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
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AssistanceScreen()),
            ),
            borderRadius: BorderRadius.circular(22),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE5DFD3)),
              ),
              child: const Icon(
                Icons.notifications_outlined,
                color: Color(0xFF203F35),
                size: 20,
              ),
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
              const Icon(
                Icons.check_circle_outline,
                size: 14,
                color: Color(0xFF53766C),
              ),
              const SizedBox(width: 6),
              Text(
                '$tableString • verified',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  color: Color(0xFF203F35),
                ),
              ),
            ],
          ),
          Text(
            widget.isTakeout ? 'Takeout' : 'Dine-in',
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF788078),
              fontWeight: FontWeight.w500,
            ),
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
          'Piliin ang mga ticket o order na gustong hingian ng bill at bayaran nang hiwalay.',
          style: TextStyle(fontSize: 13, color: Color(0xFF788078), height: 1.4),
        ),
      ],
    );
  }

  Widget _buildSessionStatusBadge() {
    final bool isPaid = _orderStatus == 'COMPLETED';
    final bool isClosed = _sessionStatus == 'CLOSED';
    final String statusText = isPaid
        ? 'Paid • Session Closed'
        : isClosed
        ? 'Session Closed'
        : _billRequestedSubmitted
        ? 'Bill Requested'
        : 'Active Session';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isPaid || isClosed || _billRequestedSubmitted
            ? const Color(0xFFEAF0E9)
            : const Color(0xFFEEE7D9),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPaid || isClosed || _billRequestedSubmitted
                ? Icons.check_circle_outline
                : Icons.receipt_long_outlined,
            size: 13,
            color: isPaid || isClosed || _billRequestedSubmitted
                ? const Color(0xFF203F35)
                : const Color(0xFFA47C3D),
          ),
          const SizedBox(width: 6),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isPaid || isClosed || _billRequestedSubmitted
                  ? const Color(0xFF203F35)
                  : const Color(0xFFA47C3D),
            ),
          ),
        ],
      ),
    );
  }

  // Bawat order card ay pwedeng i-check o i-uncheck ng customer para sa hiwalay na pagbabayad
  Widget _buildBilledOrderCard(Map<String, dynamic> order, int index) {
    final String code = order['order_code'] ?? '#ORD';
    final String status = (order['status'] ?? 'PENDING').toString().toUpperCase();
    final bool isPending = status == 'PENDING';
    final String time = order['time'] ?? '01:53';
    final List items = order['items'] ?? [];
    final bool isSelected = order['isSelected'] ?? true;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDFA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected ? const Color(0xFFA47C3D) : const Color(0xFFE5DFD3),
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: CheckboxListTile(
        value: isSelected,
        activeColor: const Color(0xFF203F35),
        checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onChanged: (bool? value) {
          setState(() {
            _sessionOrders[index]['isSelected'] = value ?? true;
          });
          _recalculateTotals();
        },
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  code,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF203F35),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isPending
                        ? const Color(0xFFEEE7D9)
                        : const Color(0xFFEAF0E9),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isPending ? Icons.access_time : Icons.check,
                        size: 12,
                        color: isPending
                            ? const Color(0xFFA47C3D)
                            : const Color(0xFF203F35),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        status,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isPending
                              ? const Color(0xFFA47C3D)
                              : const Color(0xFF203F35),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: const TextStyle(fontSize: 11, color: Color(0xFF788078)),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: Divider(height: 1, color: Color(0xFFE5DFD3)),
            ),
            ...items.map((item) {
              final int quantity =
                  int.tryParse(item['quantity']?.toString() ?? '') ?? 1;
              final double unitPrice = _parseDouble(
                item['unit_price'] ?? item['price'],
              );
              final double addonTotal = _parseDouble(item['addon_total']);
              final double lineTotal = _parseDouble(item['line_total']) > 0
                  ? _parseDouble(item['line_total'])
                  : (unitPrice + addonTotal) * quantity;
              final List addons = item['addons'] is List
                  ? item['addons'] as List
                  : const [];
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
                            '${item['name'] ?? 'Item'} (x$quantity)',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF24382F),
                            ),
                          ),
                        ),
                        Text(
                          '₱${lineTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF203F35),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₱${unitPrice.toStringAsFixed(2)} each',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF788078),
                      ),
                    ),
                    ...addons.map(
                          (addon) => Padding(
                        padding: const EdgeInsets.only(left: 8, top: 2),
                        child: Text(
                          '+ ${addon['name'] ?? 'Add-on'} · ₱${_parseDouble(addon['price']).toStringAsFixed(2)} each',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF53766C),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
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
              const Text(
                'Food & drinks (Selected)',
                style: TextStyle(fontSize: 12, color: Color(0xFF788078)),
              ),
              Text(
                '₱${_foodDrinksTotal.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF203F35),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Selected add-ons',
                style: TextStyle(fontSize: 12, color: Color(0xFF788078)),
              ),
              Text(
                '₱${_addOnsTotal.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF203F35),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Divider(height: 1, color: Color(0xFFE5DFD3)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Selected Total',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF24382F),
                ),
              ),
              Text(
                '₱${_grandTotal.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF203F35),
                ),
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
          const Icon(
            Icons.account_balance_wallet_outlined,
            color: Color(0xFF53766C),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _billRequestedSubmitted
                  ? 'Your bill request was sent for the selected tickets! A waiter is bringing your receipt.'
                  : 'Piliin ang mga ticket sa itaas para sa hiwalay na paghingi ng bill o pagbayad.',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF53766C),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryActionButton(bool hasSelectedOrders) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: (!hasSelectedOrders ||
              _isRequestingBill ||
              _billRequestedSubmitted ||
              _sessionStatus == 'CLOSED' ||
              _orderStatus == 'COMPLETED')
              ? const Color(0xFF788078)
              : const Color(0xFF203F35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
        ),
        onPressed: (!hasSelectedOrders ||
            _isRequestingBill ||
            _billRequestedSubmitted ||
            _sessionStatus == 'CLOSED' ||
            _orderStatus == 'COMPLETED')
            ? null
            : _submitRequestBill,
        child: _isRequestingBill
            ? const CircularProgressIndicator(color: Colors.white)
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _orderStatus == 'COMPLETED'
                  ? 'Paid ✓'
                  : _sessionStatus == 'CLOSED'
                  ? 'Session Closed'
                  : _billRequestedSubmitted
                  ? 'Bill Requested ✓'
                  : 'Request Bill for Selected',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              _billRequestedSubmitted ||
                  _sessionStatus == 'CLOSED' ||
                  _orderStatus == 'COMPLETED'
                  ? Icons.check_circle
                  : Icons.receipt_long,
              color: Colors.white,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerBottomNav(int tableNum) {
    return Container(
      height: 70,
      decoration: const BoxDecoration(
        color: Color(0xFFFFFDFA),
        border: Border(top: BorderSide(color: Color(0xFFE5DFD3))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
            Icons.restaurant,
            'Menu',
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const MenuScreen()),
              );
            },
          ),
          _buildNavItem(
            Icons.track_changes,
            'Live Status',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OrderStatusScreen(
                    orderId: UserSession.lastPlacedOrderId ?? 1042,
                    isTakeout: widget.isTakeout,
                    tableId: tableNum,
                    isAdditionalOrder: UserSession.isAdditionalOrder,
                  ),
                ),
              );
            },
          ),
          _buildNavItem(
            Icons.account_balance_wallet,
            'Pay',
            isActive: true,
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
      IconData icon,
      String label, {
        bool isActive = false,
        required VoidCallback onTap,
      }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 20,
            color: isActive ? const Color(0xFF203F35) : const Color(0xFF788078),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive
                  ? const Color(0xFF203F35)
                  : const Color(0xFF788078),
            ),
          ),
          if (isActive) ...[
            const SizedBox(height: 2),
            Container(
              width: 16,
              height: 2,
              decoration: BoxDecoration(
                color: const Color(0xFFA47C3D),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}