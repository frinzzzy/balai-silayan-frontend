import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'menu_screen.dart';
import 'assistance_screen.dart';

class FoodAddOn {
  final int id;
  final int menuItemId;
  final String name;
  final double price;

  FoodAddOn({
    required this.id,
    required this.menuItemId,
    required this.name,
    required this.price,
  });

  factory FoodAddOn.fromJson(Map<String, dynamic> json) {
    return FoodAddOn(
      id: json['id'] ?? 0,
      menuItemId: json['menu_item_id'] ?? 0,
      name: json['name'] ?? 'Add-On',
      price: double.tryParse(json['price']?.toString() ?? '0.0') ?? 0.0,
    );
  }
}

class FoodDetailsScreen extends StatefulWidget {
  final FoodItem foodItem;
  final int? tableId;
  final bool isTakeout;
  final Function(FoodItem item, int quantity, List<FoodAddOn> selectedAddOns)? onAddToCart;

  const FoodDetailsScreen({
    super.key,
    required this.foodItem,
    this.tableId = 7,
    this.isTakeout = false,
    this.onAddToCart,
  });

  @override
  State<FoodDetailsScreen> createState() => _FoodDetailsScreenState();
}

class _FoodDetailsScreenState extends State<FoodDetailsScreen> {
  int _quantity = 1;
  List<FoodAddOn> _availableAddOns = [];
  final Set<FoodAddOn> _selectedAddOns = {};
  bool _isLoadingAddOns = true;

