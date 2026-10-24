import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'dart:ui';
import 'dart:convert';

import '../../menu_screen.dart' as root_menu;
import '../../checkout_screen.dart';
import '../../assistance_screen.dart';
import '../../orders_screen.dart';
import '../../order_status_screen.dart';
import '../../shopping_cart_screen.dart';
import '../../food_details_screen.dart';
import '../auth/qr_scanner_screen.dart';
import 'order_type_selection_screen.dart';
import '../../session_bill_screen.dart';
import '../../models/user_session.dart';

class FoodItem {
  final int itemDbId;
  final String name;
  final double price;
  final int categoryId;
  final bool isAvailable;
  final String? imageUrl;

  static final Map<int, String> hardcodedImageUrls = {
    1: 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624', // Bihon
    2: 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624', // Mike Bihon
    3: 'https://images.unsplash.com/photo-1612929633738-8fe44f7ec841', // Pansit Canton
    4: 'https://images.unsplash.com/photo-1552611052-33e04de081de', // Pansit Bihon Guisado
    5: 'https://images.unsplash.com/photo-1621996346565-e3d5d6281222', // Filipino Style Spaghetti
    6: 'https://images.unsplash.com/photo-1633964913295-ceb43826e7c9', // Creamy Carbonara
    7: 'https://images.unsplash.com/photo-1543339308-43e59d6b73a6', // Baked Macaroni
    8: 'https://images.unsplash.com/photo-1528735602780-2552fd46c7af', // Clubhouse Sandwich W/ Fries
    9: 'https://images.unsplash.com/photo-1550547660-d9450f859349', // Ham and Cheese Sandwich
    10: 'https://images.unsplash.com/photo-1539252554453-80ab65ce3586', // Tuna Melt Sandwich
    11: 'https://images.unsplash.com/photo-1567620832903-9fc6debc209f', // Plain Wings
    12: 'https://images.unsplash.com/photo-1608039829572-78524f79c4c7', // Buffalo Wings
    13: 'https://images.unsplash.com/photo-1527477396000-e27163b481c2', // Honey Garlic Wings
    14: 'https://images.unsplash.com/photo-1540420773420-3366772f4999', // Caesar Salad
    15: 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd', // Chopsuey
    16: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c', // Pinakbet
    17: 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1', // Kare-Kare (Labot)
    18: 'https://images.unsplash.com/photo-1543339308-43e59d6b73a6', // Bulalo Special
    19: 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624', // Sinigang na Baboy
    20: 'https://images.unsplash.com/photo-1626777552726-4a6b54c97e46', // Sizzling Chicken
    21: 'https://images.unsplash.com/photo-1544025162-d76694265947', // Sizzling Pork Sisig
    22: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c', // Sizzling Tofu
    23: 'https://images.unsplash.com/photo-1573080496219-bb080dd4f877', // French Fries
    24: 'https://images.unsplash.com/photo-1513456852971-30c0b8199d4d', // Nachos Supreme
    25: 'https://images.unsplash.com/photo-1534422298391-e4f8c172dddb', // Fish and Chips
    26: 'https://images.unsplash.com/photo-1555126634-323283e090fa', // Tapsilog
    27: 'https://images.unsplash.com/photo-1544025162-d76694265947', // Porksilog
    28: 'https://images.unsplash.com/photo-1567620832903-9fc6debc209f', // Chickensilog
    29: 'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2', // Bangusilog
    30: 'https://images.unsplash.com/photo-1513104890138-7c749659a591', // Super Supreme Pizza
    31: 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38', // Hawaiian Overload
    32: 'https://images.unsplash.com/photo-1534308983496-4fabb1a015ee', // Pepperoni Classic
    33: 'https://images.unsplash.com/photo-1548839140-29a749e1cf4d', // Bottled Water
    34: 'https://images.unsplash.com/photo-1556679343-c7306c1976bc', // Iced Tea (Glass)
    35: 'https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd', // Blue Lemonade
    36: 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97', // Coke Regular (330ml)
    37: 'https://images.unsplash.com/photo-1625772299848-391b6a87d7b3', // Sprite (330ml)
    38: 'https://images.unsplash.com/photo-1516684732162-798a0062be99', // Plain Rice (Solo)
    39: 'https://images.unsplash.com/photo-1512058564366-18510be2db19', // Garlic Rice
    40: 'https://images.unsplash.com/photo-1543339308-43e59d6b73a6', // Java Rice
    41: 'https://images.unsplash.com/photo-1563805042-7684c019e1cb', // Halo-Halo Special
    42: 'https://images.unsplash.com/photo-1509440159596-0249088772ff', // Leche Flan
    43: 'https://images.unsplash.com/photo-1488477181946-6428a0291777', // Mango Panna Cotta
    44: 'https://images.unsplash.com/photo-1553163147-622ab57be1c2', // Bibimbap
    45: 'https://images.unsplash.com/photo-1590301157890-4810ed352733', // Kimchi Fried Rice
    46: 'https://images.unsplash.com/photo-1541658016709-82535e94bc69', // Tteokbokki
    47: 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624', // Ramen with Cheese
  };

  FoodItem({
    required this.itemDbId,
    required this.name,
    required this.price,
    required this.categoryId,
    this.isAvailable = true,
    String? imageUrl,
  }) : imageUrl = imageUrl ?? hardcodedImageUrls[itemDbId] ?? 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624';

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    final int id = json['id'] ?? 0;
    final String? dbImg = json['image_url'];
    final String fallbackImg = hardcodedImageUrls[id] ?? 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624';

