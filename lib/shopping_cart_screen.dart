import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'dart:convert';
import 'menu_screen.dart';
import 'checkout_screen.dart';
import 'assistance_screen.dart';
import 'order_type_selection_screen.dart';
import 'user_session.dart';
import 'config/api_config.dart';

class ShoppingCartScreen extends StatefulWidget {
  final Map<FoodItem, int> cart;
  final double total;
  final int? tableId;
  final bool isTakeout;
  final bool isAdditionalOrder;

  const ShoppingCartScreen({
    super.key,
    required this.cart,
    required this.total,
    this.tableId = 7,
    this.isTakeout = false,
    this.isAdditionalOrder = false,
  });

  @override
  State<ShoppingCartScreen> createState() => _ShoppingCartScreenState();
}

class _ShoppingCartScreenState extends State<ShoppingCartScreen> {
  late Map<FoodItem, int> _editableCart;
  late double _calculatedTotal;
  bool _isLoadingParentItems = false;
  List<dynamic> _sessionOrdersSummary = [];
  double _sessionGrandTotal = 0.0;
  late io.Socket _cartSocket;
  bool _dialogShown = false;

  String get _baseUrl => ApiConfig.baseUrl;

  @override
  void initState() {
    super.initState();
    _editableCart = Map.from(widget.cart);
    _calculatedTotal = widget.total;
    if (widget.isAdditionalOrder || UserSession.isAdditionalOrder) {
      _fetchOrdersSummary();
    } else {
      _sessionOrdersSummary = [];
      _sessionGrandTotal = 0.0;
    }
    _connectCartSocket();
  }

  void _connectCartSocket() {
    try {
      _cartSocket = io.io(
        _baseUrl,
        io.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .disableAutoConnect()
            .build(),
      );

      _cartSocket.onConnect((_) {
        final int? tableId = widget.tableId ?? UserSession.activeTableId ?? UserSession.activeTableNumber;
        if (tableId != null) {
          _cartSocket.emit('join_room', 'table_$tableId');
        }
        final int? sessionId = UserSession.activeSessionId ?? int.tryParse(UserSession.sessionId ?? '');
        if (sessionId != null) {
          _cartSocket.emit('join_room', 'session_$sessionId');
        }
      });

      _cartSocket.on('order_paid', _handleTableOrderFinished);
      _cartSocket.on('table_session_closed', _handleTableOrderFinished);
      _cartSocket.on('session_cancelled', _handleTableOrderFinished);
      _cartSocket.on('order_status_updated', _handleTableOrderEvent);
      _cartSocket.on('order_updated', _handleTableOrderEvent);
      _cartSocket.connect();
    } catch (_) {}
  }

  void _handleTableOrderEvent(dynamic data) {
    if (!mounted) return;
    if (data == null) return;

    final Map<String, dynamic> payload = data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data as Map);
    final Map<String, dynamic> orderPayload = payload['order'] is Map ? Map<String, dynamic>.from(payload['order']) : payload;

    final int currentTable = widget.tableId ?? UserSession.activeTableId ?? UserSession.activeTableNumber ?? 7;
    final int? eventTableId = int.tryParse(orderPayload['table_id']?.toString() ?? orderPayload['table_number']?.toString() ?? payload['table_id']?.toString() ?? '');

    if (eventTableId != null && eventTableId != currentTable) {
      return;
    }

    final String status = (orderPayload['status'] ?? orderPayload['order_status'] ?? payload['status'] ?? payload['order_status'] ?? '').toString().toUpperCase();
    final dynamic eventOrderId = orderPayload['order_id'] ?? orderPayload['id'] ?? payload['order_id'] ?? payload['id'];
    final dynamic currentOrderId = UserSession.lastPlacedOrderId ?? UserSession.targetParentOrderId ?? UserSession.firstOrderId;

    if (eventOrderId != null && currentOrderId != null) {
      final String targetStr = currentOrderId.toString().replaceAll('#BS-', '').trim();
      final String eventStr = eventOrderId.toString().replaceAll('#BS-', '').trim();
      final int? targetInt = int.tryParse(targetStr);
      final int? eventInt = int.tryParse(eventStr);
      bool isSame = (targetStr == eventStr) || (targetInt != null && eventInt != null && targetInt == eventInt);
      if (!isSame) {
        return;
      }
    }

