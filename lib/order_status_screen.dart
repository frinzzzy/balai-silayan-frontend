import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'menu_screen.dart';
import 'assistance_screen.dart';
import 'orders_screen.dart';

class OrderStatusScreen extends StatefulWidget {
  final dynamic orderId;
  final bool isTakeout;
  final int? tableId;
  final double totalAmount;
  final bool isAdditionalOrder;

  const OrderStatusScreen({
    super.key,
    required this.orderId,
    required this.isTakeout,
    this.tableId = 7,
    this.totalAmount = 1255.0,
    this.isAdditionalOrder = false,
  });

  @override
  State<OrderStatusScreen> createState() => _OrderStatusScreenState();
}

class _OrderStatusScreenState extends State<OrderStatusScreen> {
  late io.Socket _repositorySocketGateway;
  String _statusBadgeLabel = "Pending review";
  int _stepperProgressIndex = 0;
  bool _showLiveTrackerView = false;

  @override
  void initState() {
    super.initState();
    _connectRepositorySocketStream();
  }

  String _formatOrderCode(dynamic orderId) {
    if (orderId == null) return '#BS-1042';
    final str = orderId.toString().trim();
    if (str.startsWith('#')) return str;

    final intVal = int.tryParse(str);
    if (intVal != null) {
      if (intVal > 9999) {
        final code = intVal.toRadixString(36).toUpperCase().padLeft(5, '0');
        return '#BS-$code';
      }
      return '#BS-${intVal.toString().padLeft(4, '0')}';
    }

    final cleanStr = str.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    return '#BS-${cleanStr.length > 5 ? cleanStr.substring(0, 5) : cleanStr.padLeft(5, '0')}';
  }

  void _connectRepositorySocketStream() {
    _repositorySocketGateway = io.io(
      'http://localhost:5000',
      io.OptionBuilder().setTransports(['websocket']).disableAutoConnect().build(),
    );
    _repositorySocketGateway.connect();

    _repositorySocketGateway.onConnect((_) {
      _repositorySocketGateway.emit('join_room', widget.orderId.toString());
    });

    void handleStatusUpdate(dynamic eventPayloadData) {
      if (eventPayloadData != null && mounted) {
        final Map<String, dynamic> data = eventPayloadData is Map<String, dynamic>
            ? eventPayloadData
            : Map<String, dynamic>.from(eventPayloadData as Map);

        final String targetOrderId = (data['order_id'] ?? data['id'] ?? '').toString();
        if (targetOrderId.isEmpty || targetOrderId == widget.orderId.toString()) {
          String serverStatus = (data['status'] ?? data['order_status'] ?? 'PENDING').toString().toUpperCase();

          setState(() {
            _showLiveTrackerView = true; // Auto-switch to live tracker when kitchen updates status!
            if (serverStatus == 'PREPARING') {
              _statusBadgeLabel = "Preparing in Kitchen";
              _stepperProgressIndex = 1;
            } else if (serverStatus == 'READY' || serverStatus == 'SERVED' || serverStatus == 'COMPLETED') {
              _statusBadgeLabel = "Ready & Served";
              _stepperProgressIndex = 2;
            } else if (serverStatus == 'DECLINED' || serverStatus == 'CANCELLED') {
              _statusBadgeLabel = "Cancelled";
              _stepperProgressIndex = 0;
            } else {
              _statusBadgeLabel = "Pending review";
              _stepperProgressIndex = 0;
            }
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Order ${widget.orderId} status updated to $_statusBadgeLabel!'),
              backgroundColor: const Color(0xFF203F35),
            ),
          );
        }
      }
    }

    _repositorySocketGateway.on('order_status_updated', handleStatusUpdate);
    _repositorySocketGateway.on('orderStatusUpdated', handleStatusUpdate);
  }

  @override
  void dispose() {
    _repositorySocketGateway.disconnect();
    _repositorySocketGateway.dispose();
    super.dispose();
  }

