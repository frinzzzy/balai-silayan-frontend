import 'package:flutter/material.dart';

import 'dart:async';

import 'screens/admin/models/admin_order_model.dart';
import 'screens/admin/services/admin_service.dart';
import 'screens/admin/screens/order_queue_screen.dart';
import 'screens/admin/screens/sales_analytics_screen.dart';
import 'screens/admin/screens/stock_management_screen.dart';
import 'services/socket_service.dart';
import 'services/audio_notification_service.dart';
import 'models/user_session.dart';
import 'theme/app_theme.dart';
import 'theme/admin_tokens.dart';
import 'widgets/skeleton.dart';
import 'config/api_config.dart';

import 'package:http/http.dart' as http;

import 'dart:convert';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AdminService _adminService = AdminService();
  final SocketService _socketService = SocketService();

  // 🔑 GlobalKey para direktang tawagin ang pag-refresh ng stock screen
  final GlobalKey<StockManagementScreenState> _stockScreenKey =
      GlobalKey<StockManagementScreenState>();

  bool _isLoggedIn = false;
  final bool _isApiConnected = true; // Locked to production API
  int _currentTabIndex = 0;
  bool _isLoading = false;
  bool _isLoggingIn = false;

  // Notification tracking para hindi mag-spam: seed sa unang load, tapos
  // i-notify lang ang mga bagong ticket/stock na lumitaw pagkatapos.
  final Set<int> _knownOrderIds = <int>{};
  bool _orderIdsSeeded = false;
  final Set<String> _lowStockItemIds = <String>{};
  bool _lowStockSeeded = false;
  bool _lowStockCheckInFlight = false;
  Timer? _pollTimer;
  Timer? _lowStockDebounce;

  final TextEditingController _usernameController = TextEditingController(
    text: 'admin',
  );
  final TextEditingController _passwordController = TextEditingController(
    text: 'admin123',
  );

  List<AdminOrder> _orders = [];
  DailySalesStats _salesStats = DailySalesStats(
    totalSales: 84240.0,
    totalTransactions: 72,
    cashSales: 35100.0,
    gcashSales: 49140.0,
  );

  @override
  void initState() {
    super.initState();
    if (_isLoggedIn) {
      _loadDashboardData();
      _initSocketSync();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _lowStockDebounce?.cancel();
    _socketService.disconnect();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _initSocketSync() {
    _socketService.connect(
      joinAdminRooms: true,
      onNewOrder: (_) => _loadDashboardData(silent: true),
      onOrderUpdated: (_) => _loadDashboardData(silent: true),
      onStatusUpdated: (_) => _loadDashboardData(silent: true),
      onSessionClosed: (_) => _loadDashboardData(silent: true),
      onBillRequested: (payload) => _handleBillRequestedEvent(payload),
      onStockUpdated: (_) {
        _loadDashboardData(silent: true);
        _stockScreenKey.currentState?.loadInventorySilently();
        _scheduleLowStockCheck();
      },
    );
    _startPollingFallback();
  }

  /// Backup kapag natigil/disconnected ang socket — regular refresh para hindi
  /// mawala ang new-order at bill-request alerts.
  void _startPollingFallback() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (!mounted || !_isLoggedIn) return;
      _loadDashboardData(silent: true);
    });
  }

  void _scheduleLowStockCheck() {
    _lowStockDebounce?.cancel();
    _lowStockDebounce = Timer(const Duration(milliseconds: 1200), () {
      _checkLowStock();
    });
  }

  Future<void> _loadDashboardData({bool silent = false}) async {
    if (!mounted) return;
    if (!silent && _orders.isEmpty) {
      setState(() => _isLoading = true);
    }
    final orders = await _adminService.fetchOrdersQueue(
      isApiConnected: _isApiConnected,
    );
    final stats = await _adminService.fetchDailySalesAnalytics(
      isApiConnected: _isApiConnected,
    );
    if (!mounted) return;

    final bool wasSeeded = _orderIdsSeeded;
    final List<AdminOrder> newOrders = <AdminOrder>[];
    if (wasSeeded) {
      for (final AdminOrder order in orders) {
        if (!_knownOrderIds.contains(order.id)) newOrders.add(order);
      }
    }
    _knownOrderIds
      ..clear()
      ..addAll(orders.map((o) => o.id));
    _orderIdsSeeded = true;

    // Notify bago ang setState para kasama agad sa rebuild ang unread badge.
    if (wasSeeded && newOrders.isNotEmpty) {
      _notifyNewOrders(newOrders);
    }
    // Unang load: i-seed ang dedupe keys ng lumang bill requests para hindi
    // mag-replay nang isa-isa. Bagong request lang ang mag-a-alert pagkatapos.
    _notifyPendingBillRequests(orders, seedOnly: !wasSeeded);

    setState(() {
      _orders = orders;
      _salesStats = stats;
      _isLoading = false;
    });

    if (!wasSeeded) {
      // Unang load: i-seed ang low-stock baseline nang walang alert spam.
      await _checkLowStock(seedOnly: !_lowStockSeeded);
    }
  }

  void _notifyNewOrders(Iterable<AdminOrder> orders) {
    for (final AdminOrder order in orders) {
      AudioNotificationService.showAdminNewOrderBanner(
        tableNumber: order.tableNumber,
        orderId: order.id,
        parentOrderId: order.parentOrderId,
        isAdditional: order.isAdditional,
        itemsSummary: order.itemsDescription,
        totalAmount: order.totalAmount.toStringAsFixed(2),
      );
    }
  }

  Future<void> _checkLowStock({bool seedOnly = false}) async {
    if (_lowStockCheckInFlight) return;
    _lowStockCheckInFlight = true;
    try {
      final List<Map<String, dynamic>> inventory = await _adminService
          .fetchMenuInventory();
      if (!mounted || inventory.isEmpty) return;

      final Set<String> currentLowIds = <String>{};
      final List<Map<String, dynamic>> newlyLow = <Map<String, dynamic>>[];

      for (final Map<String, dynamic> item in inventory) {
        final int stock =
            int.tryParse(
              (item['stock_quantity'] ?? item['stock'] ?? 0).toString(),
            ) ??
            0;
        final int threshold =
            int.tryParse((item['low_stock_threshold'] ?? 10).toString()) ?? 10;
        if (stock > threshold) continue;

        final String key =
            (item['id'] ?? item['item_name'] ?? item['name'] ?? '').toString();
        if (key.isEmpty) continue;
        currentLowIds.add(key);

        final bool isNewLow =
            _lowStockSeeded && !_lowStockItemIds.contains(key);
        if (!seedOnly && isNewLow) {
          newlyLow.add(<String, dynamic>{
            'id': item['id'],
            'name': item['name'] ?? item['item_name'] ?? 'Item',
            'stock': stock,
          });
        }
      }

      _lowStockItemIds
        ..clear()
        ..addAll(currentLowIds);
      _lowStockSeeded = true;

      if (!seedOnly && newlyLow.isNotEmpty) {
        AudioNotificationService.showAdminLowStockBanner(items: newlyLow);
        if (mounted) setState(() {});
      }
    } finally {
      _lowStockCheckInFlight = false;
    }
  }

  /// I-scan ang buong order queue at mag-notify para sa bawat session na may
  /// pending bill request. Dedupe ang service, kaya safe itong tawagin sa
  /// bawat refresh/back/tab switch.
  void _notifyPendingBillRequests(
    Iterable<AdminOrder> orders, {
    bool seedOnly = false,
  }) {
    final Set<int> countedTickets = <int>{};
    int pendingCount = 0;

    for (final AdminOrder order in orders) {
      if (!order.hasPendingBillRequest) continue;

      final int ticketRoot = order.parentOrderId != null &&
              order.parentOrderId! > 0
          ? order.parentOrderId!
          : order.id;
      if (countedTickets.add(ticketRoot)) pendingCount++;

      if (seedOnly) {
        // Record lang ang dedupe key — walang banner, walang tunog.
        AudioNotificationService.seedAdminBillRequested(
          tableNumber: order.tableNumber,
          sessionId: order.sessionId,
          orderId: order.id,
          parentOrderId: order.parentOrderId,
          billRequestedAt: order.billRequestedAt,
        );
      } else {
        AudioNotificationService.showAdminBillRequestedBanner(
          tableNumber: order.tableNumber,
          sessionId: order.sessionId,
          orderId: order.id,
          parentOrderId: order.parentOrderId,
          billRequestedAt: order.billRequestedAt,
          grandTotal: order.totalAmount.toStringAsFixed(2),
        );
      }
    }

    if (seedOnly && pendingCount > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$pendingCount bill request(s) pending.'),
          backgroundColor: AdminTheme.warningFg,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  /// Socket `bill_requested` handler: mag-notify agad mula sa payload bago
  /// i-refresh ang queue, para hindi maantala ang admin alert.
  void _handleBillRequestedEvent(dynamic payload) {
    if (payload is Map) {
      final Map<String, dynamic> data = Map<String, dynamic>.from(payload);
      final int? rawTableNumber = int.tryParse(
        (data['table_number'] ?? '').toString(),
      );
      final int? rawTableId = int.tryParse((data['table_id'] ?? '').toString());
      final int? sessionId = int.tryParse(
        (data['session_id'] ?? '').toString(),
      );

      // Fallback sa table number mula sa kasalukuyang queue kung table_id lang
      // ang nasa socket payload.
      int? tableNumber = rawTableNumber;
      if (tableNumber == null) {
        for (final AdminOrder order in _orders) {
          final bool matchesSession =
              sessionId != null && order.sessionId == sessionId;
          final bool matchesTable =
              rawTableId != null && order.tableNumber == rawTableId;
          if (matchesSession || matchesTable) {
            tableNumber = order.tableNumber;
            break;
          }
        }
        tableNumber ??= rawTableId;
      }

      final dynamic rawRequestedAt =
          data['bill_requested_at'] ?? data['requested_at'];
      final DateTime? requestedAt = rawRequestedAt != null
          ? DateTime.tryParse(rawRequestedAt.toString())
          : null;
      final dynamic rawTotal =
          data['grand_total'] ?? data['total_amount'] ?? data['amount'];
      final double? total = rawTotal != null
          ? double.tryParse(rawTotal.toString())
          : null;

      if (tableNumber != null && tableNumber > 0) {
        final int? orderId = int.tryParse(
          (data['order_id'] ?? data['ticket_order_id'] ?? '').toString(),
        );
        int? parentOrderId = int.tryParse(
          (data['parent_order_id'] ?? '').toString(),
        );
        // Kung wala sa payload, hanapin sa kasalukuyang queue para ma-group
        // ang alert sa root ticket.
        if (parentOrderId == null && orderId != null) {
          for (final AdminOrder order in _orders) {
            if (order.id == orderId) {
              parentOrderId = order.parentOrderId;
              break;
            }
          }
        }
        AudioNotificationService.showAdminBillRequestedBanner(
          tableNumber: tableNumber,
          sessionId: sessionId,
          orderId: orderId,
          parentOrderId: parentOrderId,
          billRequestedAt: requestedAt,
          grandTotal: total?.toStringAsFixed(2),
        );
      }
    }

    _loadDashboardData(silent: true);
  }

  Future<void> _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter employee ID and password.'),
          backgroundColor: AppTheme.errorRust,
        ),
      );
      return;
    }

    setState(() => _isLoggingIn = true);

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/auth/login'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"username": username, "password": password}),
      );

      if (!mounted) return;
      setState(() => _isLoggingIn = false);

      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        final token =
            resData['token'] ??
            resData['data']?['token'] ??
            resData['access_token'];
        UserSession.authToken = token;
        AdminService.staffAuthToken = token;
        AdminService.staffName = username;

        setState(() {
          _isLoggedIn = true;
        });
        _loadDashboardData();
        _initSocketSync();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login Successful! Welcome to Admin Portal.'),
            backgroundColor: AdminTheme.textDark,
          ),
        );
        return;
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid credentials. Please try again.'),
              backgroundColor: AppTheme.errorRust,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoggingIn = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login connection error: $e'),
            backgroundColor: AppTheme.errorRust,
          ),
        );
      }
    }
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminTheme.surfaceIvory,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Confirm Logout',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AdminTheme.textDark,
          ),
        ),
        content: const Text(
          'Are you sure you want to log out from the admin portal?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AdminTheme.mutedGray),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _socketService.disconnect();
              UserSession.clearSession();
              AdminService.staffAuthToken = null;
              _orderIdsSeeded = false;
              _lowStockSeeded = false;
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminDashboardScreen(),
                ),
                (route) => false,
              );
            },
            child: const Text(
              'Log Out',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleReopenBill(int orderId) async {
    final bool ok = await _adminService.reopenOrderBill(
      orderId: orderId,
      isApiConnected: _isApiConnected,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Ordering reopened for order #$orderId.'
              : 'Could not reopen ordering. Please try again.',
        ),
        backgroundColor: ok ? const Color(0xFF203F35) : const Color(0xFF8E5136),
      ),
    );
    if (ok) _loadDashboardData(silent: true);
  }

  void _handleActionTriggered(
    int orderId,
    String targetStatus, {
    String? paymentMethod,
    String? declineReason,
  }) {
    final String timeNow = '${TimeOfDay.now().format(context)} • Today';
    setState(() {
      final index = _orders.indexWhere((o) => o.id == orderId);
      if (index != -1) {
        _orders[index].status = targetStatus;
        if (paymentMethod != null) {
          _orders[index].paymentMethod = paymentMethod;
        }
        _orders[index].updatedAt = timeNow;
      }
    });

    final currentOrder = _orders.firstWhere(
      (o) => o.id == orderId,
      orElse: () => AdminOrder(
        id: orderId,
        tableNumber: 1,
        itemsDescription: '',
        totalAmount: 0,
        status: targetStatus,
        paymentMethod: 'UNPAID',
        updatedAt: '',
      ),
    );
    if (targetStatus == 'PAID') {
      _adminService.processPayment(
        orderId: orderId,
        paymentMethod: paymentMethod ?? currentOrder.paymentMethod,
        amountPaid: currentOrder.totalAmount,
        isApiConnected: _isApiConnected,
      );
    } else {
      _adminService.updateOrderStatus(
        orderId: orderId,
        status: targetStatus,
        paymentMethod: currentOrder.paymentMethod,
        declineReason: declineReason,
        isApiConnected: _isApiConnected,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoggedIn) {
      return _buildEmployeeLoginScreen();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= 900;

        return Scaffold(
          backgroundColor: AdminTheme.background,
          appBar: AppBar(
            backgroundColor: AdminTheme.deepGreen,
            elevation: 0,
            title: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'lib/logo/BalaiSilayanLogo_512.png',
                    width: 30,
                    height: 30,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'BALAI SILAYAN · ADMIN PORTAL',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Libre Baskerville',
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Text(
                        _currentTabIndex == 0
                            ? 'ORDER QUEUE'
                            : _currentTabIndex == 1
                            ? 'SALES ANALYTICS'
                            : 'STOCK MANAGEMENT',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.8,
                          color: AdminTheme.goldAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              Builder(
                builder: (context) {
                  final int unread =
                      AudioNotificationService.unseenHistoryCount;
                  return IconButton(
                    tooltip: 'Notification history',
                    onPressed: () {
                      AudioNotificationService.showNotificationHistory(context);
                      // markHistorySeen() ay kasama sa showNotificationHistory.
                      setState(() {});
                    },
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(
                          Icons.notifications_outlined,
                          color: Colors.white,
                        ),
                        if (unread > 0)
                          Positioned(
                            right: -6,
                            top: -5,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AdminTheme.deepGreen,
                                  width: 1.5,
                                ),
                              ),
                              constraints: const BoxConstraints(minWidth: 17),
                              child: Text(
                                unread > 99 ? '99+' : '$unread',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.circle,
                  size: 10,
                  color: _isApiConnected
                      ? AdminTheme.successFg
                      : AdminTheme.danger,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                tooltip: 'Logout',
                onPressed: _handleLogout,
              ),
              const SizedBox(width: 12),
            ],
          ),
          body: Row(
            children: [
              if (isDesktop) _buildSidebarNav(),
              Expanded(
                child: _isLoading
                    ? _buildLoadingSkeleton()
                    : IndexedStack(
                        index: _currentTabIndex,
                        children: [
                          OrderQueueScreen(
                            orders: _orders,
                            onActionTriggered: _handleActionTriggered,
                            onReopenBill: _handleReopenBill,
                            onRefresh: _loadDashboardData,
                            stats: _salesStats,
                          ),
                          SalesAnalyticsScreen(
                            stats: _salesStats,
                            orders: _orders,
                            onRefresh: _loadDashboardData,
                          ),
                          StockManagementScreen(
                            key: _stockScreenKey,
                            onRefresh: _loadDashboardData,
                          ),
                        ],
                      ),
              ),
            ],
          ),
          bottomNavigationBar: isDesktop
              ? null
              : NavigationBar(
                  backgroundColor: AdminTheme.deepGreen,
                  indicatorColor: AdminTheme.goldAccent,
                  selectedIndex: _currentTabIndex,
                  onDestinationSelected: (idx) =>
                      setState(() => _currentTabIndex = idx),
                  destinations: [
                    NavigationDestination(
                      icon: Icon(Icons.receipt_long_outlined),
                      label: 'Order Queue',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.analytics_outlined),
                      label: 'Sales Analytics',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.inventory_2_outlined),
                      label: 'Stock Mgmt',
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildLoadingSkeleton() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: List.generate(3, (index) => _buildSkeletonCard()),
    );
  }

  Widget _buildSkeletonCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminTheme.surfaceIvory,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Skeleton(width: 140, height: 14, radius: 7)),
              SizedBox(
                width: 60,
                child: Skeleton(width: 70, height: 24, radius: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Skeleton(width: 180, height: 18, radius: 9)),
              SizedBox(
                width: 60,
                child: Skeleton(width: 60, height: 18, radius: 9),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Skeleton(width: double.infinity, height: 12, radius: 6),
        ],
      ),
    );
  }

  Widget _buildSidebarNav() {
    final navItems = [
      {'index': 0, 'icon': Icons.receipt_long_outlined, 'label': 'Order queue'},
      {
        'index': 1,
        'icon': Icons.analytics_outlined,
        'label': 'Sales analytics',
      },
      {
        'index': 2,
        'icon': Icons.inventory_2_outlined,
        'label': 'Stock management',
      },
    ];

    return Container(
      width: 264,
      color: AdminTheme.deepGreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'lib/logo/BalaiSilayanLogo_512.png',
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Balai Silayan',
                        style: TextStyle(
                          fontFamily: 'Libre Baskerville',
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'ADMIN PORTAL',
                        style: TextStyle(
                          fontSize: 9.5,
                          letterSpacing: 1.6,
                          fontWeight: FontWeight.w800,
                          color: AdminTheme.goldAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF244B3E)),
          const SizedBox(height: 10),
          ...navItems.map((item) {
            final idx = item['index'] as int;
            final isSelected = _currentTabIndex == idx;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: InkWell(
                onTap: () => setState(() => _currentTabIndex = idx),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AdminTheme.deepGreenSelected
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AdminTokens.gold.withValues(alpha: 0.35)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        item['icon'] as IconData,
                        color: isSelected
                            ? AdminTheme.goldAccent
                            : Colors.white70,
                        size: 18,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        item['label'] as String,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: isSelected ? Colors.white : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 17,
                  backgroundColor: AdminTheme.deepGreenSelected,
                  child: Text(
                    'A',
                    style: TextStyle(
                      color: AdminTheme.goldAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Admin Staff',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        'Restaurant Management',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _handleLogout,
                  icon: const Icon(
                    Icons.logout_rounded,
                    size: 18,
                    color: Colors.white60,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeLoginScreen() {
    return Scaffold(
      backgroundColor: AdminTheme.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AdminTheme.surfaceIvory,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AdminTheme.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: AdminTheme.textDark,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AdminTheme.border),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset(
                        'lib/logo/BalaiSilayanLogo_512.png',
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.restaurant,
                          color: AdminTheme.goldAccent,
                          size: 36,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Balai Silayan',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Libre Baskerville',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AdminTheme.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Employee POS & Admin Portal',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AdminTheme.mutedDark),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'Employee ID / Username',
                    prefixIcon: const Icon(
                      Icons.person_outline,
                      color: AdminTheme.textDark,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Access Passcode',
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                      color: AdminTheme.textDark,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminTheme.textDark,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isLoggingIn ? null : _handleLogin,
                    child: _isLoggingIn
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Access Dashboard',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
