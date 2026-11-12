import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'menu_screen.dart';
import 'assistance_screen.dart';
import 'order_status_screen.dart';
import 'user_session.dart';
import 'services/global_socket_listener.dart';
import 'config/api_config.dart';

class BillRequestedScreen extends StatefulWidget {
  final int? tableId;
  final bool isTakeout;
  final double totalAmount;
  final double foodDrinksTotal;
  final double addOnsTotal;
  final String? billRequestedAt;

  const BillRequestedScreen({
    super.key,
    this.tableId,
    this.isTakeout = false,
    this.totalAmount = 0.0,
    this.foodDrinksTotal = 0.0,
    this.addOnsTotal = 0.0,
    this.billRequestedAt,
  });

  @override
  State<BillRequestedScreen> createState() => _BillRequestedScreenState();
}

class _BillRequestedScreenState extends State<BillRequestedScreen> {
  String? _billRequestedAt;
  bool _sessionSettled = false;
  bool _isLoadingBillState = true;

  String get _baseUrl => ApiConfig.baseUrl;

  @override
  void initState() {
    super.initState();
    _billRequestedAt = widget.billRequestedAt;
    // Read-only refresh lang ito; hindi na nagre-request tuwing bubuksan ang
    // screen para hindi na maulit ang bill request sa back/refresh.
    _loadBillState();
    // Phase D: gumagamit na nating ang GlobalSocketListener — hindi local na
    // socket ang bawat screen.
    GlobalSocketListener.instance.setOnBillRequested((data) => _handleBillRequestedEvent(data));
    GlobalSocketListener.instance.setOnSessionClosed((data) => _handleSessionSettled(data));
  }

