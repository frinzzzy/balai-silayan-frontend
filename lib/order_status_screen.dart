import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'assistance_screen.dart';
import 'orders_screen.dart';
import 'qr_scanner_screen.dart';
import 'order_type_selection_screen.dart';
import 'user_session.dart';

class OrderStatusScreen extends StatefulWidget {
  final dynamic orderId;
  final bool isTakeout;
  final int? tableId;
  final double totalAmount;
  final bool isAdditionalOrder;
  final List<dynamic>? initialOrderItems;

  const OrderStatusScreen({
    super.key,
    required this.orderId,
    required this.isTakeout,
    this.tableId,
    this.totalAmount = 0.0,
    this.isAdditionalOrder = false,
    this.initialOrderItems,
  });

  @override
  State<OrderStatusScreen> createState() => _OrderStatusScreenState();
}

class _OrderStatusScreenState extends State<OrderStatusScreen> {
  late io.Socket _repositorySocketGateway;
  Timer? _statusPollTimer;
  String _statusBadgeLabel = "Pending review";
  String _currentOrderStatus = 'PENDING';
  int _stepperProgressIndex = 0;
  bool _showLiveTrackerView = false;
  bool _isLoadingLiveOrder = true;
  bool _hasActiveOrder = true;
  bool _sessionWasClosed = false;

  double _fetchedTotalAmount = 0.0;
  String _fetchedOrderCode = '';
  String _formattedTimestamp = '';
  List<dynamic> _fetchedOrderItems = [];
  String _declineReason = '';

  int _getStatusPriority(String status) {
    switch (status.toUpperCase()) {
      case 'PAID':
      case 'COMPLETED':
      case 'CLOSED':
      case 'SETTLED':
        return 4;
      case 'SERVED':
      case 'READY':
        return 3;
      case 'PREPARING':
        return 2;
      case 'NEW':
      case 'PENDING':
        return 1;
      case 'REJECTED':
      case 'DECLINED':
      case 'CANCELLED':
      case 'SESSION_CANCELLED':
        return 5;
      default:
        return 1;
    }
  }

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
    _fetchedTotalAmount = widget.totalAmount > 0 ? widget.totalAmount : UserSession.lastPlacedOrderTotal;
    _fetchedOrderItems = widget.initialOrderItems ?? UserSession.lastPlacedOrderItems;
    _connectRepositorySocketStream();
    _fetchLatestOrderFromBackend();

    _statusPollTimer = Timer.periodic(const Duration(seconds: 6), (timer) {
      if (mounted) {
        _fetchLatestOrderFromBackend();
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void didUpdateWidget(covariant OrderStatusScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderId != widget.orderId) {
      setState(() {
        _isLoadingLiveOrder = true;
        _fetchedTotalAmount = widget.totalAmount > 0 ? widget.totalAmount : UserSession.lastPlacedOrderTotal;
        _fetchedOrderItems = widget.initialOrderItems ?? UserSession.lastPlacedOrderItems;
      });
      _fetchLatestOrderFromBackend();
    }
  }

  String _formatOrderCode(dynamic orderId) {
    return UserSession.formatOrderCode(orderId);
  }

  List<Map<String, dynamic>> _orderListFrom(dynamic value) {
    if (value is List) {
      return value.map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}).toList();
    }
    return [];
  }

