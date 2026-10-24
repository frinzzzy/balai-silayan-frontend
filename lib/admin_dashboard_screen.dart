import 'package:flutter/material.dart';
import 'screens/admin/models/admin_order_model.dart';
import 'screens/admin/services/admin_service.dart';
import 'screens/admin/screens/order_queue_screen.dart';
import 'screens/admin/screens/sales_analytics_screen.dart';
import 'services/socket_service.dart';
import 'models/user_session.dart';
import 'theme/app_theme.dart';
import 'qr_scanner_screen.dart';
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

  bool _isLoggedIn = false;
  final bool _isApiConnected = true; // Locked to production API
  int _currentTabIndex = 0;
  bool _isLoading = false;
  bool _isLoggingIn = false;

  final TextEditingController _usernameController = TextEditingController(text: 'admin');
  final TextEditingController _passwordController = TextEditingController(text: 'admin123');

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
    _socketService.disconnect();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _initSocketSync() {
    _socketService.connect(
      onOrderUpdated: (_) => _loadDashboardData(silent: true),
      onStatusUpdated: (_) => _loadDashboardData(silent: true),
      onSessionClosed: (_) => _loadDashboardData(silent: true),
    );
  }

  Future<void> _loadDashboardData({bool silent = false}) async {
    if (!mounted) return;
    if (!silent && _orders.isEmpty) {
      setState(() => _isLoading = true);
    }
    final orders = await _adminService.fetchOrdersQueue(isApiConnected: _isApiConnected);
    final stats = await _adminService.fetchDailySalesAnalytics(isApiConnected: _isApiConnected);
    if (mounted) {
      setState(() {
        _orders = orders;
        _salesStats = stats;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter employee ID and password.'), backgroundColor: AppTheme.errorRust),
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
        final token = resData['token'] ?? resData['data']?['token'] ?? resData['access_token'];
        UserSession.authToken = token;
        AdminService.staffAuthToken = token;

        setState(() {
          _isLoggedIn = true;
        });
        _loadDashboardData();
        _initSocketSync();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login Successful! Welcome to Admin Portal.'), backgroundColor: Color(0xFF203F35)),
        );
        return;
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid credentials. Please try again.'), backgroundColor: AppTheme.errorRust),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoggingIn = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login connection error: $e'), backgroundColor: AppTheme.errorRust),
        );
      }
    }
  }

  void _handleLogout() {
    _socketService.disconnect();
    UserSession.clearSession();
    AdminService.staffAuthToken = null;
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
      (route) => false,
    );
  }

  void _handleActionTriggered(int orderId, String targetStatus, {String? paymentMethod, String? declineReason}) {
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

    final currentOrder = _orders.firstWhere((o) => o.id == orderId, orElse: () => AdminOrder(id: orderId, tableNumber: 1, itemsDescription: '', totalAmount: 0, status: targetStatus, paymentMethod: 'UNPAID', updatedAt: ''));
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
          backgroundColor: const Color(0xFFF8F4EC),
          appBar: AppBar(
            backgroundColor: const Color(0xFF19382F),
            elevation: 0,
            title: const Row(
              children: [
                Icon(Icons.home_outlined, color: Color(0xFFC3AA7F), size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
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
                ),
              ],
            ),
            actions: [
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
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF203F35)))
                    : IndexedStack(
                        index: _currentTabIndex,
                        children: [
                          OrderQueueScreen(
                            orders: _orders,
                            onActionTriggered: _handleActionTriggered,
                            onRefresh: _loadDashboardData,
                          ),
                          SalesAnalyticsScreen(
                            stats: _salesStats,
                            orders: _orders,
                            onRefresh: _loadDashboardData,
                          ),
                        ],
                      ),
              ),
            ],
          ),
          bottomNavigationBar: isDesktop
              ? null
              : BottomNavigationBar(
                  currentIndex: _currentTabIndex,
                  onTap: (idx) => setState(() => _currentTabIndex = idx),
                  backgroundColor: const Color(0xFF19382F),
                  selectedItemColor: const Color(0xFFC3AA7F),
                  unselectedItemColor: Colors.white60,
                  items: const [
                    BottomNavigationBarItem(
                      icon: Icon(Icons.receipt_long_outlined),
                      label: 'Order Queue',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.analytics_outlined),
                      label: 'Sales Analytics',
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildSidebarNav() {
    final navItems = [
      {'index': 0, 'icon': Icons.receipt_long_outlined, 'label': 'Order queue'},
      {'index': 1, 'icon': Icons.analytics_outlined, 'label': 'Sales analytics'},
    ];

    return Container(
      width: 230,
      color: const Color(0xFF19382F),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'MANAGEMENT',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white.withValues(alpha: 0.5), letterSpacing: 1.2),
            ),
          ),
          const SizedBox(height: 12),
          ...navItems.map((item) {
            final idx = item['index'] as int;
            final isSelected = _currentTabIndex == idx;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: InkWell(
                onTap: () => setState(() => _currentTabIndex = idx),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF2C4D40) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        item['icon'] as IconData,
                        color: isSelected ? const Color(0xFFC3AA7F) : Colors.white70,
                        size: 18,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        item['label'] as String,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Admin Staff', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                Text('Restaurant Management', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeLoginScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4EC),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFDFA),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE5DFD3)),
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
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFF203F35),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Center(
                      child: Icon(Icons.restaurant, color: Color(0xFFC3AA7F), size: 36),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Balai Silayan',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Libre Baskerville', fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF203F35)),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Employee POS & Admin Portal',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Color(0xFF687368)),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'Employee ID / Username',
                    prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF203F35)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Access Passcode',
                    prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF203F35)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF203F35),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isLoggingIn ? null : _handleLogin,
                    child: _isLoggingIn
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Access Dashboard',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF687368),
                  ),
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Back to QR Login'),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const QrScannerScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