  // Complete Embedded Database Add-Ons Mapping matching PostgreSQL
  final List<FoodAddOn> _databaseAddOns = [
    // Silogs & Budget Meals (Items 65 - 76)
    FoodAddOn(id: 1, menuItemId: 65, name: "Extra Egg", price: 15.00),
    FoodAddOn(id: 2, menuItemId: 66, name: "Extra Egg", price: 15.00),
    FoodAddOn(id: 3, menuItemId: 67, name: "Extra Egg", price: 15.00),
    FoodAddOn(id: 4, menuItemId: 68, name: "Extra Egg", price: 15.00),
    FoodAddOn(id: 5, menuItemId: 69, name: "Extra Egg", price: 15.00),
    FoodAddOn(id: 6, menuItemId: 70, name: "Extra Egg", price: 15.00),
    FoodAddOn(id: 7, menuItemId: 71, name: "Extra Egg", price: 15.00),
    FoodAddOn(id: 8, menuItemId: 72, name: "Extra Egg", price: 15.00),
    FoodAddOn(id: 9, menuItemId: 73, name: "Extra Egg", price: 15.00),
    FoodAddOn(id: 10, menuItemId: 74, name: "Extra Egg", price: 15.00),
    FoodAddOn(id: 11, menuItemId: 75, name: "Extra Egg", price: 15.00),
    FoodAddOn(id: 12, menuItemId: 76, name: "Extra Egg", price: 15.00),
    FoodAddOn(id: 13, menuItemId: 65, name: "Extra Rice", price: 25.00),
    FoodAddOn(id: 14, menuItemId: 66, name: "Extra Rice", price: 25.00),
    FoodAddOn(id: 15, menuItemId: 67, name: "Extra Rice", price: 25.00),
    FoodAddOn(id: 16, menuItemId: 68, name: "Extra Rice", price: 25.00),
    FoodAddOn(id: 17, menuItemId: 69, name: "Extra Rice", price: 25.00),
    FoodAddOn(id: 18, menuItemId: 70, name: "Extra Rice", price: 25.00),
    FoodAddOn(id: 19, menuItemId: 71, name: "Extra Rice", price: 25.00),
    FoodAddOn(id: 20, menuItemId: 72, name: "Extra Rice", price: 25.00),
    FoodAddOn(id: 21, menuItemId: 73, name: "Extra Rice", price: 25.00),
    FoodAddOn(id: 22, menuItemId: 74, name: "Extra Rice", price: 25.00),
    FoodAddOn(id: 23, menuItemId: 75, name: "Extra Rice", price: 25.00),
    FoodAddOn(id: 24, menuItemId: 76, name: "Extra Rice", price: 25.00),

    // Pizzas (Items 77 - 83)
    FoodAddOn(id: 25, menuItemId: 77, name: "Extra Cheese", price: 50.00),
    FoodAddOn(id: 26, menuItemId: 78, name: "Extra Cheese", price: 50.00),
    FoodAddOn(id: 27, menuItemId: 79, name: "Extra Cheese", price: 50.00),
    FoodAddOn(id: 28, menuItemId: 80, name: "Extra Cheese", price: 50.00),
    FoodAddOn(id: 29, menuItemId: 81, name: "Extra Cheese", price: 50.00),
    FoodAddOn(id: 30, menuItemId: 82, name: "Extra Cheese", price: 50.00),
    FoodAddOn(id: 31, menuItemId: 83, name: "Extra Cheese", price: 50.00),

    // Burgers & Sandwiches (Items 16 - 19, 76)
    FoodAddOn(id: 32, menuItemId: 16, name: "Extra Cheese", price: 20.00),
    FoodAddOn(id: 33, menuItemId: 17, name: "Extra Cheese", price: 20.00),
    FoodAddOn(id: 34, menuItemId: 18, name: "Extra Cheese", price: 20.00),
    FoodAddOn(id: 35, menuItemId: 19, name: "Extra Cheese", price: 20.00),
    FoodAddOn(id: 36, menuItemId: 76, name: "Extra Cheese", price: 20.00),
    FoodAddOn(id: 37, menuItemId: 19, name: "Extra Patty", price: 50.00),
    FoodAddOn(id: 38, menuItemId: 76, name: "Extra Patty", price: 50.00),

    // Sizzling Plates (Items 53 - 57)
    FoodAddOn(id: 39, menuItemId: 53, name: "Extra Gravy", price: 15.00),
    FoodAddOn(id: 40, menuItemId: 54, name: "Extra Gravy", price: 15.00),
    FoodAddOn(id: 41, menuItemId: 55, name: "Extra Gravy", price: 15.00),
    FoodAddOn(id: 42, menuItemId: 56, name: "Extra Gravy", price: 15.00),
    FoodAddOn(id: 43, menuItemId: 57, name: "Extra Gravy", price: 15.00),
    FoodAddOn(id: 44, menuItemId: 53, name: "Extra Egg", price: 15.00),
    FoodAddOn(id: 45, menuItemId: 54, name: "Extra Egg", price: 15.00),
    FoodAddOn(id: 46, menuItemId: 55, name: "Extra Egg", price: 15.00),
    FoodAddOn(id: 47, menuItemId: 56, name: "Extra Egg", price: 15.00),
    FoodAddOn(id: 48, menuItemId: 57, name: "Extra Egg", price: 15.00),

    // Wings (Items 21 - 26)
    FoodAddOn(id: 49, menuItemId: 21, name: "Extra Wings Sauce Dip", price: 25.00),
    FoodAddOn(id: 50, menuItemId: 22, name: "Extra Wings Sauce Dip", price: 25.00),
    FoodAddOn(id: 51, menuItemId: 23, name: "Extra Wings Sauce Dip", price: 25.00),
    FoodAddOn(id: 52, menuItemId: 24, name: "Extra Wings Sauce Dip", price: 25.00),
    FoodAddOn(id: 53, menuItemId: 25, name: "Extra Wings Sauce Dip", price: 25.00),
    FoodAddOn(id: 54, menuItemId: 26, name: "Extra Wings Sauce Dip", price: 25.00),

    // Kare-Kare (Items 33 - 34)
    FoodAddOn(id: 55, menuItemId: 33, name: "Extra Bagoong", price: 20.00),
    FoodAddOn(id: 56, menuItemId: 34, name: "Extra Bagoong", price: 20.00),

    // Korean Specialty Sauces (Items 117 - 129)
    FoodAddOn(id: 57, menuItemId: 118, name: "Extra Black Sauce (Jjajang)", price: 5.00),
    FoodAddOn(id: 58, menuItemId: 117, name: "Extra Orange/Spicy Sauce", price: 5.00),
    FoodAddOn(id: 59, menuItemId: 118, name: "Extra Orange/Spicy Sauce", price: 5.00),
    FoodAddOn(id: 60, menuItemId: 119, name: "Extra Orange/Spicy Sauce", price: 5.00),
    FoodAddOn(id: 61, menuItemId: 124, name: "Extra Orange/Spicy Sauce", price: 5.00),
    FoodAddOn(id: 62, menuItemId: 128, name: "Extra Orange/Spicy Sauce", price: 5.00),
    FoodAddOn(id: 63, menuItemId: 129, name: "Extra Orange/Spicy Sauce", price: 5.00),
  ];