  Future<void> _fetchLatestOrderFromBackend() async {
    try {
      final int? sessionId =
          UserSession.activeSessionId ??
              int.tryParse(UserSession.sessionId ?? '');
      final int tableNum = widget.tableId ?? UserSession.activeTableNumber ?? UserSession.activeTableId ?? 7;

      final dynamic targetOrderId = widget.orderId ?? UserSession.lastPlacedOrderId ?? UserSession.targetParentOrderId;

      Map<String, dynamic>? matchingOrder;
      double sessionGrandTotal = 0.0;
      List<dynamic> sessionItems = [];
      bool currentOrderCompleted = false;
      bool sessionWideCompleted = false;

      // 1. Direct endpoint check para sa kasalukuyang tinitingnang ticket
      if (targetOrderId != null) {
        try {
          final singleRes = await http.get(Uri.parse('$_baseUrl/api/v1/orders/$targetOrderId'));
          if (singleRes.statusCode == 200) {
            final singleData = jsonDecode(singleRes.body);
            final resData = singleData['data'] ?? singleData['order'];
            if (resData != null && resData is Map) {
              matchingOrder = Map<String, dynamic>.from(resData);
              final String st = (matchingOrder['status'] ?? matchingOrder['order_status'] ?? '').toString().toUpperCase();
              if (st == 'COMPLETED' || st == 'PAID' || st == 'CLOSED' || st == 'SETTLED') {
                currentOrderCompleted = true;
              }
            }
          }
        } catch (_) {}
      }

      // 2. Live orders check para sa session (Explicit match para iwas cross-ticket leak)
      final String liveUrl = sessionId != null
          ? '$_baseUrl/api/v1/customer/orders/live?table_id=$tableNum&session_id=$sessionId'
          : '$_baseUrl/api/v1/customer/orders/live?table_id=$tableNum';

      try {
        final response = await http.get(Uri.parse(liveUrl));
        if (response.statusCode == 200) {
          final dynamic decodedResponse = jsonDecode(response.body);
          final dynamic responseData = decodedResponse is Map
              ? decodedResponse['data'] ?? decodedResponse['orders'] ?? decodedResponse
              : decodedResponse;

          final List<Map<String, dynamic>> ordersList = _orderListFrom(
            responseData is Map ? responseData['orders'] : responseData,
          );

          if (ordersList.isNotEmpty) {
            sessionGrandTotal = ordersList.fold(0.0, (sum, ord) {
              return sum + (double.tryParse(ord['total_amount']?.toString() ?? ord['order_total']?.toString() ?? '0') ?? 0.0);
            });

            bool allCompleted = ordersList.isNotEmpty;
            for (final ord in ordersList) {
              final String st = (ord['status'] ?? ord['order_status'] ?? '').toString().toUpperCase();
              if (!(st == 'COMPLETED' || st == 'PAID' || st == 'CLOSED' || st == 'SETTLED')) {
                allCompleted = false;
                break;
              }
            }
            if (ordersList.isNotEmpty && allCompleted) {
              sessionWideCompleted = true;
            }

            // EXPLICIT MATCHING gamit ang firstWhere para iwas state overwrite at orders[0] assumptions
            if (targetOrderId != null) {
              final targetIdStr = targetOrderId.toString().replaceAll('#BS-', '').trim();
              final int? targetInt = int.tryParse(targetIdStr);

              try {
                final foundOrder = ordersList.firstWhere((o) {
                  final idStr = (o['order_id'] ?? o['id'] ?? '').toString().replaceAll('#BS-', '').trim();
                  final int? idInt = int.tryParse(idStr);
                  return idStr.isNotEmpty && (idStr == targetIdStr || (targetInt != null && idInt != null && targetInt == idInt));
                });
                matchingOrder = Map<String, dynamic>.from(foundOrder);
                final String st = (matchingOrder['status'] ?? matchingOrder['order_status'] ?? '').toString().toUpperCase();
                if (st == 'COMPLETED' || st == 'PAID' || st == 'CLOSED' || st == 'SETTLED') {
                  currentOrderCompleted = true;
                }
              } catch (_) {}
            }
          }
        }
      } catch (_) {}

      if (matchingOrder == null && targetOrderId != null) {
        matchingOrder = {
          'order_id': targetOrderId,
          'id': targetOrderId,
          'total_amount': widget.totalAmount > 0 ? widget.totalAmount : UserSession.lastPlacedOrderTotal,
          'order_status': 'PENDING',
          'items': widget.initialOrderItems ?? UserSession.lastPlacedOrderItems,
        };
      }

      if (currentOrderCompleted || sessionWideCompleted) {
        final String codeToUse = _fetchedOrderCode.isNotEmpty
            ? _fetchedOrderCode
            : UserSession.formatOrderCode(targetOrderId);
        _showSessionFinishedDialog(codeToUse);
      }

      if (matchingOrder != null && mounted) {
        final bool isAdditional = widget.isAdditionalOrder;
        final double orderTotal = double.tryParse(
          (matchingOrder['total_amount'] ?? matchingOrder['order_total'] ?? matchingOrder['grand_total'])?.toString() ?? '0',
        ) ?? 0.0;

        double calculatedItemsTotal = 0.0;
        final List<dynamic> rawItems = matchingOrder['items'] is List ? matchingOrder['items'] : [];

        if (rawItems.isNotEmpty) {
          for (final item in rawItems) {
            final double unitPrice = double.tryParse(item['unit_price']?.toString() ?? item['price']?.toString() ?? '0') ?? 0.0;
            final int qty = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;

            double addonSum = 0.0;
            if (item['addons'] is List) {
              for (final addon in item['addons']) {
                addonSum += double.tryParse(addon['price']?.toString() ?? '0') ?? 0.0;
              }
            }
            calculatedItemsTotal += (unitPrice + addonSum) * qty;
          }
        }

        final double singleOrderTotal = orderTotal > 0 ? orderTotal : (calculatedItemsTotal > 0 ? calculatedItemsTotal : widget.totalAmount);

        final double finalTotal = isAdditional
            ? (singleOrderTotal > 0 ? singleOrderTotal : (sessionGrandTotal > 0 ? sessionGrandTotal : UserSession.lastPlacedOrderTotal))
            : (singleOrderTotal > 0 ? singleOrderTotal : UserSession.lastPlacedOrderTotal);

        final String serverStatus = (matchingOrder['status'] ?? matchingOrder['order_status'] ?? 'PENDING').toString().toUpperCase();
        final String reasonStr = (matchingOrder['decline_reason'] ?? matchingOrder['reason'] ?? '').toString();
        if (reasonStr.isNotEmpty) {
          _declineReason = reasonStr;
        }

        final int currentPriority = _getStatusPriority(_currentOrderStatus);
        final int serverPriority = _getStatusPriority(serverStatus);
        final String effectiveStatus = serverPriority >= currentPriority ? serverStatus : _currentOrderStatus;

        final String code = matchingOrder['order_code'] ?? _formatOrderCode(targetOrderId);

        if (rawItems.isNotEmpty) {
          sessionItems = rawItems;
        } else if (_fetchedOrderItems.isNotEmpty) {
          sessionItems = _fetchedOrderItems;
        } else {
          sessionItems = UserSession.lastPlacedOrderItems;
        }

        String timeStr = 'Today';
        if (matchingOrder['created_at'] != null || matchingOrder['time'] != null) {
          try {
            final timeVal = matchingOrder['created_at'] ?? matchingOrder['time'];
            final dt = DateTime.parse(timeVal.toString()).toLocal();
            final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
            final min = dt.minute.toString().padLeft(2, '0');
            final ampm = dt.hour >= 12 ? 'PM' : 'AM';
            timeStr = '$hour:$min $ampm • Today';
          } catch (_) {
            timeStr = matchingOrder['time']?.toString() ?? 'Today';
          }
        }

        setState(() {
          _hasActiveOrder = true;
          _fetchedTotalAmount = finalTotal > 0 ? finalTotal : (UserSession.lastPlacedOrderTotal > 0 ? UserSession.lastPlacedOrderTotal : widget.totalAmount);
          _fetchedOrderCode = code;
          _formattedTimestamp = timeStr;
          _fetchedOrderItems = sessionItems;
          _isLoadingLiveOrder = false;
          _applyStatusValues(effectiveStatus);
        });
        return;
      }
    } catch (_) {}

    if (mounted) {
      final dynamic effectiveOrderId = widget.orderId ?? UserSession.lastPlacedOrderId ?? UserSession.targetParentOrderId;
      final bool fallbackHasValidOrder = effectiveOrderId != null;
      final double effectiveTotal = widget.totalAmount > 0
          ? widget.totalAmount
          : (UserSession.lastPlacedOrderTotal > 0 ? UserSession.lastPlacedOrderTotal : 0.0);

      final dt = DateTime.now();
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final min = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';

      setState(() {
        _hasActiveOrder = fallbackHasValidOrder;
        _fetchedTotalAmount = effectiveTotal;
        _fetchedOrderCode = _formatOrderCode(effectiveOrderId);
        _formattedTimestamp = '$hour:$min $ampm • Today';
        if (_fetchedOrderItems.isEmpty) {
          _fetchedOrderItems = UserSession.lastPlacedOrderItems;
        }
        _isLoadingLiveOrder = false;
      });
    }
  }