  Future<void> _loadBillState() async {
    try {
      final int tableNum = widget.tableId ?? UserSession.activeTableId ?? 1;
      final Uri requestUri = Uri.parse('$_baseUrl/api/v1/tables/$tableNum/bill');

      final response = await http
          .get(requestUri, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        final dynamic rawData = decoded is Map ? (decoded['data'] ?? decoded) : null;
        if (rawData is Map && mounted) {
          final Map<String, dynamic> data = Map<String, dynamic>.from(rawData);
          final dynamic requestedAt =
              data['bill_requested_at'] ?? data['requested_at'];
          final String sessionStatus =
              (data['session_status'] ?? 'ACTIVE').toString().toUpperCase();
          final List<dynamic> activeOrders =
              data['orders'] is List ? data['orders'] as List : const [];

          // Per-ticket mode: kapag may kahit isang ticket na nag-request ng bill,
          // hindi na dapat i-clear ang screen state kahit NULL ang legacy
          // session-level marker.
          String? requestedStamp = requestedAt?.toString();
          if (requestedStamp == null) {
            for (final dynamic raw in activeOrders) {
              if (raw is Map && raw['bill_requested_at'] != null) {
                requestedStamp = raw['bill_requested_at'].toString();
                break;
              }
            }
          }

          setState(() {
            _billRequestedAt = requestedStamp ?? _billRequestedAt;
            _sessionSettled = (sessionStatus == 'CLOSED' ||
                    sessionStatus == 'COMPLETED' ||
                    sessionStatus == 'SETTLED') &&
                activeOrders.isEmpty;
            _isLoadingBillState = false;
          });
          return;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoadingBillState = false);
    }
  }

  bool _isEventForThisTable(dynamic data) {
    if (data is! Map) return true;
    final int? currentSessionId = UserSession.activeSessionId ??
        int.tryParse(UserSession.sessionId ?? '');
    final int? eventSessionId = int.tryParse(
      (data['session_id'] ?? '').toString(),
    );
    if (currentSessionId != null &&
        eventSessionId != null &&
        currentSessionId != eventSessionId) {
      return false;
    }

    final int? currentTableId = widget.tableId ??
        UserSession.activeTableId ??
        UserSession.activeTableNumber;
    final int? eventTableId = int.tryParse(
      (data['table_id'] ?? data['table_number'] ?? '').toString(),
    );
    if (currentTableId != null &&
        eventTableId != null &&
        currentTableId != eventTableId) {
      return false;
    }
    return true;
  }

  void _handleBillRequestedEvent(dynamic data) {
    if (!mounted || !_isEventForThisTable(data)) return;
    setState(() {
      _billRequestedAt = data is Map
          ? (data['bill_requested_at'] ?? data['requested_at'] ?? '')
              .toString()
          : null;
      _sessionSettled = false;
      _isLoadingBillState = false;
    });
  }

  void _handleSessionSettled(dynamic data) {
    if (!mounted || !_isEventForThisTable(data)) return;
    setState(() {
      _billRequestedAt = null;
      _sessionSettled = true;
    });
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFFDFA),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Payment Confirmed', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF203F35))),
        content: const Text('Na-confirm na ng staff ang iyong bayad. Maraming salamat sa paghain sa Balai Silayan!'),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF203F35)),
            onPressed: () {
              Navigator.pop(ctx);
              UserSession.clearSession();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const MenuScreen(), settings: const RouteSettings(name: 'menu')),
                    (route) => false,
              );
            },
            child: const Text('Back to Menu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    GlobalSocketListener.instance.setOnBillRequested(null);
    GlobalSocketListener.instance.setOnSessionClosed(GlobalSocketListener.instance.defaultOrderSessionClosed);
    super.dispose();
  }

  void _navigateToMenu() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const MenuScreen(), settings: const RouteSettings(name: 'menu')),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final int tableNum = widget.tableId ?? UserSession.activeTableId ?? 1;
    final String tableString = widget.isTakeout ? 'Takeout' : 'Table ${tableNum.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F4EC),
      body: SafeArea(
        child: Column(
          children: [
            _buildRestaurantHeader(),
            _buildTableContextStrip(tableString),
            Expanded(
              child: _isLoadingBillState && _billRequestedAt == null
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF203F35),
                      ),
                    )
                  : _sessionSettled
                      ? _buildSettledView()
                      : SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24.0,
                            vertical: 16.0,
                          ),
                          child: Column(
                            children: [
                              const SizedBox(height: 12),
                              _buildConfirmationSeal(),
                              const SizedBox(height: 20),
                              _buildIntroductionHeader(),
                              const SizedBox(height: 12),
                              _buildStatusBadge(),
                              const SizedBox(height: 20),
                              _buildBillSummaryCard(tableString),
                              const SizedBox(height: 16),
                              _buildSecurityContextNote(),
                              const SizedBox(height: 28),
                              _buildSecondaryActionButton(),
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

  Widget _buildSettledView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF0E9),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE5DFD3)),
              ),
              child: const Center(
                child: Icon(
                  Icons.verified,
                  size: 38,
                  color: Color(0xFF203F35),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'SESSION SETTLED',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFFA47C3D),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Salamat sa paghain!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF203F35),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Tapos na ang bill request para sa session na ito. Wala nang kailangang i-request muli.',
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
                child: const Text(
                  'Back to Menu',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
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
                '$tableString • verified',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Color(0xFF203F35)),
              ),
            ],
          ),
          Text(
            widget.isTakeout ? 'Takeout' : 'Dine-in',
            style: const TextStyle(fontSize: 10, color: Color(0xFF788078), fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationSeal() {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF0E9),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE5DFD3)),
      ),
      child: const Center(
        child: Icon(Icons.receipt_long, size: 32, color: Color(0xFF203F35)),
      ),
    );
  }

  Widget _buildIntroductionHeader() {
    return const Column(
      children: [
        Text(
          'BILL REQUESTED',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFFA47C3D),
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Bill is on the way.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF203F35),
            height: 1.2,
          ),
        ),
        SizedBox(height: 10),
        Text(
          'Salamat! Our staff has been notified to prepare your official receipt or collect payment.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Color(0xFF788078), height: 1.4),
        ),
      ],
    );
  }

  Widget _buildStatusBadge() {
    final bool isBillRequested = _billRequestedAt != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isBillRequested ? const Color(0xFFEAF0E9) : const Color(0xFFEEE7D9),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time, size: 13, color: isBillRequested ? const Color(0xFF203F35) : const Color(0xFFA47C3D)),
          const SizedBox(width: 6),
          Text(
            isBillRequested ? 'Bill Requested' : 'Awaiting staff arrival',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isBillRequested ? const Color(0xFF203F35) : const Color(0xFFA47C3D),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillSummaryCard(String tableString) {
    return Container(
      padding: const EdgeInsets.all(18),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Dining Table', style: TextStyle(fontSize: 12, color: Color(0xFF788078))),
              Text(tableString, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF203F35))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Food & drinks', style: TextStyle(fontSize: 12, color: Color(0xFF788078))),
              Text('₱${widget.foodDrinksTotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF203F35))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Selected add-ons', style: TextStyle(fontSize: 12, color: Color(0xFF788078))),
              Text('₱${widget.addOnsTotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF203F35))),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14.0),
            child: Divider(height: 1, color: Color(0xFFE5DFD3)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Billed Amount', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF24382F))),
              Text(
                '₱${widget.totalAmount.toStringAsFixed(0)}',
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

  Widget _buildSecurityContextNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF0E9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: Color(0xFF53766C), size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your session remains active until payment is confirmed by staff on their workstation.',
              style: TextStyle(fontSize: 12, color: Color(0xFF53766C), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryActionButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: const Color(0xFFFFFDFA),
          side: const BorderSide(color: Color(0xFFE5DFD3)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: _navigateToMenu,
        child: const Text('Back to menu', style: TextStyle(color: Color(0xFF203F35), fontWeight: FontWeight.bold, fontSize: 14)),
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
          _buildNavItem(Icons.restaurant, 'Menu', onTap: () {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MenuScreen(), settings: const RouteSettings(name: 'menu')));
          }),
          _buildNavItem(Icons.track_changes, 'Live Status', onTap: () {
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
          }),
          _buildNavItem(Icons.account_balance_wallet, 'Pay', isActive: true, onTap: () {}),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, {bool isActive = false, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: isActive ? const Color(0xFF203F35) : const Color(0xFF788078)),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? const Color(0xFF203F35) : const Color(0xFF788078),
            ),
          ),
          if (isActive) ...[
            const SizedBox(height: 2),
            Container(width: 16, height: 2, decoration: BoxDecoration(color: const Color(0xFFA47C3D), borderRadius: BorderRadius.circular(2))),
          ]
        ],
      ),
    );
  }
}