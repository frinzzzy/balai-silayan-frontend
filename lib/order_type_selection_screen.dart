import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'menu_screen.dart';
import 'assistance_screen.dart';

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

class _OrderTypeSelectionScreenState
    extends State<OrderTypeSelectionScreen> {
  bool _isNewOrderSelected = true;
  bool _isLoadingSession = false;
  int? _resolvedTableId;
  int? _resolvedTableNumber;

  @override
  void initState() {
    super.initState();

    _resolvedTableId = widget.tableId;
    _resolvedTableNumber = widget.tableNumber;

    if (widget.qrToken != null && widget.qrToken!.isNotEmpty) {
      _processQrScanToken(widget.qrToken!);
    }
  }

  Future<void> _processQrScanToken(String token) async {
    setState(() => _isLoadingSession = true);

    try {
      final response = await http.get(
        Uri.parse('http://localhost:5000/api/session/scan/$token'),
      );

      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);

        setState(() {
          _resolvedTableId = resData['table_id'] ?? widget.tableId;
          _resolvedTableNumber =
              resData['table_number'] ?? widget.tableNumber;
          _isLoadingSession = false;
        });
      } else {
        setState(() => _isLoadingSession = false);
      }
    } catch (_) {
      setState(() => _isLoadingSession = false);
    }
  }

  void _navigateToMenu() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => MenuScreen(
          tableId: _resolvedTableId ?? widget.tableId,
          tableNumber: _resolvedTableNumber ?? widget.tableNumber,
          isAdditionalOrder: !_isNewOrderSelected,
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
              border: Border.all(
                color: const Color(0xFFE5DFD3),
              ),
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
              border: Border.all(
                color: const Color(0xFFE5DFD3),
              ),
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
    final int currentTable =
        _resolvedTableNumber ?? _resolvedTableId ?? 7;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 10,
      ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "LET'S BEGIN",
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFFA47C3D),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'What brings you to the table?',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF203F35),
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Choose how you’d like to order. There’s always room for another favorite.',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF788078),
            height: 1.4,
          ),
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
              'Start your dining session with your first order.',
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

    return InkWell(
      onTap: () => setState(() => _isNewOrderSelected = false),
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
              'Already ordered? Add something more to your active table session.',
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
          Icon(
            Icons.layers_outlined,
            color: Color(0xFF53766C),
            size: 18,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Additional orders get their own order number, while sharing the same table and final bill.',
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
            ? const CircularProgressIndicator(
          color: Colors.white,
        )
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
            Icon(
              Icons.arrow_forward,
              color: Colors.white,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}