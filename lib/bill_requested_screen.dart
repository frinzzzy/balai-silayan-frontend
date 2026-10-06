import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'menu_screen.dart';
import 'assistance_screen.dart';
import 'order_status_screen.dart';

class BillRequestedScreen extends StatefulWidget {
  final int? tableId;
  final bool isTakeout;
  final double totalAmount;
  final double foodDrinksTotal;
  final double addOnsTotal;

  const BillRequestedScreen({
    super.key,
    this.tableId = 7,
    this.isTakeout = false,
    this.totalAmount = 1255.0,
    this.foodDrinksTotal = 1165.0,
    this.addOnsTotal = 90.0,
  });

  @override
  State<BillRequestedScreen> createState() => _BillRequestedScreenState();
}

class _BillRequestedScreenState extends State<BillRequestedScreen> {
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
      bottomNavigationBar: _buildCustomerBottomNav(),
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
    return Column(
      children: [
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
      ],
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEEE7D9),
        borderRadius: BorderRadius.circular(100),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time, size: 13, color: Color(0xFFA47C3D)),
          SizedBox(width: 6),
          Text(
            'Awaiting staff arrival',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFA47C3D)),
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

  Widget _buildCustomerBottomNav() {
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
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MenuScreen()));
          }),
          _buildNavItem(Icons.receipt_long_outlined, 'Orders', onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => OrderStatusScreen(orderId: 1042, isTakeout: widget.isTakeout, tableId: widget.tableId)));
          }),
          _buildNavItem(Icons.notifications_none, 'Help', onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const AssistanceScreen()));
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
