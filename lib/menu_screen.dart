import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'dart:convert';
import 'dart:async';
import 'orders_screen.dart';
import 'order_status_screen.dart';
import 'shopping_cart_screen.dart';
import 'food_details_screen.dart';
import 'qr_scanner_screen.dart';
import 'order_type_selection_screen.dart';
import 'session_bill_screen.dart';
import 'admin_dashboard_screen.dart';
import 'user_session.dart';
import 'services/audio_notification_service.dart';
import 'services/socket_service.dart';
import 'config/api_config.dart';

class FoodItem {
  final int itemDbId;
  final String name;
  final double price;
  final int categoryId;
  final bool isAvailable;
  final String? imageUrl;

  static final Map<int, String> hardcodedImageUrls = {
    1: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c',
    2: 'https://images.unsplash.com/photo-1612929633738-8fe44f7ec841',
    3: 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38',
    4: 'https://images.unsplash.com/photo-1552611052-33e04de081de',
    5: 'https://images.unsplash.com/photo-1621996346565-e3d5d6281222',
    6: 'https://images.unsplash.com/photo-1633964913295-ceb43826e7c9',
    7: 'https://images.unsplash.com/photo-1543339308-43e59d6b73a6',
    8: 'https://images.unsplash.com/photo-1528735602780-2552fd46c7af',
    9: 'https://images.unsplash.com/photo-1550547660-d9450f859349',
    10: 'https://images.unsplash.com/photo-1539252554453-80ab65ce3586',
    11: 'https://images.unsplash.com/photo-1567620832903-9fc6debc209f',
    12: 'https://images.unsplash.com/photo-1608039829572-78524f79c4c7',
    13: 'https://images.unsplash.com/photo-1527477396000-e27163b481c2',
    14: 'https://images.unsplash.com/photo-1540420773420-3366772f4999',
    15: 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd',
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
    String safeImg = hardcodedImageUrls[id] ?? 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624';

    return FoodItem(
      itemDbId: id,
      name: json['name'] ?? 'Delicious Dish',
      price: double.tryParse(json['price']?.toString() ?? '0.0') ?? 0.0,
      categoryId: json['category_id'] ?? 1,
      isAvailable: json['is_available'] ?? true,
      imageUrl: safeImg,
    );
  }
}

class MenuCategory {
  final int id;
  final String name;

  MenuCategory({required this.id, required this.name});

  factory MenuCategory.fromJson(Map<String, dynamic> json) {
    return MenuCategory(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Category',
    );
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
  int _selectedCategoryId = 0;
  List<FoodItem> _menuRepository = [];
  final Map<FoodItem, int> _orderCart = {};
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  String get _baseUrl => ApiConfig.baseUrl;

  int? _chosenTableNumber;
  bool _isTakeoutSelected = false;

  final List<FoodItem> _testSamples = [
    FoodItem(itemDbId: 1, categoryId: 1, name: 'Bihon', price: 165.00),
    FoodItem(itemDbId: 2, categoryId: 1, name: 'Mike Bihon', price: 165.00),
    FoodItem(itemDbId: 3, categoryId: 1, name: 'Canton', price: 175.00),
    FoodItem(itemDbId: 8, categoryId: 2, name: 'Spaghetti', price: 95.00),
  ];

  final List<MenuCategory> _categoriesFallback = [
    MenuCategory(id: 0, name: "All Orders"),
    MenuCategory(id: 1, name: "Pancit"),
    MenuCategory(id: 2, name: "Pasta"),
    MenuCategory(id: 3, name: "Sandwiches"),
  ];

  List<MenuCategory> _categoriesList = [];
  Timer? _heartbeatTimer;
  late io.Socket _menuSocket;
  bool _dialogShown = false;

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

    UserSession.isAdditionalOrder = widget.isAdditionalOrder;
    if (!widget.isAdditionalOrder) {
      UserSession.targetParentOrderId = null;
      UserSession.lastPlacedOrderId = null;
    }

    _fetchDatabaseCategories();
    _fetchLiveDatabaseMenu();
    _syncExistingOrdersForTable();
    _startHeartbeatTimer();
    _connectMenuSocket();
  }