    if (status == 'COMPLETED' || status == 'PAID' || status == 'CLOSED' || status == 'SETTLED') {
      _handleTableOrderFinished(payload);
    } else if (status == 'DECLINED' || status == 'REJECTED') {
      final String reason = (orderPayload['decline_reason'] ?? orderPayload['reason'] ?? payload['decline_reason'] ?? payload['reason'] ?? 'Item Out of Stock').toString();
      _showCartOrderDeclinedDialog(reason, orderPayload['order_code'] ?? '#BS-${eventOrderId ?? ""}');
    }
  }

  bool _cartDeclinedDialogShown = false;

  void _showCartOrderDeclinedDialog(String declineReason, String orderCode) {
    if (_cartDeclinedDialogShown || !mounted) return;
    _cartDeclinedDialogShown = true;

    final int currentTable = widget.tableId ?? UserSession.activeTableId ?? UserSession.activeTableNumber ?? 7;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFFDFA),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Order Declined', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pasensya na po, ang inyong order ($orderCode) ay na-decline ng kitchen/admin.',
              style: const TextStyle(fontSize: 13, color: Color(0xFF203F35), height: 1.4),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Text(
                'Reason: $declineReason',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B3B2B)),
            onPressed: () {
              Navigator.pop(ctx);
              UserSession.clearSession();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => OrderTypeSelectionScreen(
                    tableId: currentTable,
                    tableNumber: currentTable,
                  ),
                ),
                (route) => false,
              );
            },
            child: const Text('Acknowledge / Back to Menu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _handleTableOrderFinished(dynamic data) {
    if (!mounted) return;

    final int currentTable = widget.tableId ?? UserSession.activeTableId ?? UserSession.activeTableNumber ?? 7;
    int? eventTableId;
    dynamic eventOrderId;
    if (data is Map) {
      eventTableId = int.tryParse(data['table_id']?.toString() ?? '');
      eventOrderId = data['order_id'] ?? data['id'];
    }

    if (eventTableId != null && eventTableId != currentTable) {
      return;
    }

    final dynamic currentOrderId = UserSession.lastPlacedOrderId ?? UserSession.targetParentOrderId ?? UserSession.firstOrderId;
    final String orderCode = data is Map ? (data['order_code']?.toString() ?? '#BS-${eventOrderId ?? ""}').trim() : 'Ticket';

    if (eventOrderId != null && currentOrderId != null && eventOrderId.toString() != currentOrderId.toString()) {
      return;
    }

    if (_dialogShown) return;
    _dialogShown = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFFDFA),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Order Finished', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF203F35))),
        content: Text('Order $orderCode is done and has been settled.'),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF203F35)),
            onPressed: () {
              Navigator.pop(ctx);
              UserSession.clearSession();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => OrderTypeSelectionScreen(
                    tableId: currentTable,
                    tableNumber: currentTable,
                  ),
                ),
                (route) => false,
              );
            },
            child: const Text('Back to Selection', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    try {
      _cartSocket.disconnect();
      _cartSocket.dispose();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _fetchOrdersSummary() async {
    final sessionId = UserSession.activeSessionId ?? int.tryParse(UserSession.sessionId ?? '');
    final sessionToken = UserSession.customerSessionToken ?? UserSession.authToken ?? UserSession.qrToken;
    if (sessionId == null) return;

    setState(() => _isLoadingParentItems = true);

    try {
      final Map<String, String> headers = {"Content-Type": "application/json"};
      if (sessionToken != null && sessionToken.isNotEmpty) {
        headers["Authorization"] = "Bearer $sessionToken";
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/api/v1/customer/sessions/$sessionId/bill'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        final data = resData['data'];
        if (data != null) {
          final List orders = data['orders'] ?? data['orders_summary'] ?? [];
          final double grandTotal = double.tryParse(data['grand_total']?.toString() ?? '0') ?? 0.0;

          setState(() {
            _sessionOrdersSummary = orders;
            _sessionGrandTotal = grandTotal;
          });
        }
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _isLoadingParentItems = false);
    }
  }

  void _recalculateTotal() {
    setState(() {
      _calculatedTotal = _editableCart.entries.fold(
        0.0,
        (sum, entry) => sum + (entry.key.price * entry.value),
      );
    });
  }

  void _updateQuantity(FoodItem item, int delta) {
    setState(() {
      final currentQty = _editableCart[item] ?? 0;
      final newQty = currentQty + delta;
      if (newQty <= 0) {
        _editableCart.remove(item);
      } else {
        _editableCart[item] = newQty;
      }
      _recalculateTotal();
    });
  }

  void _removeItem(FoodItem item) {
    setState(() {
      _editableCart.remove(item);
      _recalculateTotal();
    });
  }

  int get _totalItemCount => _editableCart.values.fold(0, (sum, qty) => sum + qty);

  @override
  Widget build(BuildContext context) {
    final int tableNum = widget.tableId ?? 7;
    final String tableString = widget.isTakeout ? 'Takeout' : 'Table ${tableNum.toString().padLeft(2, '0')}';
    final bool isAdditional = widget.isAdditionalOrder || UserSession.isAdditionalOrder;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F4EC),
      body: SafeArea(
        child: Column(
          children: [
            _buildRestaurantHeader(),
            _buildTableContextStrip(tableString),
            Expanded(
              child: _isLoadingParentItems
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF203F35)),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildIntroductionHeader(),
                          const SizedBox(height: 20),
                          if (isAdditional && _sessionOrdersSummary.isNotEmpty) ...[
                            const Text(
                              'Active Table Tickets',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF203F35)),
                            ),
                            const SizedBox(height: 12),
                            ..._sessionOrdersSummary.asMap().entries.map((entry) {
                              final index = entry.key;
                              final order = entry.value;
                              return _buildTicketGroupCard(index + 1, order);
                            }),
                            const SizedBox(height: 24),
                          ],
                          if (_editableCart.isEmpty && (!isAdditional || _sessionOrdersSummary.isEmpty))
                            _buildEmptyCartView()
                          else if (_editableCart.isNotEmpty) ...[
                            if (isAdditional)
                              const Text(
                                'New Cart Items',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF203F35)),
                              ),
                            if (isAdditional) const SizedBox(height: 12),
                            ..._editableCart.entries.map((entry) => _buildCartItemCard(entry.key, entry.value)),
                            const SizedBox(height: 12),
                            _buildPriceBreakdownCard(),
                            const SizedBox(height: 24),
                            _buildActionButtonsArea(),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketGroupCard(int ticketNum, dynamic order) {
    final String orderCode = order['order_code'] ?? '#BS-${order['order_id'] ?? ticketNum}';
    final String status = (order['status'] ?? order['order_status'] ?? 'PENDING').toString().toUpperCase();
    final double orderTotal = double.tryParse(order['total_amount']?.toString() ?? order['order_total']?.toString() ?? '0') ?? 0.0;
    final List items = order['items'] ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDFA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5DFD3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Ticket #$ticketNum ($orderCode)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF203F35))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEE7D9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(status, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFA47C3D))),
              ),
            ],
          ),
          const Divider(height: 20, color: Color(0xFFE5DFD3)),
          if (items.isEmpty)
            const Text('No items in this ticket.', style: TextStyle(fontSize: 12, color: Color(0xFF788078)))
          else
            ...items.map((i) {
              final name = i['name'] ?? i['item_name'] ?? 'Dish Item';
              final qty = i['quantity'] ?? 1;
              final price = double.tryParse(i['unit_price']?.toString() ?? i['price']?.toString() ?? '0') ?? 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text('$qty x $name', style: const TextStyle(fontSize: 13, color: Color(0xFF24382F)))),
                    Text('₱${(price * qty).toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF203F35))),
                  ],
                ),
              );
            }),
          const Divider(height: 20, color: Color(0xFFE5DFD3)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Ticket Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF788078))),
              Text('₱${orderTotal.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF203F35))),
            ],
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
    final bool isAdditional = widget.isAdditionalOrder || UserSession.isAdditionalOrder;
    final String? parentId = UserSession.targetParentOrderId;

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
                '$tableString verified',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Color(0xFF203F35)),
              ),
            ],
          ),
          Text(
            widget.isTakeout
                ? 'Takeout'
                : (isAdditional && parentId != null ? 'Adding to $parentId' : 'Dine-in'),
            style: const TextStyle(fontSize: 10, color: Color(0xFF788078), fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroductionHeader() {
    final bool isAdditional = widget.isAdditionalOrder || UserSession.isAdditionalOrder;
    final String orderTag = isAdditional ? 'ADDITIONAL ORDER' : 'NEW ORDER';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$orderTag • $_totalItemCount ITEMS',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFFA47C3D),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          "Your table's favorites.",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF203F35),
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isAdditional
              ? 'Adding items to your active table order. Review dishes before sending them to the kitchen.'
              : 'A lovely spread for ${widget.isTakeout ? "Takeout" : "Table ${widget.tableId ?? 7}"}. Adjust any dish before sending it to the kitchen.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF788078), height: 1.4),
        ),
      ],
    );
  }

  Widget _buildEmptyCartView() {
    return Container(
      padding: const EdgeInsets.all(32),
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDFA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5DFD3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.shopping_bag_outlined, size: 48, color: Color(0xFF788078)),
          const SizedBox(height: 16),
          const Text(
            'Your shopping cart is empty.',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF203F35)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Explore our heritage selections and add your favorite dishes.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF788078)),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF203F35),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Add More Dishes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItemCard(FoodItem item, int quantity) {
    final double itemTotal = item.price * quantity;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEE7D9),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.restaurant_outlined, size: 24, color: Color(0xFF203F35)),
                      const SizedBox(height: 2),
                      Text(
                        item.name.substring(0, 1),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFA47C3D)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF24382F)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        InkWell(
                          onTap: () => _removeItem(item),
                          child: const Icon(Icons.delete_outline, size: 18, color: Color(0xFF788078)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₱${item.price.toStringAsFixed(0)} each',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF788078)),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Standard Serving',
                      style: TextStyle(fontSize: 10, color: Color(0xFF53766C)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F4EC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE5DFD3)),
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => _updateQuantity(item, -1),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6.0),
                        child: Icon(Icons.remove, size: 16, color: Color(0xFF203F35)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$quantity',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF24382F)),
                    ),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: () => _updateQuantity(item, 1),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6.0),
                        child: Icon(Icons.add, size: 16, color: Color(0xFF203F35)),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '₱${itemTotal.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF203F35)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceBreakdownCard() {
    final bool isAdditional = widget.isAdditionalOrder || UserSession.isAdditionalOrder;
    final double combinedGrandTotal = isAdditional ? (_calculatedTotal + _sessionGrandTotal) : _calculatedTotal;

    if (!isAdditional) {
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
                const Text('New Order Total', style: TextStyle(fontSize: 12, color: Color(0xFF788078))),
                Text('₱${_calculatedTotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF203F35))),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: Divider(height: 1, color: Color(0xFFE5DFD3)),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Grand Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF24382F))),
                Text(
                  '₱${combinedGrandTotal.toStringAsFixed(0)}',
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
              const Text('Active Tickets Total', style: TextStyle(fontSize: 12, color: Color(0xFF788078))),
              Text('₱${_sessionGrandTotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF203F35))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('New Cart Items Total', style: TextStyle(fontSize: 12, color: Color(0xFF788078))),
              Text('₱${_calculatedTotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF203F35))),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Divider(height: 1, color: Color(0xFFE5DFD3)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Grand Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF24382F))),
              Text(
                '₱${combinedGrandTotal.toStringAsFixed(0)}',
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

  Widget _buildActionButtonsArea() {
    final bool isAdditional = widget.isAdditionalOrder || UserSession.isAdditionalOrder;
    _calculatedTotal;
    final double combinedGrandTotal = isAdditional ? (_calculatedTotal + _sessionGrandTotal) : _calculatedTotal;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF203F35),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CheckoutScreen(
                    cart: _editableCart,
                    total: combinedGrandTotal,
                    tableId: widget.tableId,
                    isTakeout: widget.isTakeout,
                    isAdditionalOrder: widget.isAdditionalOrder,
                  ),
                ),
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Review order • ₱${combinedGrandTotal.toStringAsFixed(0)}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: const Color(0xFFFFFDFA),
              side: const BorderSide(color: Color(0xFFE5DFD3)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Add more dishes',
              style: TextStyle(color: Color(0xFF203F35), fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }
}
