import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'menu_screen.dart';
import 'qr_scanner_screen.dart';
import 'user_session.dart';
import 'order_status_screen.dart';
import 'services/audio_notification_service.dart';

class OrderTypeSelectionScreen extends StatefulWidget {
  final int tableNumber;
  final int tableId;
  final String? qrToken;

  const OrderTypeSelectionScreen({
    super.key,
    this.tableNumber = 7,
    this.tableId = 7,
    this.qrToken,
  });

  @override
  State<OrderTypeSelectionScreen> createState() =>
      _OrderTypeSelectionScreenState();
}

class _OrderTypeSelectionScreenState extends State<OrderTypeSelectionScreen> {
  bool _isAdditionalOrderSelected = false;
  bool _isLoadingSession = false;
  bool _isLoadingOrders = false;

  int? _resolvedTableId;
  int? _resolvedTableNumber;

  List<dynamic> _unfinishedOrders = [];

  @override
  void initState() {
    super.initState();
    _resolvedTableId = widget.tableId;
    _resolvedTableNumber = widget.tableNumber;
    UserSession.activeTableId = widget.tableId;
    UserSession.activeTableNumber = widget.tableNumber;

    if (widget.qrToken != null && widget.qrToken!.isNotEmpty) {
      _processQrScanToken(widget.qrToken!);
    } else {
      _fetchUnfinishedOrders();
    }
  }

