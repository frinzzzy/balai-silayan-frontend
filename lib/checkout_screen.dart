import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'order_status_screen.dart';
import 'order_type_selection_screen.dart';
import 'menu_screen.dart';
import 'user_session.dart';
import 'services/order_context.dart';
import 'services/socket_service.dart';
import 'config/api_config.dart';

class CheckoutScreen extends StatefulWidget {
  final Map<FoodItem, int> cart;
  final double total;
  final int? tableId;
  final bool isTakeout;
  final bool isAdditionalOrder;

  const CheckoutScreen({
    super.key,
    required this.cart,
    required this.total,
    this.tableId = 7,
    required this.isTakeout,
    this.isAdditionalOrder = false,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _isSubmitting = false;
  late Map<FoodItem, int> _editableCart;
  late double _calculatedTotal;

  String get _baseUrl => ApiConfig.baseUrl;

  @override
  void initState() {
    super.initState();
    _editableCart = Map.from(widget.cart);
    _calculatedTotal = _calculateCartTotal();
  }

  String _generateUuidV4() {
    final Random random = Random();
    final bytes = List<int>.generate(16, (i) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    String hex(int byte) => byte.toRadixString(16).padLeft(2, '0');

    return '${hex(bytes[0])}${hex(bytes[1])}${hex(bytes[2])}${hex(bytes[3])}-'
        '${hex(bytes[4])}${hex(bytes[5])}-'
        '${hex(bytes[6])}${hex(bytes[7])}-'
        '${hex(bytes[8])}${hex(bytes[9])}-'
        '${hex(bytes[10])}${hex(bytes[11])}${hex(bytes[12])}${hex(bytes[13])}${hex(bytes[14])}${hex(bytes[15])}';
  }

  double _getItemPrice(FoodItem item) {
    return item.price;
  }

  double _calculateCartTotal() {
    double sum = _editableCart.entries.fold(
      0.0,
      (acc, entry) => acc + (_getItemPrice(entry.key) * entry.value),
    );
    if (sum == 0.0 && widget.total > 0) {
      sum = widget.total;
    }
    return sum;
  }

  void _recalculatePipeline() {
    setState(() {
      _calculatedTotal = _calculateCartTotal();
    });
  }

  void _updateQuantity(FoodItem item, int variance) {
    setState(() {
      int activeQty = _editableCart[item] ?? 0;
      if (activeQty + variance <= 0) {
        _editableCart.remove(item);
      } else {
        _editableCart[item] = activeQty + variance;
      }
      _recalculatePipeline();
    });
  }

  Future<void> _submitOrderToBackend() async {
    if (_editableCart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your basket is empty. Please select food items first.'),
          backgroundColor: Color(0xFF8E5136),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final int targetTableId = widget.isTakeout ? 1 : (widget.tableId ?? UserSession.activeTableId ?? 7);

    final List<Map<String, dynamic>> orderItemsPayload = _editableCart.entries.map((entry) {
      final item = entry.key;
      final qty = entry.value;
      final String itemName = item.name;
      final double itemPrice = item.price;
      return {
        "menu_item_id": item.itemDbId,
        "name": itemName,
        "item_name": itemName,
        "quantity": qty,
        "unit_price": itemPrice,
        "price": itemPrice,
        "addons": [],
      };
    }).toList();

    final String idempotencyKey = _generateUuidV4();

    int? targetSessionId = UserSession.activeSessionId ??
        int.tryParse(UserSession.sessionId ?? '');

    if (targetSessionId == null) {
      try {
        final sessionRes = await http.post(
          Uri.parse('$_baseUrl/api/v1/dev/force-active-session'),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"table_id": targetTableId}),
        ).timeout(const Duration(seconds: 15));
        if (sessionRes.statusCode == 200) {
          final resData = jsonDecode(sessionRes.body);
          final data = resData['data'];
          if (data != null && data['session_id'] != null) {
            targetSessionId = int.tryParse(data['session_id'].toString());
            UserSession.activeSessionId = targetSessionId;
            UserSession.sessionId = targetSessionId?.toString();
            if (data['session_token'] != null) {
              UserSession.customerSessionToken = data['session_token'].toString();
            }
          }
        }
      } catch (_) {}
    }

    final bool isAdditional = widget.isAdditionalOrder || UserSession.isAdditionalOrder;

    // AUTO-HEAL: Kung isAdditional ay true ngunit walang targetParentOrderId, kumuha mula sa unfinished orders ng table
    if (isAdditional && (UserSession.targetParentOrderId == null || UserSession.targetParentOrderId!.isEmpty)) {
      try {
        final res = await http.get(Uri.parse('$_baseUrl/api/v1/orders/unfinished?table_id=$targetTableId')).timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          final decoded = jsonDecode(res.body);
          final List orders = decoded['orders'] ?? decoded['data'] ?? [];
          if (orders.isNotEmpty) {
            final activeParent = orders.first;
            UserSession.targetParentOrderId = (activeParent['order_id'] ?? activeParent['id']).toString();
          }
        }
      } catch (_) {}
    }
    
    dynamic rawParentId = isAdditional ? (UserSession.targetParentOrderId ?? UserSession.firstOrderId) : null;
    int? parsedParentOrderId;
    if (rawParentId != null) {
      parsedParentOrderId = int.tryParse(rawParentId.toString());
    }

    final bool safeIsAdditional = isAdditional && parsedParentOrderId != null;
    final dynamic finalParentId = safeIsAdditional ? parsedParentOrderId : null;

    final Map<String, dynamic> transactionBody = {
      "table_id": targetTableId,
      "session_id": targetSessionId,
      "parent_order_id": safeIsAdditional ? finalParentId : null,
      "is_additional_order": safeIsAdditional,
      "items": orderItemsPayload,
      "grand_total": _calculatedTotal,
      "client_order_id": idempotencyKey,
      "timestamp": DateTime.now().toIso8601String(),
    };

    try {
      debugPrint('--- DEBUG TRANSACTION BODY ---');
      debugPrint('Is Additional: $safeIsAdditional');
      debugPrint('Target Parent Order ID: $finalParentId');
      debugPrint('Session ID: $targetSessionId');
      debugPrint('Table ID: $targetTableId');
      debugPrint('Transaction Body: ${jsonEncode(transactionBody)}');

      final String? sessionToken = UserSession.customerSessionToken ?? UserSession.authToken;
      final Map<String, String> reqHeaders = {
        "Content-Type": "application/json",
        "x-idempotency-key": idempotencyKey,
        if (sessionToken != null && sessionToken.isNotEmpty)
          "Authorization": "Bearer $sessionToken",
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/orders'),
        headers: reqHeaders,
        body: jsonEncode(transactionBody),
      ).timeout(const Duration(seconds: 20));

      debugPrint('API Response Status: ${response.statusCode}');
      debugPrint('API Response Body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final dynamic createdOrderData =
            responseData['data']?['order'] ?? responseData['data'];
        final dynamic generatedOrderId =
            createdOrderData?['id'] ??
            createdOrderData?['order_id'] ??
            DateTime.now().millisecondsSinceEpoch;

        final dynamic responseItems =
            responseData['data']?['items'] ?? createdOrderData?['items'];
        final List<dynamic>? initialOrderItems = responseItems is List
            ? List<dynamic>.from(responseItems)
            : null;

        _saveOrderSessionAndJoinSocketRooms(
          createdOrderData: createdOrderData,
          generatedOrderId: generatedOrderId,
          targetTableId: targetTableId,
          targetSessionId: targetSessionId,
          initialOrderItems: initialOrderItems ?? orderItemsPayload,
          linkedParentOrderId: finalParentId,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Order submitted successfully to kitchen!'),
              backgroundColor: Color(0xFF203F35),
            ),
          );
          _navigateToStatusTracking(
            generatedOrderId,
            initialOrderItems: initialOrderItems,
          );
        }
      } else {
        final dynamic errorBody = jsonDecode(response.body);
        final String errorMessage = errorBody is Map
            ? (errorBody['message']?.toString() ??
            'Backend returned status code ${response.statusCode}')
            : 'Backend returned status code ${response.statusCode}';
        final String? errorCode =
            errorBody is Map ? errorBody['code']?.toString() : null;

        if (response.statusCode == 409 && errorCode == 'BILL_ALREADY_REQUESTED') {
          setState(() => _isSubmitting = false);
          _showBillLockedDialog(errorMessage);
          return;
        }

        final bool sessionClosedError = response.statusCode == 409 &&
            (errorCode == 'SESSION_CLOSED' ||
                (errorBody is Map && errorBody['error'] == 'SESSION_CLOSED'));
        if (sessionClosedError) {
          setState(() => _isSubmitting = false);
          _showSessionClosedDialog();
          return;
        }

        if (response.statusCode == 401 || response.statusCode == 403 ||
            (errorMessage.toLowerCase().contains('session') &&
            (errorMessage.toLowerCase().contains('active') || errorMessage.toLowerCase().contains('not active') || errorMessage.toLowerCase().contains('unauthorized')))) {
          try {
            final sessionRes = await http.post(
              Uri.parse('$_baseUrl/api/v1/dev/force-active-session'),
              headers: {"Content-Type": "application/json"},
              body: jsonEncode({"table_id": targetTableId}),
            );
            if (sessionRes.statusCode == 200) {
              final resData = jsonDecode(sessionRes.body);
              final data = resData['data'];
              if (data != null && data['session_id'] != null) {
                final int newSessionId = int.parse(data['session_id'].toString());
                UserSession.activeSessionId = newSessionId;
                UserSession.sessionId = newSessionId.toString();
                if (data['session_token'] != null) {
                  UserSession.customerSessionToken = data['session_token'].toString();
                }

                transactionBody["session_id"] = newSessionId;
                final retryResponse = await http.post(
                  Uri.parse('$_baseUrl/api/v1/orders'),
                  headers: reqHeaders,
                  body: jsonEncode(transactionBody),
                );

                if (retryResponse.statusCode == 201 || retryResponse.statusCode == 200) {
                  final Map<String, dynamic> retryData = jsonDecode(retryResponse.body);
                  final dynamic createdOrderData = retryData['data']?['order'] ?? retryData['data'];
                  final dynamic generatedOrderId = createdOrderData?['id'] ?? createdOrderData?['order_id'] ?? DateTime.now().millisecondsSinceEpoch;

                  _saveOrderSessionAndJoinSocketRooms(
                    createdOrderData: createdOrderData,
                    generatedOrderId: generatedOrderId,
                    targetTableId: targetTableId,
                    targetSessionId: newSessionId,
                    initialOrderItems: orderItemsPayload,
                    linkedParentOrderId: finalParentId,
                  );

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Order submitted successfully to kitchen!'),
                        backgroundColor: Color(0xFF203F35),
                      ),
                    );
                    _navigateToStatusTracking(generatedOrderId);
                  }
                  return;
                }
              }
            }
          } catch (_) {}
        }

        // AUTO-HEAL KUNG 404 PARENT ORDER NOT FOUND
        if (response.statusCode == 404 && errorMessage.toLowerCase().contains('parent order')) {
          UserSession.targetParentOrderId = null;
          UserSession.isAdditionalOrder = false;
          UserSession.firstOrderId = null;

          transactionBody["is_additional_order"] = false;
          transactionBody["parent_order_id"] = null;

          try {
            final retryResponse = await http.post(
              Uri.parse('$_baseUrl/api/v1/orders'),
              headers: reqHeaders,
              body: jsonEncode(transactionBody),
            );

            if (retryResponse.statusCode == 201 || retryResponse.statusCode == 200) {
              final Map<String, dynamic> retryData = jsonDecode(retryResponse.body);
              final dynamic createdOrderData = retryData['data']?['order'] ?? retryData['data'];
              final dynamic generatedOrderId = createdOrderData?['id'] ?? createdOrderData?['order_id'] ?? DateTime.now().millisecondsSinceEpoch;

              _saveOrderSessionAndJoinSocketRooms(
                createdOrderData: createdOrderData,
                generatedOrderId: generatedOrderId,
                targetTableId: targetTableId,
                targetSessionId: targetSessionId,
                initialOrderItems: orderItemsPayload,
                linkedParentOrderId: null,
              );

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Order submitted successfully as a new ticket!'),
                    backgroundColor: Color(0xFF203F35),
                  ),
                );
                _navigateToStatusTracking(generatedOrderId);
              }
              return;
            }
          } catch (_) {}
        }

        _handleOrderSubmissionError(errorMessage);
      }
    } catch (e) {
      _handleOrderSubmissionError('Connection error: $e');
    }
  }

  void _handleOrderSubmissionError(String errorDetails) {
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    final String lowerErr = errorDetails.toLowerCase();
    final bool isSessionGone = lowerErr.contains('complete') ||
        lowerErr.contains('closed') ||
        lowerErr.contains('settled') ||
        lowerErr.contains('finished') ||
        lowerErr.contains('not active');
    final bool isParentGone = lowerErr.contains('parent order') ||
        lowerErr.contains('failed to create order');

    if (isSessionGone || isParentGone) {
      // ⚠️ Huwag agad i-clear ang buong session: lang ang mismong session ang
      // dapat i-close. Kapag nawala lang ang parent ticket (ex. completed ang
      // older ticket), i-reset lang ang additional flags.
      if (isSessionGone) {
        UserSession.clearSession();
      } else {
        UserSession.isAdditionalOrder = false;
        UserSession.targetParentOrderId = null;
        UserSession.firstOrderId = null;
        OrderContext.instance.reset();
      }
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFFFFFDFA),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Session Complete', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF203F35))),
          content: Text(
            isSessionGone
                ? 'Can’t be ordered because this session is complete. Please back to order choices.'
                : 'The previous ticket has already been finished. Back to order choices para magpatuloy ng bagong order.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF203F35), height: 1.4),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF203F35)),
              onPressed: () {
                Navigator.pop(ctx);
                final int tableNum = widget.tableId ?? UserSession.activeTableId ?? UserSession.activeTableNumber ?? 7;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OrderTypeSelectionScreen(
                      tableId: tableNum,
                      tableNumber: tableNum,
                    ),
                  ),
                  (route) => false,
                );
              },
              child: const Text('Back to Order Choices', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Order was not submitted. $errorDetails'),
        backgroundColor: const Color(0xFF8E5136),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showBillLockedDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFFDFA),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Bill already requested',
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF203F35)),
        ),
        content: Text(
          message.isNotEmpty
              ? message
              : 'Naka-request na ang bill para sa ticket na ito. Ask staff to reopen ordering bago magdagdag ng items.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF203F35), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF203F35)),
            onPressed: () {
              Navigator.pop(ctx);
              if (Navigator.canPop(context)) Navigator.pop(context);
            },
            child: const Text(
              'Back to Menu',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  /// Kapag na-settle na ang session (409 SESSION_CLOSED), huwag i-retry nang
  /// tahimik — ipakita sa customer na kailangan niyang mag-scan muli.
  void _showSessionClosedDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFFDFA),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Session ended',
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF203F35)),
        ),
        content: const Text(
          'Na-settle na ang table session na ito. I-scan muli ang QR ng table '
          'para magsimula ng bagong session.',
          style: TextStyle(fontSize: 13, color: Color(0xFF203F35), height: 1.4),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF203F35)),
            onPressed: () {
              Navigator.pop(ctx);
              UserSession.clearSession();
              UserSession.clearAllBillRequests();
              UserSession.targetParentOrderId = null;
              UserSession.lastPlacedOrderId = null;
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text(
              'OK',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToStatusTracking(
    dynamic orderId, {
    List<dynamic>? initialOrderItems,
  }) {
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => OrderStatusScreen(
          orderId: orderId,
          isTakeout: widget.isTakeout,
          tableId: widget.tableId,
          totalAmount: _calculatedTotal,
          isAdditionalOrder: widget.isAdditionalOrder,
          initialOrderItems: initialOrderItems,
        ),
      ),
      (route) => route.isFirst,
    );
  }

  void _saveOrderSessionAndJoinSocketRooms({
    required dynamic createdOrderData,
    required dynamic generatedOrderId,
    required int targetTableId,
    required int? targetSessionId,
    List<dynamic>? initialOrderItems,
    dynamic linkedParentOrderId,
  }) {
    int? sanitizedOrderId = int.tryParse(generatedOrderId?.toString() ?? '');

    final dynamic respSessionId = createdOrderData?['session_id'];
    int? resolvedSessionId = targetSessionId;
    if (respSessionId != null) {
      resolvedSessionId = int.tryParse(respSessionId.toString()) ?? targetSessionId;
    }

    if (resolvedSessionId != null) {
      UserSession.activeSessionId = resolvedSessionId;
      UserSession.sessionId = resolvedSessionId.toString();
    }

    UserSession.activeTableId = targetTableId;
    UserSession.activeTableNumber = targetTableId;

    final bool isAdditional = widget.isAdditionalOrder || UserSession.isAdditionalOrder;
    if (!isAdditional && UserSession.firstOrderId == null && sanitizedOrderId != null) {
      UserSession.firstOrderId = sanitizedOrderId;
    }

    UserSession.lastPlacedOrderId = generatedOrderId;
    UserSession.lastPlacedOrderTotal = _calculatedTotal;
    if (initialOrderItems != null) {
      UserSession.lastPlacedOrderItems = initialOrderItems;
    }

    // ⚠️ HUWAG i-overwrite ang targetParentOrderId ng bagong order id.
    // Dati: `targetParentOrderId = generatedOrderId` kaya hindi tumatama ang
    // pag-detect ng "finished parent ticket". Ngayon, ang parent ticket (hal.
    // 108) ang naka-store, at ang bagong order ay nasa `lastPlacedOrderId`.
    final String? linkedParent = linkedParentOrderId?.toString().trim();
    final bool hasParent = linkedParent != null && linkedParent.isNotEmpty && linkedParent != 'null';
    if (hasParent) {
      UserSession.isAdditionalOrder = true;
      UserSession.targetParentOrderId = linkedParent;
      OrderContext.instance.enter(
        mode: CustomerOrderMode.additionalOrder,
        activeOrderId: sanitizedOrderId,
        linkedParentId: linkedParent,
      );
    } else {
      UserSession.isAdditionalOrder = false;
      OrderContext.instance.enter(
        mode: CustomerOrderMode.newOrder,
        activeOrderId: sanitizedOrderId,
      );
    }

    try {
      final socketService = SocketService();
      socketService.joinTableRoom(targetTableId);
      if (resolvedSessionId != null) {
        socketService.joinSessionRoom(resolvedSessionId);
      }
      if (generatedOrderId != null) {
        socketService.joinOrderRoom(generatedOrderId);
      }
    } catch (_) {}
  }

  Widget _buildItemImageWidget(FoodItem item) {
    final String? imgUrl = item.imageUrl;
    if (imgUrl != null && imgUrl.startsWith('lib/menus/')) {
      return Image.asset(
        imgUrl,
        width: 52,
        height: 52,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildItemFallbackText(item),
      );
    }
    if (imgUrl != null && imgUrl.startsWith('http')) {
      return Image.network(
        imgUrl,
        width: 52,
        height: 52,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildItemFallbackText(item),
      );
    }
    return _buildItemFallbackText(item);
  }

  Widget _buildItemFallbackText(FoodItem item) {
    return Center(
      child: Text(
        item.name.isNotEmpty ? item.name.substring(0, 1) : 'D',
        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF203F35)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;
    final int displayTableNum = widget.tableId ?? 7;
    final bool isAdditional = widget.isAdditionalOrder;
    final String? parentOrderId = UserSession.targetParentOrderId;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F4EC),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF203F35), size: 18),
          onPressed: () => Navigator.pop(context, _editableCart),
        ),
        title: Text(
          isAdditional ? 'Verify Additional Order' : 'Verify Order Details',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF203F35)),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isSubmitting
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF203F35)),
                  SizedBox(height: 16),
                  Text(
                    'Submitting order to kitchen...',
                    style: TextStyle(color: Color(0xFF203F35), fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )
          : Center(
              child: Container(
                constraints: BoxConstraints(maxWidth: isDesktop ? 700 : double.infinity),
                child: Column(
                  children: [
                    Expanded(
                      child: _editableCart.isEmpty
                          ? const Center(
                              child: Text('Your basket is currently empty.', style: TextStyle(color: Color(0xFF788078))),
                            )
                          : ListView(
                              padding: const EdgeInsets.all(16),
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF203F35),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        widget.isTakeout ? Icons.shopping_bag_outlined : Icons.table_restaurant_outlined,
                                        color: const Color(0xFFA47C3D),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          widget.isTakeout
                                              ? 'Dining Preference: Takeout / To-Go'
                                              : (isAdditional && parentOrderId != null
                                                  ? 'Additional Order for Table #${displayTableNum.toString().padLeft(2, '0')} (Main: $parentOrderId)'
                                                  : 'Dining Preference: Dine-In (Table #${displayTableNum.toString().padLeft(2, '0')})'),
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Basket Selection Summary',
                                      style: TextStyle(color: Color(0xFF788078), fontWeight: FontWeight.bold),
                                    ),
                                    if (isAdditional)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFA47C3D).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          'ADD-ON',
                                          style: TextStyle(color: Color(0xFFA47C3D), fontWeight: FontWeight.bold, fontSize: 10),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ..._editableCart.entries.map((entry) {
                                  final item = entry.key;
                                  final qty = entry.value;
                                  return Card(
                                    color: const Color(0xFFFFFDFA),
                                    margin: const EdgeInsets.only(bottom: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: const BorderSide(color: Color(0xFFE5DFD3)),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 52,
                                            height: 52,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEEE7D9),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: _buildItemImageWidget(item),
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.name,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF203F35)),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '₱${item.price.toStringAsFixed(2)} each',
                                                  style: const TextStyle(color: Color(0xFFA47C3D), fontSize: 12, fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.remove_circle_outline, size: 20, color: Color(0xFF203F35)),
                                                onPressed: () => _updateQuantity(item, -1),
                                              ),
                                              Text(
                                                '$qty',
                                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF203F35)),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.add_circle, color: Color(0xFF203F35), size: 20),
                                                onPressed: () => _updateQuantity(item, 1),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                    ),
                    if (_editableCart.isNotEmpty) _renderPaymentExecutionDrawer(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _renderPaymentExecutionDrawer() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFFFFFDFA),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Order Total',
                  style: TextStyle(color: Color(0xFF788078), fontWeight: FontWeight.bold),
                ),
                Text(
                  '₱${_calculatedTotal.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF203F35)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF203F35),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: _submitOrderToBackend,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Place Order',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
