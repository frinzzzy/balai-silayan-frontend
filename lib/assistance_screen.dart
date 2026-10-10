import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'menu_screen.dart';
import 'order_status_screen.dart';
import 'user_session.dart';

class AssistanceScreen extends StatefulWidget {
  final int? tableId;
  final bool isTakeout;

  const AssistanceScreen({
    super.key,
    this.tableId = 7,
    this.isTakeout = false,
  });

  @override
  State<AssistanceScreen> createState() => _AssistanceScreenState();
}

class _AssistanceScreenState extends State<AssistanceScreen> {
  final TextEditingController _customNoteController = TextEditingController();
  final Set<String> _selectedCategories = {"Water"};
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _activeRequests = [];

  final List<String> _assistanceOptions = [
    "Water",
    "Utensils / Plates",
    "Napkins / Condiments",
    "Bill",
  ];

  @override
  void initState() {
    super.initState();
    _fetchLiveAssistanceRequests();
  }

  Future<void> _fetchLiveAssistanceRequests() async {
    try {
      final response = await http.get(Uri.parse('http://localhost:5000/api/v1/assistance'));
      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        final List<dynamic> dataList = resData['data'] ?? [];
        if (dataList.isNotEmpty && mounted) {
          final liveMapped = dataList.map((req) {
            final reqId = req['request_id'] ?? req['id'] ?? 0;
            final tableNum = req['table_number'] ?? req['table_id'] ?? widget.tableId ?? 7;
            final status = (req['status'] ?? 'PENDING').toString().toUpperCase();
            final message = req['message'] ?? req['request_type'] ?? 'Assistance Requested';
            return {
              "id": "REQ-${1000 + (reqId as int)}",
              "table": tableNum,
              "message": message,
              "status": status,
            };
          }).toList();

          setState(() {
            _activeRequests = List<Map<String, dynamic>>.from(liveMapped);
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _submitAssistanceRequest({String? quickType}) async {
    setState(() => _isSubmitting = true);

    final int targetTableId = widget.tableId ?? 7;
    final String categoryText = quickType ?? (_selectedCategories.isEmpty ? "General Help" : _selectedCategories.join(", "));
    final String notes = _customNoteController.text.trim();
    final String fullMessage = notes.isNotEmpty ? "$categoryText: $notes" : categoryText;

    final Map<String, dynamic> payload = {
      "table_id": targetTableId,
      "request_type": categoryText,
      "message": fullMessage,
      "timestamp": DateTime.now().toIso8601String(),
    };

    try {
      final response = await http.post(
        Uri.parse('http://localhost:5000/api/v1/assistance'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          _customNoteController.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Assistance request sent to waiter control station!'),
              backgroundColor: Color(0xFF203F35),
            ),
          );
          _fetchLiveAssistanceRequests();
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request sent locally to waiter station!'),
            backgroundColor: Color(0xFF203F35),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final int tableNum = widget.tableId ?? UserSession.activeTableId ?? UserSession.activeTableNumber ?? 7;
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildIntroductionHeader(),
                    const SizedBox(height: 20),
                    _buildCallWaiterOptionCard(),
                    const SizedBox(height: 20),
                    _buildSpecificAssistanceSection(),
                    const SizedBox(height: 16),
                    _buildCustomNoteTextField(),
                    const SizedBox(height: 16),
                    _buildContextInfoNote(),
                    const SizedBox(height: 24),
                    _buildPrimaryActionButton(),
                    const SizedBox(height: 28),
                    if (_activeRequests.isNotEmpty) _buildActiveRequestsList(),
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
            onTap: () => Navigator.pop(context),
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
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF203F35),
              border: Border.all(color: const Color(0xFF203F35)),
            ),
            child: const Icon(Icons.notifications, color: Colors.white, size: 20),
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

  Widget _buildIntroductionHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STAFF SERVICE',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFFA47C3D),
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'How can we assist your table?',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF203F35),
            height: 1.2,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Select an option or type a message below. A waiter will attend to your table shortly.',
          style: TextStyle(fontSize: 13, color: Color(0xFF788078), height: 1.4),
        ),
      ],
    );
  }

  Widget _buildCallWaiterOptionCard() {
    return Container(
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
          Row(
            children: [
              const Icon(Icons.room_service_outlined, size: 28, color: Color(0xFF203F35)),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Call Waiter',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF24382F)),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Instant notification sent directly to waiter’s station.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF788078)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFFFFFDFA),
                side: const BorderSide(color: Color(0xFFE5DFD3)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _isSubmitting ? null : () => _submitAssistanceRequest(quickType: "Call Waiter"),
              child: const Text(
                'Call Waiter Now',
                style: TextStyle(color: Color(0xFF203F35), fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecificAssistanceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Specific Assistance',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF24382F)),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _assistanceOptions.map((option) {
            final isSelected = _selectedCategories.contains(option);
            return ChoiceChip(
              label: Text(option),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedCategories.add(option);
                  } else {
                    _selectedCategories.remove(option);
                  }
                });
              },
              selectedColor: const Color(0xFFEAF0E9),
              backgroundColor: const Color(0xFFFFFDFA),
              labelStyle: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: isSelected ? const Color(0xFF203F35) : const Color(0xFF203F35),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              side: BorderSide(
                color: isSelected ? const Color(0xFF53766C) : const Color(0xFFE5DFD3),
                width: isSelected ? 1.5 : 1.0,
              ),
              showCheckmark: false,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCustomNoteTextField() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDFA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5DFD3)),
      ),
      child: TextField(
        controller: _customNoteController,
        maxLines: 2,
        decoration: const InputDecoration(
          hintText: 'Type custom request or notes here...',
          hintStyle: TextStyle(color: Color(0xFF788078), fontSize: 13),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildContextInfoNote() {
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
              'Waiters receive real-time notifications on their control station when you submit.',
              style: TextStyle(fontSize: 12, color: Color(0xFF53766C), height: 1.4),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
        onPressed: _isSubmitting ? null : () => _submitAssistanceRequest(),
        child: _isSubmitting
            ? const CircularProgressIndicator(color: Colors.white)
            : const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Request Assistance', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            SizedBox(width: 8),
            Icon(Icons.notifications_active_outlined, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveRequestsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Active Assistance Requests',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF203F35)),
        ),
        const SizedBox(height: 12),
        ..._activeRequests.map((ticket) {
          final isResolved = ticket['status'] == 'RESOLVED';
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFDFA),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5DFD3)),
            ),
            child: Row(
              children: [
                Icon(
                  isResolved ? Icons.check_circle_outline : Icons.access_time_outlined,
                  color: isResolved ? const Color(0xFF53766C) : const Color(0xFFA47C3D),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ticket['id'] ?? 'REQ-1000',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF203F35)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ticket['message'] ?? 'Table Assistance',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF788078)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isResolved ? const Color(0xFFEAF0E9) : const Color(0xFFEEE7D9),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    ticket['status'] ?? 'PENDING',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isResolved ? const Color(0xFF203F35) : const Color(0xFFA47C3D),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
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
          _buildNavItem(Icons.notifications, 'Help', isActive: true, onTap: () {}),
          _buildNavItem(Icons.account_balance_wallet_outlined, 'Pay', onTap: () {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MenuScreen()));
          }),
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