  Future<void> _processQrScanToken(String token) async {
    setState(() => _isLoadingSession = true);
    try {
      final response = await http
          .get(Uri.parse('http://localhost:5000/api/session/scan/$token'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        setState(() {
          _resolvedTableId = resData['table_id'] ?? widget.tableId;
          _resolvedTableNumber = resData['table_number'] ?? widget.tableNumber;

          UserSession.sessionId = resData['session_id']?.toString();
          UserSession.activeSessionId = int.tryParse(
            resData['session_id']?.toString() ?? '',
          );
          UserSession.customerSessionToken = resData['session_token']
              ?.toString();
          UserSession.activeTableId = _resolvedTableId;
          UserSession.activeTableNumber = _resolvedTableNumber;
        });
      }
    } catch (_) {
      // Handle connection error if needed
    } finally {
      if (mounted) setState(() => _isLoadingSession = false);
      _fetchUnfinishedOrders();
    }
  }

  Future<void> _fetchUnfinishedOrders() async {
    final tId = _resolvedTableId ?? widget.tableId;
    setState(() => _isLoadingOrders = true);

    try {
      final response = await http.get(
        Uri.parse('http://localhost:5000/api/v1/orders/unfinished?table_id=$tId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List ordersList = data['orders'] ?? data['data'] ?? [];
        setState(() {
          _unfinishedOrders = ordersList;
          if (_unfinishedOrders.isEmpty) {
            _isAdditionalOrderSelected = false;
          }
        });
      }
    } catch (_) {
      setState(() {
        _unfinishedOrders = [];
        _isAdditionalOrderSelected = false;
      });
    } finally {
      if (mounted) setState(() => _isLoadingOrders = false);
    }
  }

  Future<void> _navigateToMenu() async {
    final bool hasUnfinished = _unfinishedOrders.isNotEmpty;
    final bool isAdditional = _isAdditionalOrderSelected && hasUnfinished;

    UserSession.activeTableId = _resolvedTableId ?? widget.tableId;
    UserSession.activeTableNumber = _resolvedTableNumber ?? widget.tableNumber;

    if (isAdditional && hasUnfinished) {
      UserSession.isAdditionalOrder = true;

      // Kung Additional Order, mamimili kung aling unfinished order ang lalagyan ng add-on
      final selectedOrder = await _showSelectOrderDialog(
        title: 'Select Order to Add Items',
        subtitle: 'Choose which ticket to link your additional items to.',
      );

      if (selectedOrder == null) return;

      final rawParentId = selectedOrder['id'] ?? selectedOrder['order_id'];
      UserSession.targetParentOrderId = rawParentId?.toString();
    } else {
      // NEW ORDER FLOW: Kung may mga lumang orders, bigyan ng pagpipilian ang user
      if (hasUnfinished) {
        final actionChoice = await showDialog<String>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: const Color(0xFFFFFDFA),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Text(
                'Existing Table Orders',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF203F35),
                ),
              ),
              content: const Text(
                'Would you like to view your live monitoring tickets, or proceed with a brand new separate order?',
                style: TextStyle(color: Color(0xFF788078), fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, 'view_tickets'),
                  child: const Text(
                    'View Tickets',
                    style: TextStyle(color: Color(0xFF53766C)),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF203F35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context, 'brand_new'),
                  child: const Text(
                    'Start New Order',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );

        if (actionChoice == 'view_tickets') {
          // Ipakita ang listahan ng mga existing tickets para mapili at direktang mapuntahan ang OrderStatusScreen
          final selectedTicket = await _showSelectOrderDialog(
            title: 'Live Monitoring Tickets',
            subtitle: 'Select a ticket to review live status.',
          );

          if (selectedTicket != null && mounted) {
            final ticketId = selectedTicket['id'] ?? selectedTicket['order_id'];
            final totalAmt = double.tryParse(selectedTicket['total_amount']?.toString() ?? '0') ?? 0.0;
            final itemsList = selectedTicket['items'] is List ? selectedTicket['items'] : [];

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => OrderStatusScreen(
                  orderId: ticketId,
                  isTakeout: false,
                  tableId: _resolvedTableId ?? widget.tableId,
                  totalAmount: totalAmt,
                  isAdditionalOrder: false,
                  initialOrderItems: itemsList,
                ),
              ),
            );
          }
          return;
        } else if (actionChoice == null) {
          return; // Kinansela ng user
        }
      }

      // Brand New Order Settings (Gagawin itong malinis)
      UserSession.isAdditionalOrder = false;
      UserSession.targetParentOrderId = null;
      UserSession.lastPlacedOrderId = null;
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => MenuScreen(
          tableId: _resolvedTableId ?? widget.tableId,
          tableNumber: _resolvedTableNumber ?? widget.tableNumber,
          isAdditionalOrder: isAdditional,
        ),
      ),
    );
  }

  Future<Map<dynamic, dynamic>?> _showSelectOrderDialog({
    required String title,
    required String subtitle,
  }) async {
    return await showDialog<Map<dynamic, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFFFDFA),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF203F35),
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF788078),
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _unfinishedOrders.length,
                    itemBuilder: (context, index) {
                      final order = _unfinishedOrders[index];
                      final orderId = order['id'] ?? order['order_id'];
                      final total = order['total_amount'] ?? '0.00';
                      final status = order['order_status'] ?? 'PENDING';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F4EC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5DFD3)),
                        ),
                        child: ListTile(
                          title: Text(
                            '${UserSession.formatOrderCode(orderId)} ($status)',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF203F35),
                            ),
                          ),
                          subtitle: Text(
                            'Total: ₱$total',
                            style: const TextStyle(color: Color(0xFF788078)),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 14,
                            color: Color(0xFFA47C3D),
                          ),
                          onTap: () => Navigator.pop(context, order),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF788078)),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4EC),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 12.0,
              ),
              child: _buildRestaurantHeader(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 8.0,
                ),
                child: _buildStepContent(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: _buildPrimaryActionButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    return _buildTypeSelectionView();
  }

  Widget _buildTypeSelectionView() {
    final int currentTable = _resolvedTableNumber ?? _resolvedTableId ?? 7;
    final int unfinishedCount = _unfinishedOrders.length;
    final bool hasUnfinished = unfinishedCount > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTableContextStrip(currentTable),
        const SizedBox(height: 24),
        _buildIntroductionSection(),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFEEE7D9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline,
                size: 16,
                color: Color(0xFF203F35),
              ),
              const SizedBox(width: 8),
              Text(
                _isLoadingOrders
                    ? 'Checking table orders...'
                    : '$unfinishedCount unfinished ${unfinishedCount == 1 ? "order" : "orders"} at Table ${currentTable.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: Color(0xFF203F35),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildNewOrderOptionCard(),
        const SizedBox(height: 14),
        _buildAdditionalOrderOptionCard(hasUnfinished: hasUnfinished),
        const SizedBox(height: 20),
        _buildContextNoteBox(),
      ],
    );
  }

  Widget _buildRestaurantHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        InkWell(
          onTap: () async {
            final bool? changeTable = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: const Color(0xFFFFFDFA),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                title: const Text(
                  'Change Table?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF203F35),
                  ),
                ),
                content: const Text(
                  'Do you want to change table? This will clear your current table session.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text(
                      'No',
                      style: TextStyle(color: Color(0xFF788078)),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF203F35),
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text(
                      'Yes',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );

            if (changeTable == true && mounted) {
              UserSession.clearSession();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const QrScannerScreen(),
                ),
              );
            }
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
    );
  }

  Widget _buildTableContextStrip(int currentTable) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEEE7D9),
        borderRadius: BorderRadius.circular(12),
      ),
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
                'Table ${currentTable.toString().padLeft(2, '0')} • verified',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  color: Color(0xFF203F35),
                ),
              ),
            ],
          ),
          const Text(
            'Dine-in',
            style: TextStyle(
              fontSize: 10,
              color: Color(0xFF788078),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroductionSection() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "LET'S BEGIN",
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFFA47C3D),
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'What brings you to the table?',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF203F35),
            height: 1.2,
          ),
        ),
        SizedBox(height: 10),
        Text(
          'Choose how you’d like to order. There’s always room for another favorite.',
          style: TextStyle(fontSize: 14, color: Color(0xFF788078), height: 1.4),
        ),
      ],
    );
  }

  Widget _buildNewOrderOptionCard() {
    final bool isSelected = !_isAdditionalOrderSelected;
    return InkWell(
      onTap: () => setState(() => _isAdditionalOrderSelected = false),
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF203F35) : const Color(0xFFFFFDFA),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF203F35)
                : const Color(0xFFE5DFD3),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  Icons.restaurant_outlined,
                  color: isSelected
                      ? const Color(0xFFD7BF91)
                      : const Color(0xFF203F35),
                  size: 26,
                ),
                Icon(
                  isSelected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: isSelected
                      ? const Color(0xFFF8F4EC)
                      : const Color(0xFF788078),
                  size: 22,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'New Order',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? const Color(0xFFF8F4EC)
                    : const Color(0xFF203F35),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Start a separate order or inspect your existing live monitoring tickets.',
              style: TextStyle(
                fontSize: 13,
                color: isSelected
                    ? const Color(0xFFCBD7CF)
                    : const Color(0xFF788078),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionalOrderOptionCard({required bool hasUnfinished}) {
    final bool isSelected = _isAdditionalOrderSelected;

    return Opacity(
      opacity: hasUnfinished ? 1.0 : 0.5,
      child: InkWell(
        onTap: hasUnfinished
            ? () => setState(() => _isAdditionalOrderSelected = true)
            : null,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF203F35)
                : const Color(0xFFFFFDFA),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF203F35)
                  : const Color(0xFFE5DFD3),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    Icons.add_circle_outline,
                    color: isSelected
                        ? const Color(0xFFD7BF91)
                        : const Color(0xFF203F35),
                    size: 26,
                  ),
                  Icon(
                    isSelected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: isSelected
                        ? const Color(0xFFF8F4EC)
                        : const Color(0xFF788078),
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Additional Order',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? const Color(0xFFF8F4EC)
                      : const Color(0xFF203F35),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                hasUnfinished
                    ? 'Add to an unfinished order. Next, choose which order to link your additions to.'
                    : 'No unfinished order to add to. Start a New Order instead.',
                style: TextStyle(
                  fontSize: 13,
                  color: isSelected
                      ? const Color(0xFFCBD7CF)
                      : const Color(0xFF788078),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContextNoteBox() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF0E9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.layers_outlined, color: Color(0xFF53766C), size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'New and additional items are handled cleanly via active table tickets and live status.',
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

  Widget _buildPrimaryActionButton() {
    String buttonText = _isAdditionalOrderSelected
        ? "Continue with Additional Items →"
        : "Continue with New Order →";

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF203F35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        onPressed: _isLoadingSession ? null : _navigateToMenu,
        child: _isLoadingSession
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
          buttonText,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}