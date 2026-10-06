import 'package:flutter/material.dart';
import 'menu_screen.dart';
import 'checkout_screen.dart';
import 'assistance_screen.dart';

class ShoppingCartScreen extends StatefulWidget {
  final Map<FoodItem, int> cart;
  final double total;
  final int? tableId;
  final bool isTakeout;

  const ShoppingCartScreen({
    super.key,
    required this.cart,
    required this.total,
    this.tableId = 7,
    this.isTakeout = false,
  });

  @override
  State<ShoppingCartScreen> createState() => _ShoppingCartScreenState();
}

class _ShoppingCartScreenState extends State<ShoppingCartScreen> {
  late Map<FoodItem, int> _editableCart;
  late double _calculatedTotal;

  @override
  void initState() {
    super.initState();
    _editableCart = Map.from(widget.cart);
    _calculatedTotal = widget.total;
  }

  void _recalculateTotal() {
    setState(() {
      _calculatedTotal = _editableCart.entries.fold(
        0.0,
            (sum, entry) => sum + (entry.key.price * entry.value),
      );
    });
  }

  void _updateQuantity(FoodItem item, int delta) {
    setState(() {
      final currentQty = _editableCart[item] ?? 0;
      final newQty = currentQty + delta;
      if (newQty <= 0) {
        _editableCart.remove(item);
      } else {
        _editableCart[item] = newQty;
      }
      _recalculateTotal();
    });
  }

  void _removeItem(FoodItem item) {
    setState(() {
      _editableCart.remove(item);
      _recalculateTotal();
    });
  }

  int get _totalItemCount => _editableCart.values.fold(0, (sum, qty) => sum + qty);

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
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildIntroductionHeader(),
                    const SizedBox(height: 20),
                    if (_editableCart.isEmpty)
                      _buildEmptyCartView()
                    else ...[
                      ..._editableCart.entries.map((entry) => _buildCartItemCard(entry.key, entry.value)),
                      const SizedBox(height: 12),
                      _buildPriceBreakdownCard(),
                      const SizedBox(height: 24),
                      _buildActionButtonsArea(),
                    ],
                  ],
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

  Widget _buildIntroductionHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NEW ORDER • $_totalItemCount ITEMS',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFFA47C3D),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          "Your table's favorites.",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF203F35),
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'A lovely spread for ${widget.isTakeout ? "Takeout" : "Table ${widget.tableId ?? 7}"}. Adjust any dish before sending it to the kitchen.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF788078), height: 1.4),
        ),
      ],
    );
  }

  Widget _buildEmptyCartView() {
    return Container(
      padding: const EdgeInsets.all(32),
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDFA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5DFD3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.shopping_bag_outlined, size: 48, color: Color(0xFF788078)),
          const SizedBox(height: 16),
          const Text(
            'Your shopping cart is empty.',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF203F35)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Explore our heritage selections and add your favorite dishes.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF788078)),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF203F35),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Add More Dishes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItemCard(FoodItem item, int quantity) {
    final double itemTotal = item.price * quantity;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
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
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dish Image Container
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEE7D9),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.restaurant_outlined, size: 24, color: Color(0xFF203F35)),
                      const SizedBox(height: 2),
                      Text(
                        item.name.substring(0, 1),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFA47C3D)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Dish Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF24382F)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        InkWell(
                          onTap: () => _removeItem(item),
                          child: const Icon(Icons.delete_outline, size: 18, color: Color(0xFF788078)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₱${item.price.toStringAsFixed(0)} each',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF788078)),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Standard Serving',
                      style: TextStyle(fontSize: 10, color: Color(0xFF53766C)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Quantity Stepper and Item Total Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F4EC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE5DFD3)),
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => _updateQuantity(item, -1),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6.0),
                        child: Icon(Icons.remove, size: 16, color: Color(0xFF203F35)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$quantity',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF24382F)),
                    ),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: () => _updateQuantity(item, 1),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6.0),
                        child: Icon(Icons.add, size: 16, color: Color(0xFF203F35)),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '₱${itemTotal.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF203F35)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceBreakdownCard() {
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Food & drinks', style: TextStyle(fontSize: 12, color: Color(0xFF788078))),
              Text('₱${_calculatedTotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF203F35))),
            ],
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Selected add-ons', style: TextStyle(fontSize: 12, color: Color(0xFF788078))),
              Text('₱0', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF203F35))),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Divider(height: 1, color: Color(0xFFE5DFD3)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF24382F))),
              Text(
                '₱${_calculatedTotal.toStringAsFixed(0)}',
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

  Widget _buildActionButtonsArea() {
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
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CheckoutScreen(
                    cart: _editableCart,
                    total: _calculatedTotal,
                    tableId: widget.tableId,
                    isTakeout: widget.isTakeout,
                  ),
                ),
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Review order • ₱${_calculatedTotal.toStringAsFixed(0)}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
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
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Add more dishes',
              style: TextStyle(color: Color(0xFF203F35), fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }
}
