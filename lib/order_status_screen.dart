import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

import 'menu_screen.dart';
import 'session_bill_screen.dart';
import '../widgets/customer_bottom_nav.dart';
import '../widgets/finished_order_dialog.dart';
import 'user_session.dart';
import 'services/audio_notification_service.dart';
import 'services/global_socket_listener.dart';
import 'services/socket_service.dart';
import 'services/order_context.dart';
import 'services/order_event_bus.dart';
import 'services/order_event_router.dart';
import 'config/api_config.dart';

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
  Timer? _statusPollTimer;
  int? _refreshToken;
  int? _contextToken;
  String _statusBadgeLabel = "Pending review";
  String _currentOrderStatus = 'PENDING';
  int _stepperProgressIndex = 0;
  bool _showLiveTrackerView = false;
  bool _isLoadingLiveOrder = true;
  bool _hasActiveOrder = true;
  bool _sessionWasClosed = false;
  bool _billRequested = false;

  static const Set<String> _terminalBillStatuses = <String>{
    'PAID',
    'COMPLETED',
    'CLOSED',
    'SETTLED',
    'CANCELLED',
    'DECLINED',
    'REJECTED',
  };

  double _fetchedTotalAmount = 0.0;
  String _fetchedOrderCode = '';
  String _formattedTimestamp = '';
  List<dynamic> _fetchedOrderItems = [];
  String _declineReason = '';
  String _lastAppliedStatus = '';
  String? _lastStatusOrderKey;

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

  String get _baseUrl => ApiConfig.baseUrl;

  @override
  void initState() {
    super.initState();
    _fetchedTotalAmount = widget.totalAmount > 0 ? widget.totalAmount : UserSession.lastPlacedOrderTotal;
    _fetchedOrderItems = widget.initialOrderItems ?? UserSession.lastPlacedOrderItems;
    _connectRepositorySocketStream();
    _contextToken = OrderContext.instance.enter(
      mode: CustomerOrderMode.viewingOrder,
      viewingOrderId: widget.orderId ?? UserSession.lastPlacedOrderId,
      viewedParentId: UserSession.targetParentOrderId,
    );
    _refreshToken = OrderEventBus.instance.subscribeRefresh(() {
      if (mounted) _fetchLatestOrderFromBackend();
    });
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
      OrderContext.instance.update(
        viewingOrderId: widget.orderId ?? UserSession.lastPlacedOrderId,
        viewedParentId: UserSession.targetParentOrderId,
      );
      setState(() {
        _isLoadingLiveOrder = true;
        _fetchedTotalAmount = widget.totalAmount > 0 ? widget.totalAmount : UserSession.lastPlacedOrderTotal;
        _fetchedOrderItems = widget.initialOrderItems ?? UserSession.lastPlacedOrderItems;
        _lastAppliedStatus = '';
        _lastStatusOrderKey = null;
        _currentOrderStatus = 'PENDING';
        _billRequested = false;
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

      // 1. Direct endpoint check para sa kasalukuyang tinitingnang ticket
      if (targetOrderId != null) {
        try {
          final singleRes = await http.get(Uri.parse('$_baseUrl/api/v1/orders/$targetOrderId')).timeout(const Duration(seconds: 10));
          if (singleRes.statusCode == 200) {
            final singleData = jsonDecode(singleRes.body);
            final resData = singleData['data'] ?? singleData['order'];
            if (resData != null && resData is Map) {
              matchingOrder = Map<String, dynamic>.from(resData);
            }
          }
        } catch (_) {}
      }

      // 2. Live orders check para sa session (Explicit match para iwas cross-ticket leak)
      final String liveUrl = sessionId != null
          ? '$_baseUrl/api/v1/customer/orders/live?table_id=$tableNum&session_id=$sessionId'
          : '$_baseUrl/api/v1/customer/orders/live?table_id=$tableNum';

      try {
        final response = await http.get(Uri.parse(liveUrl)).timeout(const Duration(seconds: 10));
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

            // EXPLICIT MATCHING gamit ang firstWhere para iwas state overwrite at orders[0] assumptions
            if (targetOrderId != null) {
              try {
                final foundOrder = ordersList.firstWhere((o) {
                  final dynamic orderEntityId = o['order_id'] ?? o['id'];
                  return orderEntityId != null && SocketService.isSameOrder(orderEntityId, targetOrderId);
                });
                matchingOrder = Map<String, dynamic>.from(foundOrder);
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

      // Ang "Finished Order" pop-up ay hawak ng OrderEventRouter (OrderContext
      // ang nagdedesisyon kung konektado ang ticket). Dito, status update lang.

      if (matchingOrder != null && mounted) {
        final Map<String, dynamic> orderData = matchingOrder;
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
        // The monotonic clamp is only valid while watching the SAME ticket.
        // Kapag bagong order ang tinitingnan, ang server status ang masusunod
        // para hindi manatiling COMPLETED ang bagong PENDING order.
        final String orderKey = (targetOrderId ?? '').toString();
        final bool isSameOrder = _lastStatusOrderKey != null && _lastStatusOrderKey == orderKey;
        final String effectiveStatus = isSameOrder && serverPriority < currentPriority
            ? _currentOrderStatus
            : serverStatus;
        _lastStatusOrderKey = orderKey;

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

          // I-restore ang bill-requested state mula sa server para tama pa rin
          // ito pag nag-refresh o bumalik ang customer sa screen.
          if (orderData.containsKey('bill_requested_at')) {
            final bool hasBillRequest =
                orderData['bill_requested_at'] != null;
            final bool isTerminal =
                _terminalBillStatuses.contains(serverStatus) ||
                    _terminalBillStatuses.contains(effectiveStatus);
            _billRequested =
                hasBillRequest && !isTerminal && !_sessionWasClosed;
          }

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
    // Single global socket (GlobalSocketListener) — hindi na UI-bound ang
    // OrderStatusScreen para maging consistent ang lahat ng customer notifications.
    GlobalSocketListener.instance.start(context: context);
    GlobalSocketListener.instance.registerTableIdentity(
      tableId: widget.tableId,
      tableNumber: UserSession.activeTableNumber,
    );
    GlobalSocketListener.instance.setOnSessionClosed((data) => _handleSessionClosed(data));
    GlobalSocketListener.instance.setOnBillRequested((data) => _handleBillRequested(data));
  }

  bool _dialogShown = false;
  bool _hasTriggeredCompletion = false;

  void _showSessionFinishedDialog(String orderCode) {
    if (_dialogShown || _hasTriggeredCompletion || !mounted) return;
    _dialogShown = true;
    _hasTriggeredCompletion = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        FinishedOrderDialog.show(
          orderCode: orderCode,
          orderId: UserSession.formatOrderCode(
            widget.orderId ?? UserSession.lastPlacedOrderId ?? UserSession.targetParentOrderId,
          ),
        ),
      );
    });
  }

  void _applyStatusValues(String status) {
    final String normalizedStatus = status.toUpperCase();
    // Only treat it as a NEW status transition when the status actually changed.
    // This prevents duplicate dialogs/notifications when the same status is
    // re-applied (e.g. duplicate socket events, polling refreshes, refetches).
    final bool isStatusTransition = _lastAppliedStatus.isEmpty || _lastAppliedStatus != normalizedStatus;

    // Polling fallback: kapag socket ang namatay, dito pa rin lalabas ang
    // banner (dedupe key ay pareho sa central socket path kaya walang doble).
    if (isStatusTransition && _lastAppliedStatus.isNotEmpty && normalizedStatus.isNotEmpty) {
      OrderEventRouter.instance.onStatusObserved(
        status: normalizedStatus,
        orderId: widget.orderId ?? UserSession.lastPlacedOrderId ?? UserSession.targetParentOrderId,
        orderCode: _fetchedOrderCode,
        reason: _declineReason,
        parentOrderId: UserSession.targetParentOrderId,
        eventType: 'poll',
      );
    }

    _lastAppliedStatus = normalizedStatus;
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
        _billRequested = false; // Na-settle na ang bill/session — bumalik sa normal na state.
        break;
      case 'REJECTED':
      case 'DECLINED':
        _statusBadgeLabel = 'Order Declined';
        _stepperProgressIndex = 0;
        // Pop-up ay hawak na ng OrderEventRouter (via onStatusObserved sa
        // itaas) para pareho ang behavior sa socket at polling at walang doble.
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

  /// Lock ang customer UI sa "Bill Requested / Receipt Summary" state kapag
  /// nakarating sa backend ang bill request para sa kasalukuyang session.
  void _handleBillRequested(dynamic dataPayload) {
    if (!mounted) return;
    
    if (dataPayload != null) {
      final Map<String, dynamic> data = dataPayload is Map<String, dynamic>
          ? dataPayload
          : (dataPayload is Map ? Map<String, dynamic>.from(dataPayload) : {});
          
      final dynamic eventSessionId = data['session_id'];

      // Strict scoping
      if (!GlobalSocketListener.instance.isEventForCurrentTable(data, data)) return;
      if (eventSessionId != null && data['table_id'] == null && data['table_number'] == null) {
        final int? currentSessionId = UserSession.activeSessionId ?? int.tryParse(UserSession.sessionId ?? '');
        if (currentSessionId != null && int.tryParse(eventSessionId.toString()) != currentSessionId) {
          return;
        }
      }

      // Spoke isolation: ignore bill events that don't belong to the tracked order.
      final dynamic eventBillOrderId = data['order_id'] ?? data['id'];
      final dynamic currentBillTargetOrderId = widget.orderId ?? UserSession.lastPlacedOrderId ?? UserSession.targetParentOrderId;
      if (eventBillOrderId != null && currentBillTargetOrderId != null) {
        if (!SocketService.isSameOrder(eventBillOrderId, currentBillTargetOrderId)) {
          return;
        }
      }
    }

    // Kung terminal na ang order o sarado na ang session, huwag nang i-lock
    // ang UI sa "Bill Requested" — tapos na ang billing cycle.
    if (_sessionWasClosed ||
        _terminalBillStatuses.contains(_currentOrderStatus.toUpperCase())) {
      return;
    }

    setState(() {
      _billRequested = true;
      _showLiveTrackerView = false;
    });
  }

  void _handleSessionClosed(dynamic eventPayloadData) {
    if (!mounted) return;
    
    // STRICT TICKET MATCHING: Suriin muna kung ang eventOrderId ay tumutugma sa kasalukuyang tinitingnang ticket
    final Map<String, dynamic> data = eventPayloadData is Map<String, dynamic>
        ? eventPayloadData
        : (eventPayloadData is Map ? Map<String, dynamic>.from(eventPayloadData) : {});
    final Map<String, dynamic> orderPayload = data['order'] is Map ? Map<String, dynamic>.from(data['order']) : data;

    final dynamic eventOrderId = orderPayload['order_id'] ?? orderPayload['id'] ?? data['order_id'] ?? data['id'];
    final dynamic eventSessionId = orderPayload['session_id'] ?? data['session_id'];

    if (!GlobalSocketListener.instance.isEventForCurrentTable(orderPayload, data)) {
      return;
    }
    
    if (eventSessionId != null && orderPayload['table_id'] == null && data['table_id'] == null) {
      final int? currentSessionId = UserSession.activeSessionId ?? int.tryParse(UserSession.sessionId ?? '');
      if (currentSessionId != null && int.tryParse(eventSessionId.toString()) != currentSessionId) {
        return;
      }
    }
    
    if (eventSessionId == null && eventOrderId == null) {
      return;
    }

    final dynamic targetOrderId = widget.orderId ?? UserSession.lastPlacedOrderId ?? UserSession.targetParentOrderId;
    if (eventOrderId != null && targetOrderId != null) {
      // Gumagamit ng normalized na comparison upang mag-handle nang maayos ng
      // integer at string ticket formats (hal. int 12 vs '#BS-0012').
      if (!SocketService.isSameOrder(eventOrderId, targetOrderId)) {
        return; // Huwag galawin o i-trigger kung para sa ibang ticket/order!
      }
    }

    final dynamic targetId = widget.orderId ?? UserSession.lastPlacedOrderId ?? UserSession.targetParentOrderId;
    setState(() {
      _sessionWasClosed = true;
      _billRequested = false;
      _showLiveTrackerView = false;
    });
    _showSessionFinishedDialog(_fetchedOrderCode.isNotEmpty ? _fetchedOrderCode : UserSession.formatOrderCode(targetId));
  }

  @override
  void dispose() {
    _statusPollTimer?.cancel();
    if (_refreshToken != null) {
      OrderEventBus.instance.unsubscribe(_refreshToken!);
      _refreshToken = null;
    }
    if (_contextToken != null) {
      OrderContext.instance.leave(_contextToken!);
      _contextToken = null;
    }
    // Session-close/bill handlers lang ang i-restore; ang order events ay
    // dumadaan na sa broadcast bus kaya walang na-clobber na handler.
    GlobalSocketListener.instance.setOnSessionClosed(GlobalSocketListener.instance.defaultOrderSessionClosed);
    GlobalSocketListener.instance.setOnBillRequested(null);
    super.dispose();
  }

  void _navigateToMenu() {
    final int tableNum = widget.tableId ??
        UserSession.activeTableId ??
        UserSession.activeTableNumber ??
        7;
    final NavigatorState nav = Navigator.of(context);
    bool foundMenu = false;
    nav.popUntil((route) {
      if (route.settings.name == 'menu') {
        foundMenu = true;
        return true;
      }
      return route.isFirst;
    });
    if (!foundMenu) {
      nav.push(
        MaterialPageRoute(
          builder: (context) => MenuScreen(
            tableId: tableNum,
            tableNumber: tableNum,
            isAdditionalOrder:
                widget.isAdditionalOrder || UserSession.isAdditionalOrder,
          ),
          settings: const RouteSettings(name: 'menu'),
        ),
      );
    }
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

    return Scaffold(
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
                    : _billRequested
                    ? _buildBillRequestedView(
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
      bottomNavigationBar: CustomerBottomNav(
        activeTab: CustomerNavTab.liveStatus,
        onMenu: _navigateToMenu,
        onCart: () {
          MenuCartIntent.requestOpen();
          _navigateToMenu();
        },
        onLiveStatus: () {},
        onBill: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SessionBillScreen(
                tableId: tableNum,
                isTakeout: widget.isTakeout,
              ),
            ),
          );
        },
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
              InkWell(
                onTap: () => AudioNotificationService.showNotificationHistory(context),
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

  /// Bill Requested / Receipt Summary state — i-lock ang customer dito kapag
  /// na-request na ang bill, imbes na bumalik sa live order tracking.
  Widget _buildBillRequestedView(String orderCode, String tableString) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF0E9),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF53766C)),
          ),
          child: const Center(
            child: Icon(Icons.receipt_long, size: 32, color: Color(0xFF203F35)),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'BILL REQUESTED',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFFA47C3D),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Bill is on the way.',
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
          'Salamat! Our staff has been notified to prepare your official receipt or collect payment.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Color(0xFF788078), height: 1.4),
        ),
        const SizedBox(height: 20),
        _buildOrderSummaryCard(orderCode, tableString),
        const SizedBox(height: 16),
        _buildContextInfoBox(),
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
                  'Back to menu',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward, color: Colors.white, size: 18),
              ],
            ),
          ),
        ),
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
              'Live updates',
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