  void _connectRepositorySocketStream() {
    _repositorySocketGateway = io.io(
      _baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .enableAutoConnect()
          .build(),
    );

    _repositorySocketGateway.onConnect((_) {
      final int tableNum = widget.tableId ?? UserSession.activeTableId ?? UserSession.activeTableNumber ?? 7;
      _repositorySocketGateway.emit('join_room', 'table_$tableNum');

      final int? sessionId = UserSession.activeSessionId ??
          (UserSession.sessionId != null ? int.tryParse(UserSession.sessionId!) : null);
      if (sessionId != null) {
        _repositorySocketGateway.emit('join_room', 'session_$sessionId');
      }

      final dynamic activeOrderId = widget.orderId ?? UserSession.lastPlacedOrderId ?? UserSession.targetParentOrderId;
      if (activeOrderId != null) {
        _repositorySocketGateway.emit('join_room', activeOrderId.toString());
      }
    });

    _repositorySocketGateway.on('order_updated', _applyLiveOrderUpdate);
    _repositorySocketGateway.on('order_status_updated', _applyLiveOrderUpdate);
    _repositorySocketGateway.on('orderStatusUpdated', _applyLiveOrderUpdate);
    _repositorySocketGateway.on('new_order', _applyLiveOrderUpdate);
    _repositorySocketGateway.on('additional_items_added', _applyLiveOrderUpdate);
    _repositorySocketGateway.on('order_paid', _handleSessionClosed);
    _repositorySocketGateway.on('bill_requested', _applyLiveOrderUpdate);
    _repositorySocketGateway.on('session_cancelled', _handleSessionClosed);
    _repositorySocketGateway.on('table_session_closed', _handleSessionClosed);
    _repositorySocketGateway.connect();
  }