  void _navigateToMenu() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const MenuScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final int tableNum = widget.tableId ?? 7;
    final String tableString = widget.isTakeout ? 'Takeout' : 'Table ${tableNum.toString().padLeft(2, '0')}';
    final String formattedOrderCode = _formatOrderCode(widget.orderId);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F4EC),
      body: SafeArea(
        child: Column(
          children: [
            _buildRestaurantHeader(),
            _buildTableContextStrip(tableString),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: _showLiveTrackerView
                    ? _buildLiveStatusTrackerView(formattedOrderCode, tableString)
                    : _buildConfirmationView(formattedOrderCode, tableString),
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
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.point_of_sale_outlined, color: Color(0xFF203F35), size: 22),
                tooltip: 'Cashier Station',
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const OrdersScreen(cartItems: []))),
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
    final now = DateTime.now();
    final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    final timeString = '$hour:$minute $period • Today';

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
                const Icon(Icons.access_time, size: 13, color: Color(0xFFA47C3D)),
                const SizedBox(width: 6),
                Text(
                  _statusBadgeLabel,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFA47C3D)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.isAdditionalOrder ? 'ADDITIONAL ORDER' : 'NEW ORDER',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFA47C3D), letterSpacing: 1.1),
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
              const Text('Table', style: TextStyle(fontSize: 12, color: Color(0xFF788078))),
              Text(tableString, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF203F35))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Submitted', style: TextStyle(fontSize: 12, color: Color(0xFF788078))),
              Text(timeString, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF203F35))),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14.0),
            child: Divider(height: 1, color: Color(0xFFE5DFD3)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Order total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF24382F))),
              Text(
                '₱${widget.totalAmount.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF203F35)),
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
              style: TextStyle(fontSize: 12, color: Color(0xFF53766C), height: 1.4),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () {
              setState(() => _showLiveTrackerView = true);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('View live status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _navigateToMenu,
            child: const Text('Back to menu', style: TextStyle(color: Color(0xFF203F35), fontWeight: FontWeight.bold, fontSize: 14)),
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

    if (_stepperProgressIndex == 1) {
      stageTitle = 'Chefs are cooking your meal.';
      stageCopy = 'Your order is being sizzlingly prepared in our heritage kitchen.';
      badgeIcon = Icons.soup_kitchen_outlined;
      badgeBg = const Color(0xFFEAF0E9);
      badgeFg = const Color(0xFF203F35);
    } else if (_stepperProgressIndex >= 2) {
      stageTitle = 'Your food is served!';
      stageCopy = 'Enjoy your meal at $tableString. Need anything else? Call a waiter anytime.';
      badgeIcon = Icons.restaurant_outlined;
      badgeBg = const Color(0xFFEAF0E9);
      badgeFg = const Color(0xFF203F35);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status Badge Header
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
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: badgeFg),
                  ),
                ],
              ),
            ),
            const Text(
              'Updated 1m ago',
              style: TextStyle(fontSize: 10, color: Color(0xFF788078)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Title & Copy
        const Text(
          'LIVE STATUS',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFA47C3D), letterSpacing: 1.2),
        ),
        const SizedBox(height: 4),
        Text(
          stageTitle,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF203F35), height: 1.2),
        ),
        const SizedBox(height: 8),
        Text(
          stageCopy,
          style: const TextStyle(fontSize: 14, color: Color(0xFF788078), height: 1.4),
        ),
        const SizedBox(height: 20),
        // Order Summary Pill
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
              Text('Order Number: $orderCode', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF203F35))),
              Text('Total: ₱${widget.totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF203F35))),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Stepper Progress Line
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
              const Text('Order Progress', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF24382F))),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: _navigateToMenu,
            child: const Text('Back to menu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
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
        'title': 'Ready & Served',
        'subtitle': widget.isTakeout
            ? 'Your order is ready for pickup at the counter.'
            : 'Dispatched cleanly to your chosen table position.',
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
                    color: isActive ? const Color(0xFF203F35) : const Color(0xFFF8F4EC),
                    border: Border.all(color: isActive ? const Color(0xFF203F35) : const Color(0xFFE5DFD3)),
                  ),
                  child: Center(
                    child: isActive
                        ? (isCurrentStage
                        ? Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFD7BC86), shape: BoxShape.circle))
                        : const Icon(Icons.check, size: 14, color: Colors.white))
                        : Container(width: 5, height: 5, decoration: const BoxDecoration(color: Color(0xFFE5DFD3), shape: BoxShape.circle)),
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
                        fontWeight: isCurrentStage ? FontWeight.bold : FontWeight.w500,
                        fontSize: 13,
                        color: isActive ? const Color(0xFF24382F) : const Color(0xFF788078),
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