    return FoodItem(
      itemDbId: id,
      name: json['name'] ?? 'Delicious Dish',
      price: double.tryParse(json['price']?.toString() ?? '0.0') ?? 0.0,
      categoryId: json['category_id'] ?? 1,
      isAvailable: json['is_available'] ?? true,
      imageUrl: (dbImg != null && dbImg.isNotEmpty) ? dbImg : fallbackImg,
    );
  }
}

class MenuCategory {
  final int id;
  final String name;

  MenuCategory({required this.id, required this.name});

  factory MenuCategory.fromJson(Map<String, dynamic> json) {
    return MenuCategory(id: json['id'] ?? 0, name: json['name'] ?? 'Category');
  }
}

class MenuScreen extends StatefulWidget {
  final int? tableId;
  final int? tableNumber;
  final bool isAdditionalOrder;

  const MenuScreen({
    super.key,
    this.tableId,
    this.tableNumber,
    this.isAdditionalOrder = false,
  });

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  int _selectedCategoryId = 1;
  List<FoodItem> _menuRepository = [];
  final Map<FoodItem, int> _orderCart = {};
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  root_menu.FoodItem _toRootFoodItem(FoodItem item) {
    return root_menu.FoodItem(
      itemDbId: item.itemDbId,
      name: item.name,
      price: item.price,
      categoryId: item.categoryId,
      isAvailable: item.isAvailable,
    );
  }

  FoodItem _fromRootFoodItem(root_menu.FoodItem item) {
    return FoodItem(
      itemDbId: item.itemDbId,
      name: item.name,
      price: item.price,
      categoryId: item.categoryId,
      isAvailable: item.isAvailable,
    );
  }

  Map<root_menu.FoodItem, int> get _checkoutCart => _orderCart.map(
    (item, quantity) => MapEntry(_toRootFoodItem(item), quantity),
  );

  int? _chosenTableNumber;
  bool _isTakeoutSelected = false;