  void _connectMenuSocket() {
    try {
      _menuSocket = io.io(
        _baseUrl,
        io.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .enableAutoConnect()
            .build(),
      );

      _menuSocket.onConnect((_) {
        final int? tableId = _chosenTableNumber ?? UserSession.activeTableId ?? UserSession.activeTableNumber;
        if (tableId != null) {
          _menuSocket.emit('join_room', 'table_$tableId');
        }
        final int? sessionId = UserSession.activeSessionId ?? int.tryParse(UserSession.sessionId ?? '');
        if (sessionId != null) {
          _menuSocket.emit('join_room', 'session_$sessionId');
        }
      });

      _menuSocket.on('order_paid', _handleTableOrderFinished);
      _menuSocket.on('table_session_closed', _handleTableOrderFinished);
      _menuSocket.on('session_cancelled', _handleTableOrderFinished);
      _menuSocket.on('order_status_updated', _handleTableOrderEvent);
      _menuSocket.on('order_updated', _handleTableOrderEvent);
      _menuSocket.connect();
    } catch (_) {}
  }

  void _handleTableOrderEvent(dynamic data) {
    if (!mounted) return;
    if (data == null) return;

    final Map<String, dynamic> payload = data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data as Map);
    final Map<String, dynamic> orderPayload = payload['order'] is Map ? Map<String, dynamic>.from(payload['order']) : payload;

    final int currentTable = _chosenTableNumber ?? UserSession.activeTableId ?? UserSession.activeTableNumber ?? 7;
    final int? eventTableId = int.tryParse(orderPayload['table_id']?.toString() ?? orderPayload['table_number']?.toString() ?? payload['table_id']?.toString() ?? '');

    if (eventTableId != null && eventTableId != currentTable) {
      return;
    }

    final String status = (orderPayload['status'] ?? orderPayload['order_status'] ?? payload['status'] ?? payload['order_status'] ?? '').toString().toUpperCase();
    final dynamic eventOrderId = orderPayload['order_id'] ?? orderPayload['id'] ?? payload['order_id'] ?? payload['id'];
    final dynamic currentOrderId = UserSession.lastPlacedOrderId ?? UserSession.targetParentOrderId ?? UserSession.firstOrderId;

    if (eventOrderId != null && currentOrderId != null) {
      if (!SocketService.isSameOrder(eventOrderId, currentOrderId)) {
        return;
      }
    }

    final String orderCode = orderPayload['order_code']?.toString() ?? '#BS-${eventOrderId ?? ""}';