  bool _dialogShown = false;
  bool _hasTriggeredCompletion = false;
  bool _declineDialogShown = false;

  void _showSessionFinishedDialog(String orderCode) {
    if (_dialogShown || _hasTriggeredCompletion || !mounted) return;
    _dialogShown = true;
    _hasTriggeredCompletion = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFFFFFDFA),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Order Session Finished', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF203F35))),
          content: Text('This order session ($orderCode) has been settled and finished.'),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF203F35)),
              onPressed: () {
                Navigator.pop(ctx);
                UserSession.clearSession();
                _navigateToMenu();
              },
              child: const Text('Back to Selection', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    });
  }

  void _showOrderDeclinedDialog(String declineReason) {
    if (_declineDialogShown || !mounted) return;
    _declineDialogShown = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
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
                'Pasensya na po, ang inyong order (${_fetchedOrderCode.isNotEmpty ? _fetchedOrderCode : UserSession.formatOrderCode(widget.orderId ?? UserSession.lastPlacedOrderId)}) ay na-decline ng kitchen/admin.',
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
                  'Reason: ${declineReason.isNotEmpty ? declineReason : "Item Out of Stock"}',
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
                _navigateToMenu();
              },
              child: const Text('Acknowledge / Back to Menu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    });
  }

  void _applyStatusValues(String status) {
    _currentOrderStatus = status;
    switch (status) {
      case 'NEW':
        _statusBadgeLabel = 'New Order Received';
        _stepperProgressIndex = 0;
        break;
      case 'PENDING':
        _statusBadgeLabel = 'Pending review';
        _stepperProgressIndex = 0;
        break;
      case 'PREPARING':
        _statusBadgeLabel = 'Preparing in Kitchen';
        _stepperProgressIndex = 1;
        break;
      case 'READY':
        _statusBadgeLabel = 'Ready for service';
        _stepperProgressIndex = 2;
        break;
      case 'SERVED':
        _statusBadgeLabel = 'Served';
        _stepperProgressIndex = 2;
        break;
      case 'COMPLETED':
      case 'PAID':
      case 'CLOSED':
      case 'SETTLED':
        _statusBadgeLabel = 'Paid';
        _stepperProgressIndex = 3;
        final dynamic targetId = widget.orderId ?? UserSession.lastPlacedOrderId ?? UserSession.targetParentOrderId;
        _showSessionFinishedDialog(_fetchedOrderCode.isNotEmpty ? _fetchedOrderCode : UserSession.formatOrderCode(targetId));
        break;
      case 'REJECTED':
      case 'DECLINED':
        _statusBadgeLabel = 'Order Declined';
        _stepperProgressIndex = 0;
        _showOrderDeclinedDialog(_declineReason.isNotEmpty ? _declineReason : 'Item Out of Stock');
        break;
      case 'CANCELLED':
      case 'SESSION_CANCELLED':
        _statusBadgeLabel = 'Cancelled';
        _stepperProgressIndex = 0;
        break;
      default:
        _statusBadgeLabel = 'Pending review';
        _stepperProgressIndex = 0;
    }
  }

  void _applyLiveOrderUpdate(dynamic eventPayloadData) {
    if (eventPayloadData == null || !mounted) return;

    final Map<String, dynamic> data = eventPayloadData is Map<String, dynamic>
        ? eventPayloadData
        : Map<String, dynamic>.from(eventPayloadData as Map);

    final int currentTable = widget.tableId ?? UserSession.activeTableId ?? UserSession.activeTableNumber ?? 7;
    final Map<String, dynamic> orderPayload = data['order'] is Map ? Map<String, dynamic>.from(data['order']) : data;

    final int? eventTableId = int.tryParse(orderPayload['table_id']?.toString() ?? orderPayload['table_number']?.toString() ?? data['table_id']?.toString() ?? '');
    final dynamic eventOrderId = orderPayload['order_id'] ?? orderPayload['id'] ?? data['order_id'] ?? data['id'];
    final dynamic eventSessionId = orderPayload['session_id'] ?? data['session_id'];

    if (eventTableId != null && eventTableId != currentTable) {
      return;
    }

    final dynamic targetOrderId = widget.orderId ?? UserSession.lastPlacedOrderId ?? UserSession.targetParentOrderId;
    if (eventOrderId != null && targetOrderId != null) {
      if (eventOrderId.toString().replaceAll('#BS-', '').trim() != targetOrderId.toString().replaceAll('#BS-', '').trim()) {
        return; // Huwag galawin o i-trigger kung para sa ibang ticket/order!
      }
    }

    if (eventSessionId != null) {
      UserSession.activeSessionId = int.tryParse(eventSessionId.toString());
      UserSession.sessionId = eventSessionId.toString();
    }

    if (eventOrderId != null) {
      UserSession.lastPlacedOrderId = eventOrderId;
    }

    final String status = (orderPayload['status'] ?? orderPayload['order_status'] ?? data['status'] ?? data['order_status'] ?? '').toString().toUpperCase();
    final String rStr = (orderPayload['decline_reason'] ?? orderPayload['reason'] ?? data['decline_reason'] ?? data['reason'] ?? '').toString();
    if (rStr.isNotEmpty) {
      _declineReason = rStr;
    }

    setState(() {
      _showLiveTrackerView = true;
      if (status.isNotEmpty) {
        _applyStatusValues(status);
      }
    });

    _fetchLatestOrderFromBackend();
  }

  void _handleSessionClosed(dynamic eventPayloadData) {
    if (!mounted) return;
    
    // STRICT TICKET MATCHING: Suriin muna kung ang eventOrderId ay tumutugma sa kasalukuyang tinitingnang ticket
    final Map<String, dynamic> data = eventPayloadData is Map<String, dynamic>
        ? eventPayloadData
        : (eventPayloadData is Map ? Map<String, dynamic>.from(eventPayloadData) : {});
    final Map<String, dynamic> orderPayload = data['order'] is Map ? Map<String, dynamic>.from(data['order']) : data;

    final int currentTable = widget.tableId ?? UserSession.activeTableId ?? UserSession.activeTableNumber ?? 7;
    final int? eventTableId = int.tryParse(orderPayload['table_id']?.toString() ?? orderPayload['table_number']?.toString() ?? data['table_id']?.toString() ?? '');
    final dynamic eventOrderId = orderPayload['order_id'] ?? orderPayload['id'] ?? data['order_id'] ?? data['id'];

    if (eventTableId != null && eventTableId != currentTable) {
      return;
    }

    final dynamic targetOrderId = widget.orderId ?? UserSession.lastPlacedOrderId ?? UserSession.targetParentOrderId;
    if (eventOrderId != null && targetOrderId != null) {
      if (eventOrderId.toString().replaceAll('#BS-', '').trim() != targetOrderId.toString().replaceAll('#BS-', '').trim()) {
        return; // Huwag galawin o i-trigger kung para sa ibang ticket/order!
      }
    }

    final dynamic targetId = widget.orderId ?? UserSession.lastPlacedOrderId ?? UserSession.targetParentOrderId;
    _showSessionFinishedDialog(_fetchedOrderCode.isNotEmpty ? _fetchedOrderCode : UserSession.formatOrderCode(targetId));
  }

  @override
  void dispose() {
    _statusPollTimer?.cancel();
    try {
      _repositorySocketGateway.disconnect();
      _repositorySocketGateway.dispose();
    } catch (_) {}
    super.dispose();
  }

  void _navigateToMenu() {
    final int tableNum = widget.tableId ?? UserSession.activeTableId ?? UserSession.activeTableNumber ?? 7;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => OrderTypeSelectionScreen(
          tableId: tableNum,
          tableNumber: tableNum,
        ),
      ),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final int tableNum =
        widget.tableId ??
            UserSession.activeTableId ??
            UserSession.activeTableNumber ??
            7;
    final String tableString = widget.isTakeout
        ? 'Takeout'
        : 'Table ${tableNum.toString().padLeft(2, '0')}';
    final String displayOrderCode = _fetchedOrderCode.isNotEmpty
        ? _fetchedOrderCode
        : _formatOrderCode(widget.orderId);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFFFFFDFA),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Text('End Session?', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF203F35))),
            content: const Text('Are you sure to end this session?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No', style: TextStyle(color: Color(0xFF788078))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF203F35)),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Yes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
        if (shouldExit == true && context.mounted) {
          UserSession.clearSession();
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const QrScannerScreen()),
                (route) => false,
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F4EC),
        body: SafeArea(
          child: Column(
            children: [
              _buildRestaurantHeader(),
              _buildTableContextStrip(tableString),
              Expanded(
                child: _isLoadingLiveOrder
                    ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF203F35),
                  ),
                )
                    : !_hasActiveOrder
                    ? _buildNoOrderView()
                    : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 16.0,
                  ),
                  child: _showLiveTrackerView
                      ? _buildLiveStatusTrackerView(
                    displayOrderCode,
                    tableString,
                  )
                      : _buildConfirmationView(
                    displayOrderCode,
                    tableString,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoOrderView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFEEE7D9),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE5DFD3)),
            ),
            child: const Center(
              child: Icon(
                Icons.receipt_long_outlined,
                size: 38,
                color: Color(0xFFA47C3D),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'NO ACTIVE ORDERS YET',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFFA47C3D),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ready to explore our menu?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF203F35),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'You have no active orders in progress for this table. Browse our traditional offerings and place an order to get started.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF788078),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF203F35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              onPressed: _navigateToMenu,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Browse Heritage Menu',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                ],
              ),
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
            onTap: _navigateToMenu,
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
          Column(
            children: [
              Container(
                width: 26,
                height: 22,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFFA47C3D),
                    width: 1.4,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.home_outlined,
                  size: 14,
                  color: Color(0xFFA47C3D),
                ),
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
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.point_of_sale_outlined,
                  color: Color(0xFF203F35),
                  size: 22,
                ),
                tooltip: 'Cashier Station',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const OrdersScreen(cartItems: []),
                  ),
                ),
              ),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AssistanceScreen(),
                    ),
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
                  child: const Icon(
                    Icons.notifications_outlined,
                    color: Color(0xFF203F35),
                    size: 20,
                  ),
                ),
              ),
            ],
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
                '$tableString verified',
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

  Widget _buildConfirmationView(String orderCode, String tableString) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF0E9),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE5DFD3)),
          ),
          child: const Center(
            child: Icon(Icons.check, size: 36, color: Color(0xFF203F35)),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'SUCCESSFULLY SUBMITTED',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFFA47C3D),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Your order is in good hands.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF203F35),
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Salamat! Your request has reached the restaurant and is awaiting review.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Color(0xFF788078), height: 1.4),
        ),
        const SizedBox(height: 24),
        _buildOrderSummaryCard(orderCode, tableString),
        const SizedBox(height: 16),
        _buildContextInfoBox(),
        const SizedBox(height: 28),
        _buildConfirmationActionButtons(),
      ],
    );
  }

  Widget _buildOrderSummaryCard(String orderCode, String tableString) {
    final timeString = _formattedTimestamp.isNotEmpty
        ? _formattedTimestamp
        : '11:49 AM • Today';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDFA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5DFD3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEEE7D9),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.access_time,
                  size: 13,
                  color: Color(0xFFA47C3D),
                ),
                const SizedBox(width: 6),
                Text(
                  _statusBadgeLabel,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFA47C3D),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'TABLE SESSION RECEIPT',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFFA47C3D),
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            orderCode,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFF203F35),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Table',
                style: TextStyle(fontSize: 12, color: Color(0xFF788078)),
              ),
              Text(
                tableString,
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
                'Submitted',
                style: TextStyle(fontSize: 12, color: Color(0xFF788078)),
              ),
              Text(
                timeString,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF203F35),
                ),
              ),
            ],
          ),
          if (_fetchedOrderItems.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10.0),
              child: Divider(height: 1, color: Color(0xFFE5DFD3)),
            ),
            ..._fetchedOrderItems.map((item) {
              final itemName = item['name'] ??
                  item['item_name'] ??
                  item['product_name'] ??
                  item['food_name'] ??
                  item['title'] ??
                  (item['menu_item'] is Map ? (item['menu_item']['name'] ?? item['menu_item']['title']) : null) ??
                  'Item';

              final int qty = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
              final double unitPrice =
                  double.tryParse(item['unit_price']?.toString() ?? item['price']?.toString() ?? '0') ?? 0.0;

              final List addons = item['addons'] is List
                  ? item['addons'] as List
                  : const [];
              final double addonTotal =
                  double.tryParse(item['addon_total']?.toString() ?? '') ??
                      addons.fold<double>(
                        0,
                            (sum, addon) =>
                        sum +
                            (double.tryParse(addon['price']?.toString() ?? '0') ??
                                0),
                      );
              final double lineTotal =
                  double.tryParse(item['line_total']?.toString() ?? '') ??
                      (unitPrice + addonTotal) * qty;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '$itemName (x$qty)',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF24382F),
                            ),
                          ),
                        ),
                        Text(
                          '₱${lineTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF203F35),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '₱${unitPrice.toStringAsFixed(2)} each',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF788078),
                      ),
                    ),
                    ...addons.map(
                          (addon) => Padding(
                        padding: const EdgeInsets.only(left: 8, top: 2),
                        child: Text(
                          '+ ${addon['name'] ?? 'Add-on'} · ₱${(double.tryParse(addon['price']?.toString() ?? '0') ?? 0).toStringAsFixed(2)} each',
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
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14.0),
            child: Divider(height: 1, color: Color(0xFFE5DFD3)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Order Total Amount',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF24382F),
                ),
              ),
              Text(
                '₱${_fetchedTotalAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF203F35),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContextInfoBox() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF0E9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Color(0xFF53766C), size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Pending means received, not yet accepted. Watch Live Status for the restaurant’s next update.',
              style: TextStyle(
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

  Widget _buildConfirmationActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF203F35),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            onPressed: () {
              setState(() => _showLiveTrackerView = true);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'View live status',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward, color: Colors.white, size: 18),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: _navigateToMenu,
            child: const Text(
              'Back to menu',
              style: TextStyle(
                color: Color(0xFF203F35),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLiveStatusTrackerView(String orderCode, String tableString) {
    String stageTitle = 'Your order is being reviewed.';
    String stageCopy = 'We are confirming item availability with the kitchen.';
    IconData badgeIcon = Icons.access_time;
    Color badgeBg = const Color(0xFFEEE7D9);
    Color badgeFg = const Color(0xFFA47C3D);

    if (_currentOrderStatus == 'COMPLETED' || _currentOrderStatus == 'PAID' || _currentOrderStatus == 'CLOSED' || _currentOrderStatus == 'SETTLED') {
      stageTitle = 'Payment complete.';
      stageCopy = 'Your table session receipt has been paid and closed.';
      badgeIcon = Icons.check_circle_outline;
      badgeBg = const Color(0xFFEAF0E9);
      badgeFg = const Color(0xFF203F35);
    } else if (_currentOrderStatus == 'DECLINED' || _currentOrderStatus == 'REJECTED') {
      stageTitle = 'Order Rejected';
      stageCopy = _declineReason.isNotEmpty ? 'Reason: $_declineReason' : 'Please contact a team member if you need help.';
      badgeIcon = Icons.cancel_outlined;
      badgeBg = const Color(0xFFFEE2E2);
      badgeFg = const Color(0xFFEF4444);
    } else if (_sessionWasClosed) {
      stageTitle = 'This table session is closed.';
      stageCopy = 'The active session is no longer accepting new items.';
      badgeIcon = Icons.lock_outline;
      badgeBg = const Color(0xFFEAF0E9);
      badgeFg = const Color(0xFF203F35);
    } else if (_currentOrderStatus == 'CANCELLED' ||
        _currentOrderStatus == 'DECLINED') {
      stageTitle = 'This order was cancelled.';
      stageCopy = 'Please contact a team member if you need help.';
    } else if (_stepperProgressIndex == 1) {
      stageTitle = 'Chefs are cooking your meal.';
      stageCopy =
      'Your order is being sizzlingly prepared in our heritage kitchen.';
      badgeIcon = Icons.soup_kitchen_outlined;
      badgeBg = const Color(0xFFEAF0E9);
      badgeFg = const Color(0xFF203F35);
    } else if (_stepperProgressIndex == 2) {
      stageTitle = 'Your food is served!';
      stageCopy =
      'Enjoy your meal at $tableString. Need anything else? Call a waiter anytime.';
      badgeIcon = Icons.restaurant_outlined;
      badgeBg = const Color(0xFFEAF0E9);
      badgeFg = const Color(0xFF203F35);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                children: [
                  Icon(badgeIcon, size: 13, color: badgeFg),
                  const SizedBox(width: 6),
                  Text(
                    _statusBadgeLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: badgeFg,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _repositorySocketGateway.connected
                  ? 'Live updates'
                  : 'Reconnecting…',
              style: const TextStyle(fontSize: 10, color: Color(0xFF788078)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'LIVE STATUS',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFFA47C3D),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          stageTitle,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF203F35),
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          stageCopy,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF788078),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFDFA),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE5DFD3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order Number: $orderCode',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF203F35),
                ),
              ),
              Text(
                'Total: ₱${_fetchedTotalAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF203F35),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
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
              const Text(
                'Order Progress',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF24382F),
                ),
              ),
              const SizedBox(height: 16),
              _buildProgressTimeline(),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF203F35),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            onPressed: _navigateToMenu,
            child: const Text(
              'Back to menu',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressTimeline() {
    final steps = [
      {
        'title': 'Received & Pending',
        'subtitle': 'Your order code has been sent to our kitchen team.',
      },
      {
        'title': 'Preparing in Kitchen',
        'subtitle': 'Our chefs are actively cooking your fresh plates.',
      },
      {
        'title': 'Served',
        'subtitle': widget.isTakeout
            ? 'Your order is ready for pickup at the counter.'
            : 'Dispatched cleanly to your chosen table position.',
      },
      {
        'title': 'Paid & Closed',
        'subtitle': 'Your unified table receipt has been settled.',
      },
    ];

    return Column(
      children: List.generate(steps.length, (index) {
        final isActive = _stepperProgressIndex >= index;
        final isCurrentStage = _stepperProgressIndex == index;
        final isLast = index == steps.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive
                        ? const Color(0xFF203F35)
                        : const Color(0xFFF8F4EC),
                    border: Border.all(
                      color: isActive
                          ? const Color(0xFF203F35)
                          : const Color(0xFFE5DFD3),
                    ),
                  ),
                  child: Center(
                    child: isActive
                        ? (isCurrentStage
                            ? Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFD7BC86),
                                  shape: BoxShape.circle,
                                ),
                              )
                            : const Icon(
                                Icons.check,
                                size: 14,
                                color: Colors.white,
                              ))
                        : Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE5DFD3),
                              shape: BoxShape.circle,
                            ),
                          ),
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 38,
                    color: _stepperProgressIndex > index
                        ? const Color(0xFF53766C)
                        : const Color(0xFFE5DFD3),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2.0, bottom: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      steps[index]['title']!,
                      style: TextStyle(
                        fontWeight: isCurrentStage
                            ? FontWeight.bold
                            : FontWeight.w500,
                        fontSize: 13,
                        color: isActive
                            ? const Color(0xFF24382F)
                            : const Color(0xFF788078),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      steps[index]['subtitle']!,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF788078),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}