  final List<FoodItem> _testSamples = [
    // Category 1: Pancit
    FoodItem(itemDbId: 1, categoryId: 1, name: 'Bihon', price: 165.00),
    FoodItem(itemDbId: 2, categoryId: 1, name: 'Mike Bihon', price: 165.00),
    FoodItem(itemDbId: 3, categoryId: 1, name: 'Canton', price: 175.00),
    FoodItem(itemDbId: 4, categoryId: 1, name: 'Canton-Bihon', price: 175.00),
    FoodItem(
      itemDbId: 5,
      categoryId: 1,
      name: 'Canton-Sotanghon',
      price: 175.00,
    ),
    FoodItem(itemDbId: 6, categoryId: 1, name: 'Lomi', price: 165.00),
    FoodItem(itemDbId: 7, categoryId: 1, name: 'Pancit Ulam', price: 165.00),

    // Category 2: Pasta
    FoodItem(itemDbId: 8, categoryId: 2, name: 'Spaghetti', price: 95.00),
    FoodItem(
      itemDbId: 9,
      categoryId: 2,
      name: 'Spaghetti W/ Chicken',
      price: 145.00,
    ),
    FoodItem(itemDbId: 10, categoryId: 2, name: 'Carbonara', price: 95.00),
    FoodItem(
      itemDbId: 11,
      categoryId: 2,
      name: 'Carbonara W/ Chicken',
      price: 145.00,
    ),
    FoodItem(itemDbId: 12, categoryId: 2, name: 'Baked Mac', price: 170.00),
    FoodItem(itemDbId: 13, categoryId: 2, name: 'Palabok', price: 95.00),
    FoodItem(itemDbId: 14, categoryId: 2, name: 'Lasagna', price: 170.00),
    FoodItem(itemDbId: 142, categoryId: 2, name: 'Toowoomba', price: 179.00),
    FoodItem(
      itemDbId: 143,
      categoryId: 2,
      name: 'Arrabiata Pasta',
      price: 169.00,
    ),
    FoodItem(
      itemDbId: 144,
      categoryId: 2,
      name: 'Italian Meatball Pasta',
      price: 179.00,
    ),
    FoodItem(itemDbId: 145, categoryId: 2, name: 'Junhwa Pasta', price: 189.00),
    FoodItem(
      itemDbId: 146,
      categoryId: 2,
      name: 'Samgyup Cream Pasta',
      price: 179.00,
    ),

    // Category 3: Sandwiches
    FoodItem(
      itemDbId: 15,
      categoryId: 3,
      name: 'Clubhouse W/ Fries',
      price: 135.00,
    ),
    FoodItem(
      itemDbId: 16,
      categoryId: 3,
      name: 'Chicken Fillet Sandwich W/ Fries',
      price: 135.00,
    ),
    FoodItem(itemDbId: 17, categoryId: 3, name: 'Tuna Sandwich', price: 75.00),
    FoodItem(
      itemDbId: 18,
      categoryId: 3,
      name: 'Chicken Sandwich',
      price: 75.00,
    ),
    FoodItem(itemDbId: 19, categoryId: 3, name: 'Cheese Burger', price: 135.00),
    FoodItem(
      itemDbId: 20,
      categoryId: 3,
      name: 'Ham & Cheese Roll',
      price: 95.00,
    ),
    FoodItem(
      itemDbId: 134,
      categoryId: 3,
      name: 'Classic Burger',
      price: 199.00,
    ),

    // Category 4: Chicken Wings
    FoodItem(itemDbId: 21, categoryId: 4, name: 'Plain (Wings)', price: 335.00),
    FoodItem(
      itemDbId: 22,
      categoryId: 4,
      name: 'Buffalo (Wings)',
      price: 385.00,
    ),
    FoodItem(
      itemDbId: 23,
      categoryId: 4,
      name: 'Salted Egg (Wings)',
      price: 385.00,
    ),
    FoodItem(
      itemDbId: 24,
      categoryId: 4,
      name: 'Garlic Butter (Wings)',
      price: 385.00,
    ),
    FoodItem(
      itemDbId: 25,
      categoryId: 4,
      name: 'Garlic Parmesan (Wings)',
      price: 385.00,
    ),
    FoodItem(
      itemDbId: 26,
      categoryId: 4,
      name: 'Honey Glazed (Wings)',
      price: 385.00,
    ),

    // Category 5: Vegetables
    FoodItem(itemDbId: 27, categoryId: 5, name: 'Caesar Salad', price: 185.00),
    FoodItem(itemDbId: 28, categoryId: 5, name: 'Chopsuey', price: 255.00),
    FoodItem(
      itemDbId: 29,
      categoryId: 5,
      name: 'Chopsuey W/ Canton',
      price: 285.00,
    ),
    FoodItem(
      itemDbId: 30,
      categoryId: 5,
      name: 'Buttered Mix Vegetable',
      price: 245.00,
    ),
    FoodItem(
      itemDbId: 31,
      categoryId: 5,
      name: 'Menudong Gulay',
      price: 265.00,
    ),
    FoodItem(
      itemDbId: 32,
      categoryId: 5,
      name: 'Pinakbet W/ Lechon Kawali',
      price: 345.00,
    ),

    // Category 6: Daily Specials
    FoodItem(
      itemDbId: 33,
      categoryId: 6,
      name: 'Kare-Kare (Labot)',
      price: 375.00,
    ),
    FoodItem(
      itemDbId: 34,
      categoryId: 6,
      name: 'Kare-Kare (Liempo)',
      price: 475.00,
    ),
    FoodItem(itemDbId: 35, categoryId: 6, name: 'Tokwa’t Baboy', price: 175.00),
    FoodItem(
      itemDbId: 36,
      categoryId: 6,
      name: 'Sinigang (Baboy)',
      price: 395.00,
    ),
    FoodItem(
      itemDbId: 37,
      categoryId: 6,
      name: 'Sinigang (Hipon)',
      price: 445.00,
    ),
    FoodItem(
      itemDbId: 38,
      categoryId: 6,
      name: 'Sinigang (Salmon Belly)',
      price: 325.00,
    ),
    FoodItem(itemDbId: 39, categoryId: 6, name: 'Bulalo', price: 475.00),
    FoodItem(
      itemDbId: 40,
      categoryId: 6,
      name: 'Sweet & Sour Tilapia',
      price: 225.00,
    ),
    FoodItem(
      itemDbId: 41,
      categoryId: 6,
      name: 'Relyenong Bangus',
      price: 365.00,
    ),
    FoodItem(
      itemDbId: 42,
      categoryId: 6,
      name: 'Daing Na Bangus',
      price: 245.00,
    ),
    FoodItem(itemDbId: 43, categoryId: 6, name: 'Fish Fillet', price: 245.00),
    FoodItem(itemDbId: 44, categoryId: 6, name: 'Crispy Pata', price: 700.00),
    FoodItem(itemDbId: 45, categoryId: 6, name: 'Patatim', price: 750.00),
    FoodItem(itemDbId: 46, categoryId: 6, name: 'Lechon Kawali', price: 475.00),
    FoodItem(
      itemDbId: 47,
      categoryId: 6,
      name: 'Fried Chicken (Whole)',
      price: 445.00,
    ),
    FoodItem(
      itemDbId: 48,
      categoryId: 6,
      name: 'Fried Chicken (Half)',
      price: 295.00,
    ),
    FoodItem(itemDbId: 49, categoryId: 6, name: 'Cordon Bleu', price: 190.00),
    FoodItem(
      itemDbId: 50,
      categoryId: 6,
      name: 'Chicken Fillet',
      price: 265.00,
    ),
    FoodItem(
      itemDbId: 51,
      categoryId: 6,
      name: 'Lumpiang Shanghai',
      price: 230.00,
    ),
    FoodItem(
      itemDbId: 52,
      categoryId: 6,
      name: 'Torta Con Karne',
      price: 205.00,
    ),

    // Category 7: Sizzling
    FoodItem(
      itemDbId: 53,
      categoryId: 7,
      name: 'Sizzling Chicken',
      price: 375.00,
    ),
    FoodItem(
      itemDbId: 54,
      categoryId: 7,
      name: 'Sizzling Pork Sisig',
      price: 250.00,
    ),
    FoodItem(
      itemDbId: 55,
      categoryId: 7,
      name: 'Sizzling Pusit',
      price: 225.00,
    ),
    FoodItem(
      itemDbId: 56,
      categoryId: 7,
      name: 'Sizzling Mixed Seafoods',
      price: 295.00,
    ),
    FoodItem(
      itemDbId: 57,
      categoryId: 7,
      name: 'Sizzling Hungarian Sausage',
      price: 225.00,
    ),

    // Category 8: Pika Pika
    FoodItem(itemDbId: 58, categoryId: 8, name: 'French Fries', price: 115.00),
    FoodItem(itemDbId: 59, categoryId: 8, name: 'Mojos', price: 115.00),
    FoodItem(
      itemDbId: 60,
      categoryId: 8,
      name: 'Crispy Kangkong',
      price: 125.00,
    ),
    FoodItem(itemDbId: 61, categoryId: 8, name: 'Calamares', price: 170.00),
    FoodItem(itemDbId: 62, categoryId: 8, name: 'Nachos', price: 185.00),
    FoodItem(itemDbId: 63, categoryId: 8, name: 'Tofu Square', price: 135.00),
    FoodItem(
      itemDbId: 64,
      categoryId: 8,
      name: 'Shrimp Tempura',
      price: 395.00,
    ),
    FoodItem(
      itemDbId: 135,
      categoryId: 8,
      name: 'Balai Silayan Salad',
      price: 239.00,
    ),
    FoodItem(
      itemDbId: 136,
      categoryId: 8,
      name: 'Chef Lee Salad',
      price: 259.00,
    ),
    FoodItem(
      itemDbId: 137,
      categoryId: 8,
      name: 'Bulgogi Quesadilla',
      price: 219.00,
    ),
    FoodItem(
      itemDbId: 138,
      categoryId: 8,
      name: 'Chicken Quesadilla',
      price: 219.00,
    ),
    FoodItem(
      itemDbId: 139,
      categoryId: 8,
      name: 'Chaofan with Mandu',
      price: 129.00,
    ),
    FoodItem(
      itemDbId: 140,
      categoryId: 8,
      name: 'Rice Topped Korean Curry',
      price: 149.00,
    ),
    FoodItem(
      itemDbId: 141,
      categoryId: 8,
      name: 'Loaded Nachos',
      price: 229.00,
    ),

    // Category 9: Budget Meals W/ Rice
    FoodItem(itemDbId: 65, categoryId: 9, name: 'Tapsilog', price: 145.00),
    FoodItem(itemDbId: 66, categoryId: 9, name: 'Tocilog', price: 145.00),
    FoodItem(itemDbId: 67, categoryId: 9, name: 'Porksilog', price: 145.00),
    FoodItem(itemDbId: 68, categoryId: 9, name: 'Hotsilog', price: 135.00),
    FoodItem(
      itemDbId: 69,
      categoryId: 9,
      name: 'Hungariansilog',
      price: 145.00,
    ),
    FoodItem(itemDbId: 70, categoryId: 9, name: 'Chicksilog', price: 145.00),
    FoodItem(
      itemDbId: 71,
      categoryId: 9,
      name: 'Breaded Pork W/ Rice & Veg.',
      price: 165.00,
    ),
    FoodItem(
      itemDbId: 72,
      categoryId: 9,
      name: 'Chicken Fillet W/ Rice',
      price: 155.00,
    ),
    FoodItem(
      itemDbId: 73,
      categoryId: 9,
      name: 'Fish Fillet W/ Rice & Veg.',
      price: 165.00,
    ),
    FoodItem(
      itemDbId: 74,
      categoryId: 9,
      name: 'Chicken Adobo W/ Egg',
      price: 145.00,
    ),
    FoodItem(
      itemDbId: 75,
      categoryId: 9,
      name: 'Pork Adobo W/ Egg',
      price: 165.00,
    ),
    FoodItem(
      itemDbId: 76,
      categoryId: 9,
      name: 'Burger Steak W/ Rice',
      price: 165.00,
    ),

    // Category 10: Pizza
    FoodItem(
      itemDbId: 77,
      categoryId: 10,
      name: 'Super Supreme',
      price: 335.00,
    ),
    FoodItem(
      itemDbId: 78,
      categoryId: 10,
      name: 'Bulgogi Pizza',
      price: 300.00,
    ),
    FoodItem(itemDbId: 79, categoryId: 10, name: 'Sisig Pizza', price: 250.00),
    FoodItem(
      itemDbId: 80,
      categoryId: 10,
      name: 'Ham N’ Cheese',
      price: 200.00,
    ),
    FoodItem(itemDbId: 81, categoryId: 10, name: 'Hawaiian', price: 200.00),
    FoodItem(itemDbId: 82, categoryId: 10, name: 'Pepperoni', price: 200.00),
    FoodItem(
      itemDbId: 83,
      categoryId: 10,
      name: 'Bacon N’ Mushroom',
      price: 200.00,
    ),

    // Category 11: Drinks
    FoodItem(itemDbId: 84, categoryId: 11, name: 'Bottled Water', price: 25.00),
    FoodItem(
      itemDbId: 85,
      categoryId: 11,
      name: 'Mango Juice in Can',
      price: 75.00,
    ),
    FoodItem(
      itemDbId: 86,
      categoryId: 11,
      name: 'Pineapple Juice in Can',
      price: 75.00,
    ),
    FoodItem(
      itemDbId: 87,
      categoryId: 11,
      name: 'Orange Juice in Can',
      price: 75.00,
    ),
    FoodItem(
      itemDbId: 88,
      categoryId: 11,
      name: 'Four Seasons in Can',
      price: 75.00,
    ),
    FoodItem(
      itemDbId: 89,
      categoryId: 11,
      name: 'Iced Tea (Solo)',
      price: 50.00,
    ),
    FoodItem(
      itemDbId: 90,
      categoryId: 11,
      name: 'Iced Tea (Pitcher)',
      price: 150.00,
    ),
    FoodItem(
      itemDbId: 91,
      categoryId: 11,
      name: 'Blue Lemonade (Solo)',
      price: 50.00,
    ),
    FoodItem(
      itemDbId: 92,
      categoryId: 11,
      name: 'Blue Lemonade (Pitcher)',
      price: 150.00,
    ),
    FoodItem(
      itemDbId: 93,
      categoryId: 11,
      name: 'Cucumber (Solo)',
      price: 50.00,
    ),
    FoodItem(
      itemDbId: 94,
      categoryId: 11,
      name: 'Cucumber (Pitcher)',
      price: 150.00,
    ),
    FoodItem(itemDbId: 95, categoryId: 11, name: 'Coke (Mismo)', price: 30.00),
    FoodItem(
      itemDbId: 96,
      categoryId: 11,
      name: 'Coke (1.5 Litro)',
      price: 110.00,
    ),
    FoodItem(itemDbId: 97, categoryId: 11, name: 'Royal (Mismo)', price: 30.00),
    FoodItem(
      itemDbId: 98,
      categoryId: 11,
      name: 'Royal (1.5 Litro)',
      price: 110.00,
    ),
    FoodItem(
      itemDbId: 99,
      categoryId: 11,
      name: 'Sprite (Mismo)',
      price: 30.00,
    ),
    FoodItem(
      itemDbId: 100,
      categoryId: 11,
      name: 'Sprite (1.5 Litro)',
      price: 110.00,
    ),
    FoodItem(
      itemDbId: 101,
      categoryId: 11,
      name: 'San Mig Pale Pilsen',
      price: 65.00,
    ),
    FoodItem(
      itemDbId: 102,
      categoryId: 11,
      name: 'San Mig Light',
      price: 65.00,
    ),
    FoodItem(
      itemDbId: 103,
      categoryId: 11,
      name: 'San Mig Apple',
      price: 65.00,
    ),
    FoodItem(itemDbId: 104, categoryId: 11, name: 'Grande', price: 150.00),
    FoodItem(itemDbId: 105, categoryId: 11, name: 'Mucho', price: 150.00),

    // Category 12: Rice
    FoodItem(
      itemDbId: 106,
      categoryId: 12,
      name: 'Plain Rice (Solo)',
      price: 25.00,
    ),
    FoodItem(
      itemDbId: 107,
      categoryId: 12,
      name: 'Plain Rice (Bowl)',
      price: 100.00,
    ),
    FoodItem(
      itemDbId: 108,
      categoryId: 12,
      name: 'Fried Rice (Solo)',
      price: 35.00,
    ),
    FoodItem(
      itemDbId: 109,
      categoryId: 12,
      name: 'Fried Rice (Bowl)',
      price: 150.00,
    ),
    FoodItem(
      itemDbId: 110,
      categoryId: 12,
      name: 'Shanghai Rice (Solo)',
      price: 40.00,
    ),
    FoodItem(
      itemDbId: 111,
      categoryId: 12,
      name: 'Shanghai Rice (Bowl)',
      price: 160.00,
    ),
    FoodItem(
      itemDbId: 112,
      categoryId: 12,
      name: 'Java Rice (Solo)',
      price: 40.00,
    ),
    FoodItem(
      itemDbId: 113,
      categoryId: 12,
      name: 'Java Rice (Bowl)',
      price: 160.00,
    ),

    // Category 13: Desserts
    FoodItem(itemDbId: 114, categoryId: 13, name: 'Halo-Halo', price: 80.00),
    FoodItem(
      itemDbId: 115,
      categoryId: 13,
      name: 'Korean Ice Cream',
      price: 50.00,
    ),
    FoodItem(itemDbId: 116, categoryId: 13, name: 'Leche Flan', price: 95.00),
    FoodItem(
      itemDbId: 149,
      categoryId: 13,
      name: 'Samanco - Red Bean',
      price: 85.00,
    ),
    FoodItem(
      itemDbId: 150,
      categoryId: 13,
      name: 'Samanco - Chocolate',
      price: 85.00,
    ),
    FoodItem(
      itemDbId: 151,
      categoryId: 13,
      name: 'Samanco - Strawberry',
      price: 85.00,
    ),
    FoodItem(
      itemDbId: 152,
      categoryId: 13,
      name: 'Samanco - Matcha',
      price: 85.00,
    ),

    // Category 14: Korean Menu
    FoodItem(itemDbId: 117, categoryId: 14, name: 'Bibimbap', price: 180.00),
    FoodItem(
      itemDbId: 118,
      categoryId: 14,
      name: 'Jjajangmyeon',
      price: 240.00,
    ),
    FoodItem(itemDbId: 119, categoryId: 14, name: 'Tangsuyuk', price: 275.00),
    FoodItem(itemDbId: 120, categoryId: 14, name: 'Kangpunggu', price: 275.00),
    FoodItem(itemDbId: 121, categoryId: 14, name: 'Dakgangjung', price: 275.00),
    FoodItem(
      itemDbId: 122,
      categoryId: 14,
      name: 'Kimchi Bokumbap',
      price: 100.00,
    ),
    FoodItem(itemDbId: 123, categoryId: 14, name: 'Mandu', price: 135.00),
    FoodItem(itemDbId: 124, categoryId: 14, name: 'Kimbap', price: 150.00),
    FoodItem(
      itemDbId: 125,
      categoryId: 14,
      name: 'Kimchi (Tub)',
      price: 200.00,
    ),
    FoodItem(
      itemDbId: 126,
      categoryId: 14,
      name: 'Dakgalbi W/ Cheese',
      price: 335.00,
    ),
    FoodItem(itemDbId: 127, categoryId: 14, name: 'Yaki Udon', price: 180.00),
    FoodItem(itemDbId: 128, categoryId: 14, name: 'Tteokbokki', price: 210.00),
    FoodItem(itemDbId: 129, categoryId: 14, name: 'Rabokki', price: 245.00),
    FoodItem(itemDbId: 130, categoryId: 14, name: 'Japchae', price: 185.00),
    FoodItem(
      itemDbId: 131,
      categoryId: 14,
      name: 'Bulgogi (Korean)',
      price: 275.00,
    ),
    FoodItem(itemDbId: 132, categoryId: 14, name: 'Ramyeon', price: 90.00),
    FoodItem(itemDbId: 133, categoryId: 14, name: 'Bossam', price: 475.00),
    FoodItem(itemDbId: 147, categoryId: 14, name: 'Eomuk-Udon', price: 280.00),
    FoodItem(
      itemDbId: 148,
      categoryId: 14,
      name: 'Tonkotsu Pork Ramen',
      price: 280.00,
    ),
  ];

