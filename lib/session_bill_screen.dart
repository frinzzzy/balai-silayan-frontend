import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';
import 'dart:ui' show ImageFilter;

import 'menu_screen.dart';
import 'assistance_screen.dart';
import 'order_status_screen.dart';
import 'services/global_socket_listener.dart';
import 'services/order_context.dart';
import 'services/order_event_bus.dart';
import 'bill_requested_screen.dart';
import 'user_session.dart';
import 'config/api_config.dart';

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
  String? _billRequestedAt;
  String? _errorMessage;

  double _foodDrinksTotal = 0.0;
  double _addOnsTotal = 0.0;
  double _grandTotal = 0.0;
  List<Map<String, dynamic>> _sessionOrders = [];
  String _orderStatus = 'PENDING';
  String _sessionStatus = 'ACTIVE';

  int? _refreshToken;
  int? _contextToken;

  String get _baseUrl => ApiConfig.baseUrl;

  @override
  void initState() {
    super.initState();
    _fetchSessionBillData();
    _contextToken = OrderContext.instance.enter(
      mode: CustomerOrderMode.browsingTickets,
    );
    _refreshToken = OrderEventBus.instance.subscribeRefresh(() {
      if (mounted) _fetchSessionBillData(refresh: true);
    });
    GlobalSocketListener.instance.start(context: context);
    GlobalSocketListener.instance.registerTableIdentity(
      tableId: widget.tableId,
      tableNumber: widget.tableId,
    );
    GlobalSocketListener.instance.setOnSessionClosed((data) {
      if (!mounted || data is! Map) return;
      final int? eventSessionId = int.tryParse(
        (data['session_id'] ?? '').toString(),
      );
      final int? activeSessionId =
          UserSession.activeSessionId ?? int.tryParse(UserSession.sessionId ?? '');
      if (eventSessionId == activeSessionId && mounted) {
        setState(() => _sessionStatus = 'CLOSED');
      }
    });
  }

  @override
  void dispose() {
    if (_refreshToken != null) {
      OrderEventBus.instance.unsubscribe(_refreshToken!);
      _refreshToken = null;
    }
    if (_contextToken != null) {
      OrderContext.instance.leave(_contextToken!);
      _contextToken = null;
    }
    GlobalSocketListener.instance.setOnSessionClosed(GlobalSocketListener.instance.defaultOrderSessionClosed);
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
      // Ang total ay para sa buong session. Ang checkbox ay para lang sa
      // kung aling ticket ang ire-request ng bill, hindi para sa total.
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

            final dynamic orderBillRequestedAt = o['bill_requested_at'];
            final bool isTicketRequested = orderBillRequestedAt != null;

            parsedOrders.add({
              "order_id": orderId,
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
              "isRequested": isTicketRequested,
              "bill_requested_at": orderBillRequestedAt?.toString(),
              // Naka-check by default ang mga hindi pa nag-request para madaling
              // pumili. Naka-lock at naka-blur naman ang mga requested na.
              "isSelected": !isTicketRequested,
            });

            if (isTicketRequested) {
              UserSession.setTicketBillRequested(orderId, orderBillRequestedAt);
            } else {
              UserSession.clearTicketBillRequested(orderId);
            }
          }

          setState(() {
            _sessionOrders = parsedOrders;
            _sessionStatus = (data['session_status'] ?? 'ACTIVE')
                .toString()
                .toUpperCase();
            _orderStatus = parsedOrders.isEmpty
                ? 'PENDING'
                : parsedOrders.first['status'].toString().toUpperCase();
            final dynamic requestedAt =
                data['bill_requested_at'] ?? data['requested_at'];
            // Session-level marker lang ito. Per-ticket state ang
            // isRequested/bill_requested_at sa bawat order.
            final bool allTicketsRequested = parsedOrders.isNotEmpty &&
                parsedOrders.every((order) => order['isRequested'] == true);
            _billRequestedAt =
                allTicketsRequested ? requestedAt?.toString() : null;
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

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFEF4444),
      ),
    );
  }

  Future<Map<String, dynamic>> _postTicketBillRequest({
    required dynamic orderId,
    required int tableNum,
    required int? sessionId,
    required String? token,
    required Map<String, String> jsonHeaders,
  }) async {
    final List<Uri> uris = <Uri>[
      if (sessionId != null && sessionId > 0 && token != null && token.isNotEmpty)
        Uri.parse(
            '$_baseUrl/api/v1/customer/sessions/$sessionId/orders/$orderId/bill'),
      Uri.parse('$_baseUrl/api/v1/tables/$tableNum/orders/$orderId/bill'),
    ];

    bool unsupported = false;
    String message = 'Could not request the bill. Please try again.';

    for (final Uri uri in uris) {
      try {
        final bool isTableRoute = uri.path.startsWith('/api/v1/tables/');
        final Map<String, String> requestHeaders = isTableRoute
            ? const <String, String>{'Content-Type': 'application/json'}
            : jsonHeaders;
        final http.Response response = await http
            .post(uri, headers: requestHeaders, body: jsonEncode(<String, dynamic>{}))
            .timeout(const Duration(seconds: 15));

        Map<String, dynamic>? data;
        try {
          final dynamic decoded =
              response.body.isEmpty ? null : jsonDecode(response.body);
          if (decoded is Map) {
            final dynamic rawData = decoded['data'] ?? decoded;
            if (rawData is Map) {
              data = Map<String, dynamic>.from(rawData);
            }
          }
        } catch (_) {}

        if (response.statusCode == 200 || response.statusCode == 201) {
          final String requestedAt = (data?['bill_requested_at'] ??
                  data?['requested_at'] ??
                  DateTime.now().toIso8601String())
              .toString();
          return <String, dynamic>{
            'ok': true,
            'requestedAt': requestedAt,
          };
        }

        if (response.statusCode == 401 || response.statusCode == 403) {
          continue;
        }

        if (response.statusCode == 404 ||
            response.statusCode == 405 ||
            response.statusCode == 501 ||
            response.statusCode == 503) {
          // Lumang backend na wala pa ang per-ticket route.
          unsupported = true;
          continue;
        }

        return <String, dynamic>{
          'ok': false,
          'message': (data?['message'] ?? message).toString(),
          'status': response.statusCode,
        };
      } catch (_) {
        continue;
      }
    }

    return <String, dynamic>{
      'ok': false,
      'unsupported': unsupported,
      'message': message,
    };
  }

  Future<Map<String, dynamic>> _postLegacySessionBill({
    required int tableNum,
    required int? sessionId,
    required String? token,
    required Map<String, String> jsonHeaders,
  }) async {
    final List<Uri> uris = <Uri>[
      if (sessionId != null && sessionId > 0 && token != null && token.isNotEmpty)
        Uri.parse('$_baseUrl/api/v1/customer/sessions/$sessionId/bill'),
      Uri.parse('$_baseUrl/api/v1/tables/$tableNum/bill'),
    ];

    String message = 'Could not request the bill. Please try again.';

    for (final Uri uri in uris) {
      try {
        final bool isTableRoute = uri.path.startsWith('/api/v1/tables/');
        final Map<String, String> requestHeaders = isTableRoute
            ? const <String, String>{'Content-Type': 'application/json'}
            : jsonHeaders;
        final http.Response response = await http
            .post(uri, headers: requestHeaders, body: jsonEncode(<String, dynamic>{}))
            .timeout(const Duration(seconds: 15));

        Map<String, dynamic>? data;
        try {
          final dynamic decoded =
              response.body.isEmpty ? null : jsonDecode(response.body);
          if (decoded is Map) {
            final dynamic rawData = decoded['data'] ?? decoded;
            if (rawData is Map) {
              data = Map<String, dynamic>.from(rawData);
            }
          }
        } catch (_) {}

        if (response.statusCode == 200 || response.statusCode == 201) {
          return <String, dynamic>{
            'ok': true,
            'requestedAt': (data?['bill_requested_at'] ??
                    data?['requested_at'] ??
                    DateTime.now().toIso8601String())
                .toString(),
          };
        }

        if (response.statusCode == 401 || response.statusCode == 403) {
          continue;
        }

        message = (data?['message'] ?? message).toString();
      } catch (_) {
        continue;
      }
    }

    return <String, dynamic>{'ok': false, 'message': message};
  }

  Future<void> _submitRequestBill() async {
    if (_isRequestingBill) return;

    final int tableNum =
        widget.tableId ?? UserSession.activeTableId ?? UserSession.activeTableNumber ?? 1;
    final int? sessionId =
        UserSession.activeSessionId ?? int.tryParse(UserSession.sessionId ?? '');
    final String? token = UserSession.activeSessionToken;

    final List<Map<String, dynamic>> selectedTickets = _sessionOrders
        .where((order) =>
            order['isSelected'] == true && order['isRequested'] != true)
        .toList();

    if (selectedTickets.isEmpty) {
      _showSnack('Select at least one ticket to request a bill.');
      return;
    }

    final bool hasUnserved = selectedTickets.any((order) {
      final String status =
          (order['status'] ?? 'PENDING').toString().toUpperCase();
      return status == 'PENDING' ||
          status == 'NEW' ||
          status == 'PREPARING' ||
          status == 'READY';
    });

    if (hasUnserved) {
      final bool? proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFFFFFDFA),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text(
            'Request bill now?',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Color(0xFF203F35)),
          ),
          content: const Text(
            'May mga order pang hindi served. Sigurado ka bang i-request na ang bill para sa mga napiling ticket?',
            style: TextStyle(fontSize: 13, color: Color(0xFF203F35), height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Not yet'),
            ),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: const Color(0xFF203F35)),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Request Bill',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    setState(() => _isRequestingBill = true);

    final Map<String, String> jsonHeaders = <String, String>{
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    int successCount = 0;
    bool perTicketUnsupported = false;
    String lastRequestedAt = DateTime.now().toIso8601String();
    String? firstError;

    for (final Map<String, dynamic> ticket in selectedTickets) {
      final dynamic orderId = ticket['order_id'];
      final Map<String, dynamic> result = await _postTicketBillRequest(
        orderId: orderId,
        tableNum: tableNum,
        sessionId: sessionId,
        token: token,
        jsonHeaders: jsonHeaders,
      );

      if (result['ok'] == true) {
        successCount++;
        lastRequestedAt = (result['requestedAt'] ?? lastRequestedAt).toString();
        UserSession.setTicketBillRequested(orderId, lastRequestedAt);
      } else if (result['unsupported'] == true) {
        perTicketUnsupported = true;
        break;
      } else {
        firstError ??= (result['message'] ?? '').toString();
      }
    }

    // Backward compatible fallback: kung wala pa ang per-ticket route sa
    // naka-deploy na backend, isang session-level request na lang ang gagawin.
    if (perTicketUnsupported && successCount == 0) {
      final Map<String, dynamic> legacy = await _postLegacySessionBill(
        tableNum: tableNum,
        sessionId: sessionId,
        token: token,
        jsonHeaders: jsonHeaders,
      );

      if (legacy['ok'] == true) {
        lastRequestedAt =
            (legacy['requestedAt'] ?? lastRequestedAt).toString();
        for (final Map<String, dynamic> ticket in selectedTickets) {
          UserSession.setTicketBillRequested(
              ticket['order_id'], lastRequestedAt);
          successCount++;
        }
      } else {
        firstError ??= (legacy['message'] ?? firstError ?? '').toString();
      }
    }

    if (mounted) {
      setState(() {
        _isRequestingBill = false;
        for (int i = 0; i < _sessionOrders.length; i++) {
          final dynamic orderId = _sessionOrders[i]['order_id'];
          if (UserSession.isTicketBillRequested(orderId)) {
            _sessionOrders[i]['isRequested'] = true;
            _sessionOrders[i]['isSelected'] = false;
            _sessionOrders[i]['bill_requested_at'] =
                UserSession.billRequestedAtFor(orderId);
          }
        }
        final bool allRequested = _sessionOrders.isNotEmpty &&
            _sessionOrders.every((order) => order['isRequested'] == true);
        if (allRequested) {
          _billRequestedAt = lastRequestedAt;
        }
      });
      _recalculateTotals();
    }

    if (successCount > 0) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => BillRequestedScreen(
            tableId: tableNum,
            isTakeout: widget.isTakeout,
            totalAmount: _grandTotal,
            foodDrinksTotal: _foodDrinksTotal,
            addOnsTotal: _addOnsTotal,
            billRequestedAt: lastRequestedAt,
          ),
        ),
      );
      return;
    }

    _showSnack(firstError != null && firstError.isNotEmpty
        ? firstError
        : 'Could not request the bill. Please try again.');
  }

  @override
  Widget build(BuildContext context) {
    final int tableNum = widget.tableId ?? UserSession.activeTableId ?? 1;
    final String tableString = widget.isTakeout
        ? 'Takeout'
        : 'Table ${tableNum.toString().padLeft(2, '0')}';
    final bool hasSelectedOrders = _sessionOrders.any(
        (order) => order['isSelected'] == true && order['isRequested'] != true);

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
          'I-review ang mga order sa session na ito, pagkatapos ay i-request ang bill para ma-notify ang staff.',
          style: TextStyle(fontSize: 13, color: Color(0xFF788078), height: 1.4),
        ),
      ],
    );
  }

  Widget _buildSessionStatusBadge() {
    final bool isPaid = _orderStatus == 'COMPLETED';
    final bool isClosed = _sessionStatus == 'CLOSED';
    final bool billRequested = _billRequestedAt != null &&
        _sessionOrders.isNotEmpty &&
        _sessionOrders.every((order) => order['isRequested'] == true);
    final String statusText = isPaid
        ? 'Paid • Session Closed'
        : isClosed
        ? 'Session Closed'
        : billRequested
        ? 'Bill Requested'
        : 'Active Session';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isPaid || isClosed
            ? const Color(0xFFEAF0E9)
            : const Color(0xFFEEE7D9),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPaid || isClosed
                ? Icons.check_circle_outline
                : Icons.receipt_long_outlined,
            size: 13,
            color: isPaid || isClosed
                ? const Color(0xFF203F35)
                : const Color(0xFFA47C3D),
          ),
          const SizedBox(width: 6),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isPaid || isClosed
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
    final bool isRequested = order['isRequested'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isRequested ? const Color(0xFFF4F6F2) : const Color(0xFFFFFDFA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isRequested
              ? const Color(0xFF53766C)
              : isSelected
                  ? const Color(0xFFA47C3D)
                  : const Color(0xFFE5DFD3),
          width: (isSelected || isRequested) ? 1.5 : 1,
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
        value: isRequested ? true : isSelected,
        activeColor: isRequested
            ? const Color(0xFF53766C)
            : const Color(0xFF203F35),
        checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onChanged: isRequested
            ? null
            : (bool? value) {
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
            if (isRequested)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: const [
                    Icon(Icons.check_circle,
                        size: 14, color: Color(0xFF53766C)),
                    SizedBox(width: 4),
                    Text(
                      'Bill requested',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF53766C),
                      ),
                    ),
                  ],
                ),
              ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: Divider(height: 1, color: Color(0xFFE5DFD3)),
            ),
            ImageFiltered(
              imageFilter: isRequested
                  ? ImageFilter.blur(sigmaX: 2.2, sigmaY: 2.2)
                  : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: items.map((item) {
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
                }).toList(),
              ),
            ),
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
              'Kapag naipadala na ang bill request, maaari mong sundan ang status sa Live Status o hintayin ang staff.',
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
    final int selectedCount = _sessionOrders
        .where((order) =>
            order['isSelected'] == true && order['isRequested'] != true)
        .length;
    final bool allRequested = _sessionOrders.isNotEmpty &&
        _sessionOrders.every((order) => order['isRequested'] == true);
    final bool isClosed = _sessionStatus == 'CLOSED';
    final bool isPaid = _orderStatus == 'COMPLETED' || _orderStatus == 'PAID';
    final bool isDisabled = !hasSelectedOrders ||
        _isRequestingBill ||
        isClosed ||
        isPaid ||
        _sessionOrders.isEmpty;

    final String label = isPaid
        ? 'Paid ✓'
        : isClosed
            ? 'Session Closed'
            : allRequested
                ? 'Bill Requested ✓'
                : selectedCount > 0
                    ? 'Request Bill ($selectedCount selected)'
                    : 'Select a ticket to request';

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isDisabled ? const Color(0xFF788078) : const Color(0xFF203F35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
        ),
        onPressed: isDisabled ? null : _submitRequestBill,
        child: _isRequestingBill
            ? const CircularProgressIndicator(color: Colors.white)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    allRequested || isClosed || isPaid
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
                MaterialPageRoute(builder: (context) => const MenuScreen(), settings: const RouteSettings(name: 'menu')),
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
                    orderId: UserSession.activeOrderId,
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