  @override
  void initState() {
    super.initState();
    _fetchItemAddOns();
  }

  Future<void> _fetchItemAddOns() async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:5000/api/v1/menu/${widget.foodItem.itemDbId}/add-ons'),
      );
      if (response.statusCode == 200) {
        final decodedData = jsonDecode(response.body);
        final List list = decodedData['data'] ?? [];
        if (list.isNotEmpty && mounted) {
          setState(() {
            _availableAddOns = list.map((a) => FoodAddOn.fromJson(a)).toList();
            _isLoadingAddOns = false;
          });
          return;
        }
      }
    } catch (_) {}

    // Fallback to embedded database mapping for this item ID
    if (mounted) {
      final filtered = _databaseAddOns.where((a) => a.menuItemId == widget.foodItem.itemDbId).toList();
      setState(() {
        _availableAddOns = filtered;
        _isLoadingAddOns = false;
      });
    }
  }

  double get _addOnsSubtotal => _selectedAddOns.fold(0.0, (sum, a) => sum + a.price);
  double get _calculatedGrandTotal => (widget.foodItem.price + _addOnsSubtotal) * _quantity;

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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildEditorialPhotoBanner(),
                    const SizedBox(height: 16),
                    _buildDishMetadataBadges(),
                    const SizedBox(height: 16),
                    _buildDishIntroductionHeader(),
                    const SizedBox(height: 12),
                    _buildSummaryPriceRow(),
                    const SizedBox(height: 12),
                    _buildDishDescriptionCopy(),
                    const SizedBox(height: 20),
                    if (_availableAddOns.isNotEmpty) ...[
                      _buildAddOnsCard(),
                      const SizedBox(height: 20),
                    ],
                    _buildServingQuantityRow(),
                    const SizedBox(height: 24),
                    _buildPrimaryActionButton(),
                    const SizedBox(height: 16),
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

  Widget _buildEditorialPhotoBanner() {
    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFEEE7D9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5DFD3)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_getCategoryIcon(widget.foodItem.categoryId), size: 54, color: const Color(0xFF203F35)),
            const SizedBox(height: 8),
            Text(
              widget.foodItem.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF203F35),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDishMetadataBadges() {
    final bool available = widget.foodItem.isAvailable;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFEEE7D9),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            _getCategoryLabel(widget.foodItem.categoryId),
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFA47C3D)),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: available ? const Color(0xFFEAF0E9) : const Color(0xFFF7ECE3),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Row(
            children: [
              Icon(
                available ? Icons.check_circle_outline : Icons.error_outline,
                size: 13,
                color: available ? const Color(0xFF203F35) : const Color(0xFF8E5136),
              ),
              const SizedBox(width: 4),
              Text(
                available ? 'In Stock' : 'Sold Out',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: available ? const Color(0xFF203F35) : const Color(0xFF8E5136),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDishIntroductionHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'HERITAGE SELECTION',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFA47C3D), letterSpacing: 1.2),
        ),
        const SizedBox(height: 4),
        Text(
          widget.foodItem.name,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF203F35),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryPriceRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Base Serving Price',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF24382F)),
        ),
        Text(
          '₱${widget.foodItem.price.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF203F35)),
        ),
      ],
    );
  }

  Widget _buildDishDescriptionCopy() {
    return const Text(
      'Authentic heritage recipe crafted using fresh local ingredients, slow-cooked to perfection according to traditional Balai Silayan culinary standards.',
      style: TextStyle(fontSize: 13, color: Color(0xFF788078), height: 1.5),
    );
  }

  Widget _buildAddOnsCard() {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Customize Your Dish',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF24382F)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF0E9),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Text('Optional', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF788078))),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_isLoadingAddOns)
            const Center(child: CircularProgressIndicator(color: Color(0xFF203F35)))
          else
            ..._availableAddOns.map((addOn) {
              final isChecked = _selectedAddOns.contains(addOn);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      if (isChecked) {
                        _selectedAddOns.remove(addOn);
                      } else {
                        _selectedAddOns.add(addOn);
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: isChecked ? const Color(0xFF203F35) : Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: isChecked ? const Color(0xFF203F35) : const Color(0xFFE5DFD3)),
                        ),
                        child: isChecked ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              addOn.name,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF24382F)),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '+₱${addOn.price.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF203F35)),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildServingQuantityRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Serving Quantity',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF24382F)),
        ),
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
                onTap: () {
                  if (_quantity > 1) setState(() => _quantity--);
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6.0),
                  child: Icon(Icons.remove, size: 16, color: Color(0xFF203F35)),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                '$_quantity',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF24382F)),
              ),
              const SizedBox(width: 14),
              InkWell(
                onTap: () => setState(() => _quantity++),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6.0),
                  child: Icon(Icons.add, size: 16, color: Color(0xFF203F35)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryActionButton() {
    final bool available = widget.foodItem.isAvailable;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: available ? const Color(0xFF203F35) : const Color(0xFFD9DBD3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
        onPressed: !available
            ? null
            : () {
          if (widget.onAddToCart != null) {
            widget.onAddToCart!(widget.foodItem, _quantity, _selectedAddOns.toList());
          }
          Navigator.pop(context);
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              available
                  ? 'Add to Order • ₱${_calculatedGrandTotal.toStringAsFixed(0)}'
                  : 'Currently Unavailable',
              style: TextStyle(
                color: available ? Colors.white : const Color(0xFF788078),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            if (available) ...[
              const SizedBox(width: 8),
              const Icon(Icons.add_shopping_cart, color: Colors.white, size: 18),
            ]
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(int catId) {
    switch (catId) {
      case 1:
      case 2:
        return Icons.ramen_dining_outlined;
      case 3:
      case 15:
        return Icons.lunch_dining_outlined;
      case 4:
        return Icons.kebab_dining_outlined;
      case 5:
        return Icons.grass_outlined;
      case 6:
      case 7:
        return Icons.restaurant_outlined;
      case 8:
        return Icons.fastfood_outlined;
      case 9:
      case 12:
        return Icons.rice_bowl_outlined;
      case 10:
        return Icons.local_pizza_outlined;
      case 11:
        return Icons.local_cafe_outlined;
      case 13:
        return Icons.icecream_outlined;
      case 14:
        return Icons.soup_kitchen_outlined;
      default:
        return Icons.set_meal_outlined;
    }
  }

  String _getCategoryLabel(int catId) {
    switch (catId) {
      case 1:
        return 'Pancit';
      case 2:
        return 'Pasta';
      case 3:
        return 'Sandwiches';
      case 4:
        return 'Chicken Wings';
      case 5:
        return 'Vegetables';
      case 6:
        return 'Daily Specials';
      case 7:
        return 'Sizzling';
      case 8:
        return 'Pika Pika';
      case 9:
        return 'Budget Meals';
      case 10:
        return 'Pizza';
      case 11:
        return 'Drinks';
      case 12:
        return 'Rice';
      case 13:
        return 'Desserts';
      case 14:
        return 'Korean Menu';
      default:
        return 'Specialty';
    }
  }
}