  final List<MenuCategory> _categoriesFallback = [
    MenuCategory(id: 1, name: "Pancit"),
    MenuCategory(id: 2, name: "Pasta"),
    MenuCategory(id: 3, name: "Sandwiches"),
    MenuCategory(id: 4, name: "Chicken Wings"),
    MenuCategory(id: 5, name: "Vegetables"),
    MenuCategory(id: 6, name: "Daily Specials"),
    MenuCategory(id: 7, name: "Sizzling"),
    MenuCategory(id: 8, name: "Pika Pika"),
    MenuCategory(id: 9, name: "Budget Meals W/ Rice"),
    MenuCategory(id: 10, name: "Pizza"),
    MenuCategory(id: 11, name: "Drinks"),
    MenuCategory(id: 12, name: "Rice"),
    MenuCategory(id: 13, name: "Desserts"),
    MenuCategory(id: 14, name: "Korean Menu"),
    MenuCategory(id: 15, name: "Burgers"),
    MenuCategory(id: 16, name: "New Menu"),
    MenuCategory(id: 17, name: "Italian"),
  ];

  List<MenuCategory> _categoriesList = [];

  @override
  void initState() {
    super.initState();
    if (widget.tableNumber != null) {
      _chosenTableNumber = widget.tableNumber;
      UserSession.activeTableNumber = widget.tableNumber;
    } else if (widget.tableId != null) {
      _chosenTableNumber = widget.tableId;
      UserSession.activeTableId = widget.tableId;
    } else if (UserSession.activeTableNumber != null) {
      _chosenTableNumber = UserSession.activeTableNumber;
    } else if (UserSession.activeTableId != null) {
      _chosenTableNumber = UserSession.activeTableId;
    }
    _fetchCategoriesFromBackend();
    _fetchLiveDatabaseMenu();
  }

