import 'package:flutter/material.dart';
import 'screens/admin/models/admin_order_model.dart';
import 'screens/admin/services/admin_service.dart';
import 'screens/admin/screens/order_queue_screen.dart';
import 'screens/admin/screens/sales_analytics_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AdminService _adminService = AdminService();

  bool _isLoggedIn = false;
  bool _isApiConnected = false;
  int _currentTabIndex = 0;
  bool _isLoading = false;

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
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
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

  void _handleActionTriggered(int orderId, String targetStatus, {String? paymentMethod}) {
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
    _adminService.updateOrderStatus(
      orderId: orderId,
      status: targetStatus,
      paymentMethod: currentOrder.paymentMethod,
      isApiConnected: _isApiConnected,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoggedIn) {
      return _buildEmployeeLoginScreen();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F1EA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B3B2B),
        title: const Text(
          'Balai Silayan • Admin Dashboard',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          Row(
            children: [
              Text(
                _isApiConnected ? 'LIVE API' : 'MOCK MODE',
                style: TextStyle(
                  color: _isApiConnected ? const Color(0xFF4ADE80) : const Color(0xFFFBBF24),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
              Switch(
                value: _isApiConnected,
                activeThumbColor: const Color(0xFF4ADE80),
                onChanged: (val) {
                  setState(() => _isApiConnected = val);
                  _loadDashboardData();
                },
              ),
            ],
          ),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              backgroundColor: const Color(0xFFA47C3D),
              child: const Text('BS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1B3B2B)))
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
                  onRefresh: _loadDashboardData,
                ),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        onTap: (idx) => setState(() => _currentTabIndex = idx),
        backgroundColor: const Color(0xFF1B3B2B),
        selectedItemColor: const Color(0xFFA47C3D),
        unselectedItemColor: Colors.white60,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Live Queue',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics_outlined),
            label: 'Daily Sales',
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeLoginScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F1EA),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
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
                      color: const Color(0xFF1B3B2B),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Center(
                      child: Icon(Icons.restaurant, color: Color(0xFFA47C3D), size: 36),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Balai Silayan',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Libre Baskerville', fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1B3B2B)),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Employee POS & Admin Portal',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Color(0xFF788078)),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'Employee ID / Username',
                    prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF1B3B2B)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Access Passcode',
                    prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF1B3B2B)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B3B2B),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      setState(() => _isLoggedIn = true);
                    },
                    child: const Text(
                      'Access Dashboard',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1B3B2B),
                      side: const BorderSide(color: Color(0xFFA47C3D), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.flash_on, color: Color(0xFFA47C3D)),
                    label: const Text('⚡ Quick Admin Demo Login', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      setState(() => _isLoggedIn = true);
                    },
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