    if (status == 'COMPLETED' || status == 'PAID' || status == 'CLOSED' || status == 'SETTLED') {
      AudioNotificationService.showAggressiveBanner(
        context: context,
        title: "$orderCode: Payment Completed",
        message: "Your order session has been settled.",
        backgroundColor: const Color(0xFF10B981),
        icon: Icons.check_circle,
      );
      _handleTableOrderFinished(payload);
    } else if (status == 'DECLINED' || status == 'REJECTED') {
      final String reason = (orderPayload['decline_reason'] ?? orderPayload['reason'] ?? payload['decline_reason'] ?? payload['reason'] ?? 'Item Out of Stock').toString();
      AudioNotificationService.showAggressiveBanner(
        context: context,
        title: "$orderCode: Order Status: DECLINED",
        message: "Reason: $reason",
        backgroundColor: const Color(0xFFEF4444),
        icon: Icons.cancel,
      );
    } else if (status == 'PREPARING' || status == 'READY' || status == 'SERVED') {
      AudioNotificationService.showAggressiveBanner(
        context: context,
        title: "Order Status: $status",
        message: "Tap 'Live Status' or view tracking for details.",
        backgroundColor: const Color(0xFF203F35),
        icon: Icons.restaurant_menu,
      );
    }
  }

  void _handleTableOrderFinished(dynamic data) {
    if (!mounted) return;
    final int currentTable = _chosenTableNumber ?? UserSession.activeTableId ?? UserSession.activeTableNumber ?? 7;
    if (_dialogShown) return;
    _dialogShown = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFFDFA),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Order Finished', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF203F35))),
        content: const Text('Your order session is done and has been settled.'),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF203F35)),
            onPressed: () {
              Navigator.pop(ctx);
              UserSession.clearSession();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => OrderTypeSelectionScreen(
                    tableId: currentTable,
                    tableNumber: currentTable,
                  ),
                ),
                (route) => false,
              );
            },
            child: const Text('Back to Selection', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _startHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      final sessionId = UserSession.activeSessionId ?? int.tryParse(UserSession.sessionId ?? '');
      final token = UserSession.activeSessionToken;
      if (sessionId == null) return;
      try {
        final Map<String, String> headers = {"Content-Type": "application/json"};
        if (token != null && token.isNotEmpty) headers["Authorization"] = "Bearer $token";
        await http.post(Uri.parse('$_baseUrl/api/v1/customer/sessions/$sessionId/activity'), headers: headers);
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _searchController.dispose();
    try {
      _menuSocket.disconnect();
      _menuSocket.dispose();
    } catch (_) {}
    super.dispose();
  }

  Map<String, String> get _authHeaders {
    final token = UserSession.activeSessionToken;
    final Map<String, String> headers = {"Content-Type": "application/json"};
    if (token != null && token.isNotEmpty) headers["Authorization"] = "Bearer $token";
    return headers;
  }

  Future<void> _fetchDatabaseCategories() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/v1/categories'), headers: _authHeaders);
      if (response.statusCode == 200) {
        final Map<String, dynamic> decodedData = jsonDecode(response.body);
        final List catList = decodedData['data'] ?? [];
        final fetchedCategories = catList.map((cat) => MenuCategory.fromJson(cat)).toList();
        fetchedCategories.insert(0, MenuCategory(id: 0, name: "All Orders"));
        if (mounted) setState(() => _categoriesList = fetchedCategories);
      } else {
        if (mounted) setState(() => _categoriesList = _categoriesFallback);
      }
    } catch (_) {
      if (mounted) setState(() => _categoriesList = _categoriesFallback);
    }
  }

  Future<void> _syncExistingOrdersForTable() async {
    final int tableId = _chosenTableNumber ?? 7;
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/v1/orders/unfinished?table_id=$tableId'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List ordersList = data['orders'] ?? data['data'] ?? [];
        if (ordersList.isNotEmpty) {
          final firstOrder = ordersList.first;
          final rawSessionId = firstOrder['session_id'];
          if (rawSessionId != null) {
            UserSession.activeSessionId = int.tryParse(rawSessionId.toString());
            UserSession.sessionId = rawSessionId.toString();
          }
        }
      }
    } catch (_) {}
    if (_categoriesList.isEmpty && mounted) setState(() => _categoriesList = _categoriesFallback);
  }

  Future<void> _fetchLiveDatabaseMenu() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/v1/customer/menu'));
      if (response.statusCode == 200) {
        final Map<String, dynamic> decodedData = jsonDecode(response.body);
        final List menuList = decodedData['data'] ?? [];
        if (mounted && menuList.isNotEmpty) {
          setState(() {
            _menuRepository = menuList.map((item) => FoodItem.fromJson(item)).toList();
            _isLoading = false;
          });
          return;
        }
      }
      _loadFallbackSamples();
    } catch (_) {
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

  double get _cartGrandTotal => _orderCart.entries.fold(0.0, (total, entry) => total + (entry.key.price * entry.value));

  @override
  Widget build(BuildContext context) {
    final activeCategories = _categoriesList.isNotEmpty ? _categoriesList : _categoriesFallback;
    final currentCategoryName = activeCategories.firstWhere((c) => c.id == _selectedCategoryId, orElse: () => activeCategories.first).name;

    final filteredItems = _menuRepository.where((item) {
      final matchesCategory = _selectedCategoryId == 0 || item.categoryId == _selectedCategoryId;
      final matchesSearch = _searchQuery.isEmpty || item.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F4EC),
      body: SafeArea(
        child: Column(
          children: [
            _buildRestaurantHeader(),
            _buildTableContextStrip(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF203F35)))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildIntroductionHeader(),
                          const SizedBox(height: 16),
                          _buildSearchBar(),
                          const SizedBox(height: 20),
                          _buildCategorySelector(),
                          const SizedBox(height: 24),
                          _buildSectionHeader(currentCategoryName, filteredItems.length),
                          const SizedBox(height: 16),
                          _buildFoodGrid(filteredItems, 2),
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
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF203F35), letterSpacing: 1.1),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.qr_code_scanner, color: Color(0xFF203F35), size: 22),
                tooltip: 'Scan Table QR',
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const QrScannerScreen())),
              ),
              IconButton(
                icon: const Icon(Icons.point_of_sale_outlined, color: Color(0xFF203F35), size: 22),
                tooltip: 'Cashier Station',
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const OrdersScreen(cartItems: []))),
              ),
              IconButton(
                icon: const Icon(Icons.admin_panel_settings_outlined, color: Color(0xFF203F35), size: 22),
                tooltip: 'Admin Dashboard',
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminDashboardScreen())),
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
                  child: const Icon(Icons.notifications_outlined, color: Color(0xFF203F35), size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTableContextStrip() {
    return InkWell(
      onTap: () {},
      child: Container(
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
                  _chosenTableNumber != null ? 'Table ${_chosenTableNumber.toString().padLeft(2, '0')} • verified' : 'Table 07 • verified',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Color(0xFF203F35)),
                ),
              ],
            ),
            const Text('Dine-in', style: TextStyle(fontSize: 10, color: Color(0xFF788078), fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroductionHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("OUR MENU", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFA47C3D), letterSpacing: 1.2)),
        SizedBox(height: 6),
        Text('Heritage Selections', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF203F35))),
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    final activeCategories = _categoriesList.isNotEmpty ? _categoriesList : _categoriesFallback;
    return SizedBox(
      height: 44,
      child: ListView.builder(
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
                if (selected) setState(() => _selectedCategoryId = category.id);
              },
              selectedColor: const Color(0xFF203F35),
              backgroundColor: const Color(0xFFFFFDFA),
              labelStyle: TextStyle(fontSize: 11, color: isSelected ? Colors.white : const Color(0xFF788078)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
              side: BorderSide(color: isSelected ? const Color(0xFF203F35) : const Color(0xFFE5DFD3)),
              showCheckmark: false,
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF203F35))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: const Color(0xFFEEE7D9), borderRadius: BorderRadius.circular(100)),
          child: Text('$count Items', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFA47C3D))),
        ),
      ],
    );
  }

  Widget _buildFoodGrid(List<FoodItem> items, int columns) {
    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Text('No items match your selection.', style: TextStyle(color: Color(0xFF788078))),
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

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FoodDetailsScreen(
                  foodItem: foodItem,
                  tableId: _chosenTableNumber,
                  isTakeout: _isTakeoutSelected,
                  onAddToCart: (item, qty, addOns) => _modifyQuantity(item, qty),
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
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                            Text(foodItem.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF24382F)), maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text('₱${foodItem.price.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF203F35))),
                          ],
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: productCount == 0
                              ? InkWell(
                                  onTap: () => _modifyQuantity(foodItem, 1),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(color: const Color(0xFF203F35), borderRadius: BorderRadius.circular(10)),
                                    child: const Text('Add', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                                  ),
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(icon: const Icon(Icons.remove, size: 14), onPressed: () => _modifyQuantity(foodItem, -1)),
                                    Text('$productCount', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    IconButton(icon: const Icon(Icons.add, size: 14), onPressed: () => _modifyQuantity(foodItem, 1)),
                                  ],
                                ),
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
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF203F35), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ShoppingCartScreen(
                        cart: _orderCart,
                        total: _cartGrandTotal,
                        tableId: _chosenTableNumber,
                        isTakeout: _isTakeoutSelected,
                        isAdditionalOrder: widget.isAdditionalOrder,
                      ),
                    ),
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('View Cart (${_orderCart.values.fold(0, (sum, q) => sum + q)} items)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('₱${_cartGrandTotal.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
              ),
            ),
          ),
        Container(
          height: 70,
          decoration: const BoxDecoration(color: Color(0xFFFFFDFA), border: Border(top: BorderSide(color: Color(0xFFE5DFD3)))),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.restaurant, 'Menu', isActive: true, onTap: () {}),
              _buildNavItem(Icons.shopping_bag_outlined, 'Cart', onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => ShoppingCartScreen(cart: _orderCart, total: _cartGrandTotal, tableId: _chosenTableNumber, isTakeout: _isTakeoutSelected, isAdditionalOrder: widget.isAdditionalOrder)));
              }),
              _buildNavItem(Icons.track_changes, 'Live Status', onTap: () {
                final dynamic activeLiveOrderId = UserSession.lastPlacedOrderId ?? UserSession.targetParentOrderId ?? UserSession.firstOrderId;
                Navigator.push(context, MaterialPageRoute(builder: (context) => OrderStatusScreen(orderId: activeLiveOrderId, isTakeout: _isTakeoutSelected, tableId: _chosenTableNumber, isAdditionalOrder: widget.isAdditionalOrder)));
              }),
              _buildNavItem(Icons.account_balance_wallet_outlined, 'Pay', onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => SessionBillScreen(tableId: _chosenTableNumber, isTakeout: _isTakeoutSelected)));
              }),
            ],
          ),
        ),
      ],
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
          Text(label, style: TextStyle(fontSize: 10, fontWeight: isActive ? FontWeight.bold : FontWeight.normal, color: isActive ? const Color(0xFF203F35) : const Color(0xFF788078))),
          if (isActive) ...[
            const SizedBox(height: 2),
            Container(width: 16, height: 2, decoration: BoxDecoration(color: const Color(0xFF203F35), borderRadius: BorderRadius.circular(2))),
          ],
        ],
      ),
    );
  }
}