  Future<void> _fetchCategoriesFromBackend() async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:5000/api/v1/categories'),
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> decodedData = jsonDecode(response.body);
        final List list = decodedData['data'] ?? [];
        if (list.isNotEmpty && mounted) {
          setState(() {
            _categoriesList = list
                .map((item) => MenuCategory.fromJson(item))
                .toList();
          });
          return;
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _categoriesList = _categoriesFallback;
      });
    }
  }

  Future<void> _fetchLiveDatabaseMenu() async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:5000/api/v1/menu'),
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> decodedData = jsonDecode(response.body);
        final List menuList = decodedData['data'] ?? [];
        setState(() {
          _menuRepository = menuList
              .map((item) => FoodItem.fromJson(item))
              .toList();
          _isLoading = false;
        });
      } else {
        _loadFallbackSamples();
      }
    } catch (e) {
      _loadFallbackSamples();
    }
  }

  void _loadFallbackSamples() {
    setState(() {
      _menuRepository = _testSamples;
      _isLoading = false;
    });
  }

  void _modifyQuantity(FoodItem item, int variance) {
    setState(() {
      int activeQty = _orderCart[item] ?? 0;
      if (activeQty + variance <= 0) {
        _orderCart.remove(item);
      } else {
        _orderCart[item] = activeQty + variance;
      }
    });
  }

  double get _cartGrandTotal => _orderCart.entries.fold(
    0.0,
    (total, entry) => total + (entry.key.price * entry.value),
  );

  Future<List<Map<String, dynamic>>> _fetchTableStatuses() async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:5000/api/v1/tables'),
      );
      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        final List<dynamic> list = resData['data'] ?? [];
        return List<Map<String, dynamic>>.from(list);
      }
    } catch (_) {}
    return List.generate(
      20,
      (i) => {'table_number': i + 1, 'status': 'AVAILABLE'},
    );
  }

  void _promptDiningChoiceContext(BuildContext context) async {
    final List<Map<String, dynamic>> tableStatuses =
        await _fetchTableStatuses();

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      builder: (numCtx) {
        return StatefulBuilder(
          builder: (numCtx, setModalState) {
            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 20,
              ).copyWith(bottom: MediaQuery.of(numCtx).viewInsets.bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Select Your Dining Style',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF203F35),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(
                            Icons.qr_code_scanner,
                            color: Color(0xFF203F35),
                          ),
                          label: const Text('Scan Table QR Code'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF203F35),
                            backgroundColor: const Color(0xFFEEE7D9),
                            side: const BorderSide(color: Color(0xFFE5DFD3)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(numCtx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const QrScannerScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(
                            Icons.restaurant,
                            color: Color(0xFF203F35),
                          ),
                          label: const Text('Order Type'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF203F35),
                            backgroundColor: const Color(0xFFFFFDFA),
                            side: const BorderSide(color: Color(0xFFE5DFD3)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(numCtx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => OrderTypeSelectionScreen(
                                  tableNumber: _chosenTableNumber ?? 7,
                                  tableId: _chosenTableNumber ?? 7,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.shopping_bag_outlined),
                          label: const Text('Takeout / To-Go'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _isTakeoutSelected
                                ? Colors.white
                                : const Color(0xFF788078),
                            backgroundColor: _isTakeoutSelected
                                ? const Color(0xFF203F35)
                                : Colors.white,
                            side: BorderSide(
                              color: _isTakeoutSelected
                                  ? const Color(0xFF203F35)
                                  : const Color(0xFFE5DFD3),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            setModalState(() {
                              _isTakeoutSelected = true;
                              _chosenTableNumber = null;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Or choose an available table:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF788078),
                          fontSize: 13,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF22C55E),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Available',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF22C55E),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFFD63031),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Occupied',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFFD63031),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 95,
                    child: ScrollConfiguration(
                      behavior: ScrollConfiguration.of(context).copyWith(
                        dragDevices: {
                          PointerDeviceKind.touch,
                          PointerDeviceKind.mouse,
                          PointerDeviceKind.trackpad,
                        },
                      ),
                      child: Scrollbar(
                        thumbVisibility: true,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.only(bottom: 8),
                          itemCount: tableStatuses.isNotEmpty
                              ? tableStatuses.length
                              : 20,
                          itemBuilder: (context, idx) {
                            final tableData = (tableStatuses.length > idx)
                                ? tableStatuses[idx]
                                : {
                                    'table_number': idx + 1,
                                    'status': 'AVAILABLE',
                                  };
                            final int tableNum =
                                tableData['table_number'] ?? (idx + 1);
                            final bool isOccupied =
                                (tableData['status'] ?? 'AVAILABLE')
                                    .toString()
                                    .toUpperCase() ==
                                'OCCUPIED';
                            final isSelected =
                                _chosenTableNumber == tableNum &&
                                !_isTakeoutSelected;

                            Color cardBg = isSelected
                                ? const Color(0xFF203F35)
                                : (isOccupied
                                      ? const Color(0xFFFFF0F2)
                                      : Colors.white);
                            Color borderColor = isSelected
                                ? const Color(0xFF203F35)
                                : (isOccupied
                                      ? const Color(0xFFFF7675)
                                      : const Color(0xFF22C55E));
                            Color textColor = isSelected
                                ? Colors.white
                                : (isOccupied
                                      ? const Color(0xFFD63031)
                                      : const Color(0xFF203F35));
                            Color iconColor = isSelected
                                ? Colors.white
                                : (isOccupied
                                      ? const Color(0xFFD63031)
                                      : const Color(0xFF22C55E));

                            return Padding(
                              padding: const EdgeInsets.only(
                                right: 8.0,
                                bottom: 4,
                              ),
                              child: InkWell(
                                onTap: () {
                                  if (isOccupied) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Table #$tableNum is currently occupied by dining guests.',
                                        ),
                                        backgroundColor: const Color(
                                          0xFFD63031,
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  setModalState(() {
                                    _chosenTableNumber = tableNum;
                                    _isTakeoutSelected = false;
                                  });
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  width: 80,
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: borderColor,
                                      width: isOccupied || isSelected
                                          ? 1.5
                                          : 1.0,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.table_restaurant_outlined,
                                        color: iconColor,
                                        size: 18,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Table $tableNum',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: textColor,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isOccupied ? 'BUSY' : 'FREE',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          color: textColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
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
                      onPressed: () {
                        if (!_isTakeoutSelected && _chosenTableNumber == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please select an available table or Choose Takeout.',
                              ),
                            ),
                          );
                          return;
                        }
                        Navigator.pop(numCtx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CheckoutScreen(
                              cart: _checkoutCart,
                              total: _cartGrandTotal,
                              tableId: _chosenTableNumber,
                              isTakeout: _isTakeoutSelected,
                            ),
                          ),
                        );
                      },
                      child: const Text(
                        'Confirm and Continue',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeCategories = _categoriesList.isNotEmpty
        ? _categoriesList
        : _categoriesFallback;
    final currentCategoryName = activeCategories
        .firstWhere(
          (c) => c.id == _selectedCategoryId,
          orElse: () => activeCategories.first,
        )
        .name;

    final filteredItems = _menuRepository.where((item) {
      final matchesCategory = item.categoryId == _selectedCategoryId;
      final matchesSearch =
          _searchQuery.isEmpty ||
          item.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F4EC),
      body: SafeArea(
        child: Column(
          children: [
            _buildRestaurantHeader(),
            _buildTableContextStrip(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF203F35),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildIntroductionHeader(),
                          const SizedBox(height: 16),
                          _buildSearchBar(),
                          const SizedBox(height: 20),
                          _buildCategorySelector(),
                          const SizedBox(height: 24),
                          _buildSectionHeader(
                            currentCategoryName,
                            filteredItems.length,
                          ),
                          const SizedBox(height: 16),
                          _buildFoodGrid(filteredItems, isDesktop ? 4 : 2),
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
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => OrderTypeSelectionScreen(
                    tableNumber: _chosenTableNumber ?? 7,
                    tableId: _chosenTableNumber ?? 7,
                  ),
                ),
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
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.qr_code_scanner,
                  color: Color(0xFF203F35),
                  size: 22,
                ),
                tooltip: 'Scan Table QR',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const QrScannerScreen(),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.point_of_sale_outlined,
                  color: Color(0xFF203F35),
                  size: 22,
                ),
                tooltip: 'Cashier Station',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const OrdersScreen(cartItems: []),
                  ),
                ),
              ),
              InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AssistanceScreen(),
                  ),
                ),
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
          ),
        ],
      ),
    );
  }

  Widget _buildTableContextStrip() {
    final String tableLabel = _isTakeoutSelected
        ? 'Takeout / To-Go'
        : (_chosenTableNumber != null
              ? 'Table ${_chosenTableNumber.toString().padLeft(2, '0')} • verified'
              : 'Table 07 • verified');
    final String stateLabel = _isTakeoutSelected ? 'Takeout' : 'Dine-in';

    return InkWell(
      onTap: () => _promptDiningChoiceContext(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        color: const Color(0xFFEEE7D9),
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
                  tableLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    color: Color(0xFF203F35),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  stateLabel,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF788078),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.edit_outlined,
                  size: 12,
                  color: Color(0xFF788078),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroductionHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "OUR MENU",
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFFA47C3D),
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Heritage Selections',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF203F35),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDFA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5DFD3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 18, color: Color(0xFF788078)),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: const InputDecoration(
                hintText: 'Search menu items...',
                hintStyle: TextStyle(color: Color(0xFF788078), fontSize: 13),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              child: const Icon(
                Icons.close,
                size: 16,
                color: Color(0xFF788078),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    final activeCategories = _categoriesList.isNotEmpty
        ? _categoriesList
        : _categoriesFallback;
    final ScrollController categoryScrollController = ScrollController();

    return SizedBox(
      height: 44,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
          },
        ),
        child: ListView.builder(
          controller: categoryScrollController,
          scrollDirection: Axis.horizontal,
          itemCount: activeCategories.length,
          itemBuilder: (context, index) {
            final category = activeCategories[index];
            final bool isSelected = _selectedCategoryId == category.id;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ChoiceChip(
                label: Text(category.name),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedCategoryId = category.id);
                  }
                },
                selectedColor: const Color(0xFF203F35),
                backgroundColor: const Color(0xFFFFFDFA),
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                  color: isSelected ? Colors.white : const Color(0xFF788078),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
                side: BorderSide(
                  color: isSelected
                      ? const Color(0xFF203F35)
                      : const Color(0xFFE5DFD3),
                ),
                showCheckmark: false,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF203F35),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFEEE7D9),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            '$count Items',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFFA47C3D),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFoodGrid(List<FoodItem> items, int columns) {
    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Text(
            'No items match your selection.',
            style: TextStyle(color: Color(0xFF788078)),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.62,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final foodItem = items[index];
        final productCount = _orderCart[foodItem] ?? 0;
        final bool available = foodItem.isAvailable;

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FoodDetailsScreen(
                  foodItem: _toRootFoodItem(foodItem),
                  tableId: _chosenTableNumber,
                  isTakeout: _isTakeoutSelected,
                  onAddToCart: (item, qty, addOns) {
                    _modifyQuantity(_fromRootFoodItem(item), qty);
                  },
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(18),
          child: Container(
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
                Container(
                  height: 118,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEEE7D9),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(18),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _getCategoryIcon(foodItem.categoryId),
                              size: 36,
                              color: const Color(0xFF203F35),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              foodItem.name.substring(0, 1),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFA47C3D),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              foodItem.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF24382F),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _getCategoryName(foodItem.categoryId),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF788078),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              available ? 'In Stock' : 'Sold Out',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: available
                                    ? const Color(0xFF53766C)
                                    : const Color(0xFF8E5136),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '₱${foodItem.price.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF203F35),
                              ),
                            ),
                            !available
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD9DBD3),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      'Off',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF788078),
                                      ),
                                    ),
                                  )
                                : productCount == 0
                                ? InkWell(
                                    onTap: () => _modifyQuantity(foodItem, 1),
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF203F35),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Text(
                                        'Add',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  )
                                : Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF203F35),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        InkWell(
                                          onTap: () =>
                                              _modifyQuantity(foodItem, -1),
                                          child: const Padding(
                                            padding: EdgeInsets.all(4.0),
                                            child: Icon(
                                              Icons.remove,
                                              size: 14,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '$productCount',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                        InkWell(
                                          onTap: () =>
                                              _modifyQuantity(foodItem, 1),
                                          child: const Padding(
                                            padding: EdgeInsets.all(4.0),
                                            child: Icon(
                                              Icons.add,
                                              size: 14,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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

  String _getCategoryName(int catId) {
    final match = _categoriesFallback.firstWhere(
      (c) => c.id == catId,
      orElse: () => MenuCategory(id: catId, name: 'Specialty'),
    );
    return match.name;
  }

  Widget _buildCustomerBottomNav() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_orderCart.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            color: const Color(0xFFEEE7D9),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF203F35),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ShoppingCartScreen(
                        cart: _checkoutCart,
                        total: _cartGrandTotal,
                        tableId: _chosenTableNumber,
                        isTakeout: _isTakeoutSelected,
                      ),
                    ),
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'View Cart (${_orderCart.values.fold(0, (sum, q) => sum + q)} items)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '₱${_cartGrandTotal.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.arrow_forward,
                          color: Colors.white,
                          size: 16,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        Container(
          height: 70,
          decoration: const BoxDecoration(
            color: Color(0xFFFFFDFA),
            border: Border(top: BorderSide(color: Color(0xFFE5DFD3))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                Icons.restaurant,
                'Menu',
                isActive: true,
                onTap: () {},
              ),
              _buildNavItem(
                Icons.shopping_bag_outlined,
                'Cart',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ShoppingCartScreen(
                        cart: _checkoutCart,
                        total: _cartGrandTotal,
                        tableId: _chosenTableNumber,
                        isTakeout: _isTakeoutSelected,
                      ),
                    ),
                  );
                },
              ),
              _buildNavItem(
                Icons.receipt_long_outlined,
                'Orders',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OrderStatusScreen(
                        orderId: 1042,
                        isTakeout: _isTakeoutSelected,
                        tableId: _chosenTableNumber,
                      ),
                    ),
                  );
                },
              ),
              _buildNavItem(
                Icons.notifications_none,
                'Help',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AssistanceScreen(),
                    ),
                  );
                },
              ),
              _buildNavItem(
                Icons.account_balance_wallet_outlined,
                'Pay',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SessionBillScreen(
                        tableId: _chosenTableNumber,
                        isTakeout: _isTakeoutSelected,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNavItem(
    IconData icon,
    String label, {
    bool isActive = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 20,
            color: isActive ? const Color(0xFF203F35) : const Color(0xFF788078),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive
                  ? const Color(0xFF203F35)
                  : const Color(0xFF788078),
            ),
          ),
          if (isActive) ...[
            const SizedBox(height: 2),
            Container(
              width: 16,
              height: 2,
              decoration: BoxDecoration(
                color: const Color(0xFFA47C3D),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
