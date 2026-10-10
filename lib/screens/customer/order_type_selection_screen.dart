import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';

import 'menu_screen.dart';
import '../../assistance_screen.dart';
import '../../models/user_session.dart';

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
  bool _isNewOrderSelected = true;
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

  Future<void> _fetchUnfinishedOrders() async {
    final int tableId = _resolvedTableId ?? widget.tableId;
    if (mounted) setState(() => _isLoadingOrders = true);
    try {
      final response = await http
          .get(
            Uri.parse(
              'http://localhost:5000/api/v1/orders/unfinished?table_id=$tableId',
            ),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        final dynamic orders = resData['orders'] ?? resData['data'];
        if (mounted) {
          setState(() {
            _unfinishedOrders = orders is List ? orders : [];
            if (_unfinishedOrders.isEmpty) _isNewOrderSelected = true;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _unfinishedOrders = []);
      }
    } finally {
      if (mounted) setState(() => _isLoadingOrders = false);
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
        if (mounted) {
          setState(() {
            _resolvedTableId = resData['table_id'] ?? widget.tableId;
            _resolvedTableNumber =
                resData['table_number'] ?? widget.tableNumber;

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
      }
    } catch (_) {
      // Handle timeout or connection errors
    } finally {
      if (mounted) {
        setState(() => _isLoadingSession = false);
      }
      await _fetchUnfinishedOrders();
    }
  }

  void _navigateToMenu() {
    final bool isAdditional = !_isNewOrderSelected;
    UserSession.isAdditionalOrder = isAdditional;
    UserSession.activeTableId = _resolvedTableId ?? widget.tableId;
    UserSession.activeTableNumber = _resolvedTableNumber ?? widget.tableNumber;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4EC),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 12.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRestaurantHeader(),
                const SizedBox(height: 16),
                _buildTableContextStrip(),
                const SizedBox(height: 28),
                _buildIntroductionSection(),
                const SizedBox(height: 24),
                _buildNewOrderOptionCard(),
                const SizedBox(height: 16),
                _buildAdditionalOrderOptionCard(),
                const SizedBox(height: 20),
                _buildContextNoteBox(),
                const SizedBox(height: 32),
                _buildPrimaryActionButton(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRestaurantHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        InkWell(
          onTap: () => Navigator.maybePop(context),
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
                border: Border.all(color: const Color(0xFFA47C3D), width: 1.4),
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

  Widget _buildTableContextStrip() {
    final int currentTable = _resolvedTableNumber ?? _resolvedTableId ?? 7;
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
    final bool isSelected = _isNewOrderSelected;
    return InkWell(
      onTap: () => setState(() => _isNewOrderSelected = true),
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
          boxShadow: [
            if (!isSelected)
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
              'Start your session; new items join its active receipt.',
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

  Widget _buildAdditionalOrderOptionCard() {
    final bool isSelected = !_isNewOrderSelected;
    final bool hasUnfinishedOrders = _unfinishedOrders.isNotEmpty;
    return InkWell(
      onTap: hasUnfinishedOrders
          ? () => setState(() => _isNewOrderSelected = false)
          : null,
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
          boxShadow: [
            if (!isSelected)
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
              _isLoadingOrders
                  ? 'Checking for unfinished orders...'
                  : hasUnfinishedOrders
                  ? 'Add items to the active table receipt.'
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
              'New and additional items are added to the same active table receipt.',
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
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Explore the menu',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                ],
              ),
      ),
    );
  }
}
