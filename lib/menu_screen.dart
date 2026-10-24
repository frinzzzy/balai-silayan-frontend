import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'dart:ui';
import 'dart:convert';
import 'dart:async';
import 'checkout_screen.dart';
import 'assistance_screen.dart';
import 'orders_screen.dart';
import 'order_status_screen.dart';
import 'shopping_cart_screen.dart';
import 'food_details_screen.dart';
import 'qr_scanner_screen.dart';
import 'order_type_selection_screen.dart';
import 'session_bill_screen.dart';
import 'admin_dashboard_screen.dart';
import 'user_session.dart';
import 'config/api_config.dart';

class FoodItem {
  final int itemDbId;
  final String name;
  final double price;
  final int categoryId;
  final bool isAvailable;
  final String? imageUrl;

  static final Map<int, String> hardcodedImageUrls = {
    1: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c', // Bihon
    2: 'https://images.unsplash.com/photo-1612929633738-8fe44f7ec841', // Mike Bihon
    3: 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38', // Pansit Canton
    4: 'https://images.unsplash.com/photo-1552611052-33e04de081de', // Pansit Bihon Guisado
    5: 'https://images.unsplash.com/photo-1621996346565-e3d5d6281222', // Filipino Style Spaghetti
    6: 'https://images.unsplash.com/photo-1633964913295-ceb43826e7c9', // Creamy Carbonara
    7: 'https://images.unsplash.com/photo-1543339308-43e59d6b73a6', // Baked Macaroni
    8: 'https://images.unsplash.com/photo-1528735602780-2552fd46c7af',
    9: 'https://images.unsplash.com/photo-1550547660-d9450f859349',
    10: 'https://images.unsplash.com/photo-1539252554453-80ab65ce3586',
    11: 'https://images.unsplash.com/photo-1567620832903-9fc6debc209f',
    12: 'https://images.unsplash.com/photo-1608039829572-78524f79c4c7',
    13: 'https://images.unsplash.com/photo-1527477396000-e27163b481c2',
    14: 'https://images.unsplash.com/photo-1540420773420-3366772f4999',
    15: 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd',
    16: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c',
    17: 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1',
    18: 'https://images.unsplash.com/photo-1543339308-43e59d6b73a6',
    19: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c',
    20: 'https://images.unsplash.com/photo-1626777552726-4a6b54c97e46',
    21: 'https://images.unsplash.com/photo-1544025162-d76694265947',
    22: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c',
    23: 'https://images.unsplash.com/photo-1573080496219-bb080dd4f877',
    24: 'https://images.unsplash.com/photo-1513456852971-30c0b8199d4d',
    25: 'https://images.unsplash.com/photo-1534422298391-e4f8c172dddb',
    26: 'https://images.unsplash.com/photo-1555126634-323283e090fa',
    27: 'https://images.unsplash.com/photo-1544025162-d76694265947',
    28: 'https://images.unsplash.com/photo-1567620832903-9fc6debc209f',
    29: 'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2',
    30: 'https://images.unsplash.com/photo-1513104890138-7c749659a591',
    31: 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38',
    32: 'https://images.unsplash.com/photo-1534308983496-4fabb1a015ee',
    33: 'https://images.unsplash.com/photo-1548839140-29a749e1cf4d',
    34: 'https://images.unsplash.com/photo-1556679343-c7306c1976bc',
    35: 'https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd',
    36: 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97',
    37: 'https://images.unsplash.com/photo-1625772299848-391b6a87d7b3',
    38: 'https://images.unsplash.com/photo-1516684732162-798a0062be99',
    39: 'https://images.unsplash.com/photo-1512058564366-18510be2db19',
    40: 'https://images.unsplash.com/photo-1543339308-43e59d6b73a6',
    41: 'https://images.unsplash.com/photo-1563805042-7684c019e1cb',
    42: 'https://images.unsplash.com/photo-1509440159596-0249088772ff',
    43: 'https://images.unsplash.com/photo-1488477181946-6428a0291777',
    44: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c',
    45: 'https://images.unsplash.com/photo-1590301157890-4810ed352733',
    46: 'https://images.unsplash.com/photo-1541658016709-82535e94bc69',
    47: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c',
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
    final String nameStr = (json['name'] ?? '').toString().toLowerCase();

    // Sinisiguro natin na ang bawat ulam ay may tiyak na tamang Unsplash link base sa pangalan at ID nito
    String safeImg = hardcodedImageUrls[id] ?? 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624';

    if (nameStr.contains('mike bihon')) {
      safeImg = 'https://images.unsplash.com/photo-1612929633738-8fe44f7ec841';
    } else if (nameStr.contains('bihon guisado') || nameStr.contains('pansit bihon guisado')) {
      safeImg = 'https://images.unsplash.com/photo-1552611052-33e04de081de';
    } else if (nameStr.contains('bihon')) {
      safeImg = 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c';
    } else if (nameStr.contains('canton')) {
      safeImg = 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38';
    } else if (nameStr.contains('spaghetti')) {
      safeImg = 'https://images.unsplash.com/photo-1621996346565-e3d5d6281222';
    } else if (nameStr.contains('carbonara')) {
      safeImg = 'https://images.unsplash.com/photo-1633964913295-ceb43826e7c9';
    } else if (nameStr.contains('baked mac')) {
      safeImg = 'https://images.unsplash.com/photo-1543339308-43e59d6b73a6';
    }

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
    FoodItem(itemDbId: 10, categoryId: 2, name: 'Carbonara', price: 95.00),
    FoodItem(itemDbId: 15, categoryId: 3, name: 'Clubhouse W/ Fries', price: 135.00),
    FoodItem(itemDbId: 21, categoryId: 4, name: 'Plain (Wings)', price: 335.00),
    FoodItem(itemDbId: 27, categoryId: 5, name: 'Caesar Salad', price: 185.00),
    FoodItem(itemDbId: 33, categoryId: 6, name: 'Kare-Kare (Labot)', price: 375.00),
    FoodItem(itemDbId: 53, categoryId: 7, name: 'Sizzling Chicken', price: 375.00),
    FoodItem(itemDbId: 58, categoryId: 8, name: 'French Fries', price: 115.00),
    FoodItem(itemDbId: 65, categoryId: 9, name: 'Tapsilog', price: 145.00),
    FoodItem(itemDbId: 77, categoryId: 10, name: 'Super Supreme', price: 335.00),
    FoodItem(itemDbId: 84, categoryId: 11, name: 'Bottled Water', price: 25.00),
    FoodItem(itemDbId: 106, categoryId: 12, name: 'Plain Rice (Solo)', price: 25.00),
    FoodItem(itemDbId: 114, categoryId: 13, name: 'Halo-Halo', price: 80.00),
    FoodItem(itemDbId: 117, categoryId: 14, name: 'Bibimbap', price: 180.00),
  ];

  final List<MenuCategory> _categoriesFallback = [
    MenuCategory(id: 0, name: "All Orders"),
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
            .setTransports(['websocket'])
            .disableAutoConnect()
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
      final String targetStr = currentOrderId.toString().replaceAll('#BS-', '').trim();
      final String eventStr = eventOrderId.toString().replaceAll('#BS-', '').trim();
      final int? targetInt = int.tryParse(targetStr);
      final int? eventInt = int.tryParse(eventStr);
      bool isSame = (targetStr == eventStr) || (targetInt != null && eventInt != null && targetInt == eventInt);
      if (!isSame) {
        return;
      }
    }

    if (status == 'COMPLETED' || status == 'PAID' || status == 'CLOSED' || status == 'SETTLED') {
      _handleTableOrderFinished(payload);
    } else if (status == 'DECLINED' || status == 'REJECTED') {
      final String reason = (orderPayload['decline_reason'] ?? orderPayload['reason'] ?? payload['decline_reason'] ?? payload['reason'] ?? 'Item Out of Stock').toString();
      _showMenuOrderDeclinedDialog(reason, orderPayload['order_code'] ?? '#BS-${eventOrderId ?? ""}');
    }
  }

  bool _menuDeclinedDialogShown = false;

  void _showMenuOrderDeclinedDialog(String declineReason, String orderCode) {
    if (_menuDeclinedDialogShown || !mounted) return;
    _menuDeclinedDialogShown = true;

    final int currentTable = _chosenTableNumber ?? UserSession.activeTableId ?? UserSession.activeTableNumber ?? 7;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFFDFA),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Order Declined', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pasensya na po, ang inyong order ($orderCode) ay na-decline ng kitchen/admin.',
              style: const TextStyle(fontSize: 13, color: Color(0xFF203F35), height: 1.4),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Text(
                'Reason: $declineReason',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B3B2B)),
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
            child: const Text('Acknowledge / Back to Menu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _handleTableOrderFinished(dynamic data) {
    if (!mounted) return;

    final int currentTable = _chosenTableNumber ?? UserSession.activeTableId ?? UserSession.activeTableNumber ?? 7;
    int? eventTableId;
    dynamic eventOrderId;
    if (data is Map) {
      eventTableId = int.tryParse(data['table_id']?.toString() ?? data['table_number']?.toString() ?? '');
      eventOrderId = data['order_id'] ?? data['id'];
    }

    if (eventTableId != null && eventTableId != currentTable) {
      return; // Balewalain kapag para sa ibang mesa
    }

    final dynamic currentOrderId = UserSession.lastPlacedOrderId ?? UserSession.targetParentOrderId ?? UserSession.firstOrderId;
    final String orderCode = data is Map ? (data['order_code']?.toString() ?? '#BS-${eventOrderId ?? ""}').trim() : 'Ticket';

    // --- FIX CROSS-TABLE / CROSS-TICKET LEAK ---
    if (eventOrderId != null && currentOrderId != null) {
      final String targetStr = currentOrderId.toString().replaceAll('#BS-', '').trim();
      final String eventStr = eventOrderId.toString().replaceAll('#BS-', '').trim();
      if (targetStr != eventStr) {
        return; // Kung magkaiba ang order ticket, huwag i-interrupt ang user at huwag mag-redirect!
      }
    }

    if (_dialogShown) return;
    _dialogShown = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFFDFA),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Order Finished', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF203F35))),
        content: Text('Order $orderCode is done and has been settled.'),
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
        if (token != null && token.isNotEmpty) {
          headers["Authorization"] = "Bearer $token";
        }

        await http.post(
          Uri.parse('http://localhost:5000/api/v1/customer/sessions/$sessionId/activity'),
          headers: headers,
        );
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
    if (token != null && token.isNotEmpty) {
      headers["Authorization"] = "Bearer $token";
    }
    return headers;
  }

  Future<void> _fetchDatabaseCategories() async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:5000/api/v1/categories'),
        headers: _authHeaders,
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> decodedData = jsonDecode(response.body);
        final List catList = decodedData['data'] ?? [];
        final fetchedCategories = catList
            .map((cat) => MenuCategory.fromJson(cat))
            .toList();

        fetchedCategories.insert(0, MenuCategory(id: 0, name: "All Orders"));

        if (mounted) {
          setState(() {
            _categoriesList = fetchedCategories;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _categoriesList = _categoriesFallback;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _categoriesList = _categoriesFallback;
        });
      }
    }
  }

  Future<void> _syncExistingOrdersForTable() async {
    final int tableId = _chosenTableNumber ?? 7;
    try {
      final response = await http.get(
        Uri.parse('http://localhost:5000/api/v1/orders/unfinished?table_id=$tableId'),
      );
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

          final rawId = firstOrder['id'] ?? firstOrder['order_id'];
          if (rawId != null && widget.isAdditionalOrder && UserSession.targetParentOrderId == null) {
            UserSession.targetParentOrderId = rawId.toString();
          }
        }
      }
    } catch (_) {}

    if (_categoriesList.isEmpty && mounted) {
      setState(() {
        _categoriesList = _categoriesFallback;
      });
    }
  }

  Future<void> _fetchLiveDatabaseMenu() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/v1/customer/menu'),
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> decodedData = jsonDecode(response.body);
        final List menuList = decodedData['data'] ?? [];
        if (mounted && menuList.isNotEmpty) {
          setState(() {
            _menuRepository = menuList
                .map((item) => FoodItem.fromJson(item))
                .toList();
            _isLoading = false;
          });
          return;
        }
      }
      _loadFallbackSamples();
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
        headers: _authHeaders,
      );
      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        final List<dynamic> list = resData['data'] ?? [];
        return List<Map<String, dynamic>>.from(list);
      }
    } catch (_) {}
    return List.generate(20, (i) => {'table_number': i + 1, 'status': 'AVAILABLE'});
  }

  void _promptDiningChoiceContext(BuildContext context) async {
    final List<Map<String, dynamic>> tableStatuses = await _fetchTableStatuses();

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24))),
      builder: (numCtx) {
        return StatefulBuilder(
          builder: (numCtx, setModalState) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20).copyWith(bottom: MediaQuery.of(numCtx).viewInsets.bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 20),
                  const Text('Select Your Dining Style', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(
                      0xFF500808))),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.qr_code_scanner, color: Color(
                              0xFF4A0707)),
                          label: const Text('Scan Table QR Code'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF500808),
                            backgroundColor: const Color(0xFFEEE7D9),
                            side: const BorderSide(color: Color(0xFFE5DFD3)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            Navigator.pop(numCtx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const QrScannerScreen()),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.restaurant, color: Color(
                              0xFF4A0707)),
                          label: const Text('Order Type'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF4A0707),
                            backgroundColor: const Color(0xFFFFFDFA),
                            side: const BorderSide(color: Color(0xFFE5DFD3)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                            foregroundColor: _isTakeoutSelected ? Colors.white : const Color(0xFF788078),
                            backgroundColor: _isTakeoutSelected ? const Color(0xFF203F35) : Colors.white,
                            side: BorderSide(color: _isTakeoutSelected ? const Color(0xFF203F35) : const Color(0xFFE5DFD3)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      const Text('Or choose an available table:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF788078), fontSize: 13)),
                      Row(
                        children: [
                          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                          const Text('Available', style: TextStyle(fontSize: 10, color: Color(0xFF22C55E), fontWeight: FontWeight.bold)),
                          const SizedBox(width: 10),
                          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFD63031), shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                          const Text('Occupied', style: TextStyle(fontSize: 10, color: Color(0xFFD63031), fontWeight: FontWeight.bold)),
                        ],
                      )
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
                          itemCount: tableStatuses.isNotEmpty ? tableStatuses.length : 20,
                          itemBuilder: (context, idx) {
                            final tableData = (tableStatuses.length > idx) ? tableStatuses[idx] : {'table_number': idx + 1, 'status': 'AVAILABLE'};
                            final int tableNum = tableData['table_number'] ?? (idx + 1);
                            final bool isOccupied = (tableData['status'] ?? 'AVAILABLE').toString().toUpperCase() == 'OCCUPIED';
                            final isSelected = _chosenTableNumber == tableNum && !_isTakeoutSelected;

                            Color cardBg = isSelected
                                ? const Color(0xFF203F35)
                                : (isOccupied ? const Color(0xFFFFF0F2) : Colors.white);
                            Color borderColor = isSelected
                                ? const Color(0xFF203F35)
                                : (isOccupied ? const Color(0xFFFF7675) : const Color(0xFF22C55E));
                            Color textColor = isSelected
                                ? Colors.white
                                : (isOccupied ? const Color(0xFFD63031) : const Color(0xFF203F35));
                            Color iconColor = isSelected
                                ? Colors.white
                                : (isOccupied ? const Color(0xFFD63031) : const Color(0xFF22C55E));

                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0, bottom: 4),
                              child: InkWell(
                                onTap: () {
                                  if (isOccupied) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Table #$tableNum is currently occupied by dining guests.'),
                                        backgroundColor: const Color(0xFFD63031),
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
                                    border: Border.all(color: borderColor, width: isOccupied || isSelected ? 1.5 : 1.0),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.table_restaurant_outlined, color: iconColor, size: 18),
                                      const SizedBox(height: 4),
                                      Text('Table $tableNum', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor)),
                                      const SizedBox(height: 2),
                                      Text(
                                        isOccupied ? 'BUSY' : 'FREE',
                                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textColor),
                                      )
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        if (!_isTakeoutSelected && _chosenTableNumber == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please select an available table or Choose Takeout.')),
                          );
                          return;
                        }
                        Navigator.pop(numCtx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CheckoutScreen(
                              cart: _orderCart,
                              total: _cartGrandTotal,
                              tableId: _chosenTableNumber,
                              isTakeout: _isTakeoutSelected,
                              isAdditionalOrder: widget.isAdditionalOrder || UserSession.isAdditionalOrder,
                            ),
                          ),
                        );
                      },
                      child: const Text('Confirm and Continue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  )
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
    final activeCategories = _categoriesList.isNotEmpty ? _categoriesList : _categoriesFallback;
    final currentCategoryName = activeCategories.firstWhere((c) => c.id == _selectedCategoryId, orElse: () => activeCategories.first).name;

    final filteredItems = _menuRepository.where((item) {
      final matchesCategory = _selectedCategoryId == 0 || item.categoryId == _selectedCategoryId;
      final matchesSearch = _searchQuery.isEmpty || item.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    final isDesktop = MediaQuery.of(context).size.width > 900;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFFFFFDFA),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Text('End Session?', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF203F35))),
            content: const Text('Are you sure to end this session?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No', style: TextStyle(color: Color(0xFF788078))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF203F35)),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Yes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
        if (shouldExit == true && context.mounted) {
          UserSession.clearSession();
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const QrScannerScreen()),
                (route) => false,
          );
        }
      },
      child: Scaffold(
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
                      _buildFoodGrid(filteredItems, isDesktop ? 4 : 2),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _buildCustomerBottomNav(),
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
                icon: const Icon(Icons.qr_code_scanner, color: Color(0xFF203F35), size: 22),
                tooltip: 'Scan Table QR',
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const QrScannerScreen())),
              ),
              IconButton(
                icon: const Icon(Icons.point_of_sale_outlined, color: Color(0xFF203F35), size: 22),
                tooltip: 'Cashier Station',
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => OrdersScreen(cartItems: []))),
              ),
              IconButton(
                icon: const Icon(Icons.admin_panel_settings_outlined, color: Color(0xFF203F35), size: 22),
                tooltip: 'Admin Dashboard',
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminDashboardScreen())),
              ),
              InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AssistanceScreen())),
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
    final String tableLabel = _isTakeoutSelected
        ? 'Takeout / To-Go'
        : (_chosenTableNumber != null ? 'Table ${_chosenTableNumber.toString().padLeft(2, '0')} • verified' : 'Table 07 • verified');
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
                const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF53766C)),
                const SizedBox(width: 6),
                Text(
                  tableLabel,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Color(0xFF203F35)),
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  stateLabel,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF788078), fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.edit_outlined, size: 12, color: Color(0xFF788078)),
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
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFA47C3D), letterSpacing: 1.2),
        ),
        SizedBox(height: 6),
        Text(
          'Heritage Selections',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF203F35)),
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
              child: const Icon(Icons.close, size: 16, color: Color(0xFF788078)),
            ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    final activeCategories = _categoriesList.isNotEmpty ? _categoriesList : _categoriesFallback;
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
                  if (selected) setState(() => _selectedCategoryId = category.id);
                },
                selectedColor: const Color(0xFF203F35),
                backgroundColor: const Color(0xFFFFFDFA),
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                  color: isSelected ? Colors.white : const Color(0xFF788078),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                side: BorderSide(color: isSelected ? const Color(0xFF203F35) : const Color(0xFFE5DFD3)),
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
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF203F35)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFEEE7D9),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            '$count Items',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFA47C3D)),
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
        final bool available = foodItem.isAvailable;

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FoodDetailsScreen(
                  foodItem: foodItem,
                  tableId: _chosenTableNumber,
                  isTakeout: _isTakeoutSelected,
                  onAddToCart: (item, qty, addOns) {
                    _modifyQuantity(item, qty);
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
                    borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                    child: foodItem.imageUrl != null && foodItem.imageUrl!.isNotEmpty
                        ? Image.network(
                      foodItem.imageUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 118,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF203F35)),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Icon(_getCategoryIcon(foodItem.categoryId), size: 36, color: const Color(0xFF203F35)),
                        );
                      },
                    )
                        : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_getCategoryIcon(foodItem.categoryId), size: 36, color: const Color(0xFF203F35)),
                          const SizedBox(height: 4),
                          Text(
                            foodItem.name.isNotEmpty ? foodItem.name.substring(0, 1) : 'D',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFFA47C3D)),
                          ),
                        ],
                      ),
                    ),
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
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF24382F)),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _getCategoryName(foodItem.categoryId),
                              style: const TextStyle(fontSize: 10, color: Color(0xFF788078)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              available ? 'In Stock' : 'Sold Out',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: available ? const Color(0xFF53766C) : const Color(0xFF8E5136),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '₱${foodItem.price.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF203F35)),
                            ),
                            !available
                                ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD9DBD3),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text('Off', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF788078))),
                            )
                                : productCount == 0
                                ? InkWell(
                              onTap: () => _modifyQuantity(foodItem, 1),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF203F35),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text('Add', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
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
                                    onTap: () => _modifyQuantity(foodItem, -1),
                                    child: const Padding(
                                      padding: EdgeInsets.all(4.0),
                                      child: Icon(Icons.remove, size: 14, color: Colors.white),
                                    ),
                                  ),
                                  Text('$productCount', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                                  InkWell(
                                    onTap: () => _modifyQuantity(foodItem, 1),
                                    child: const Padding(
                                      padding: EdgeInsets.all(4.0),
                                      child: Icon(Icons.add, size: 14, color: Colors.white),
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
    final match = _categoriesList.isNotEmpty
        ? _categoriesList.firstWhere((c) => c.id == catId, orElse: () => MenuCategory(id: catId, name: 'Specialty'))
        : _categoriesFallback.firstWhere((c) => c.id == catId, orElse: () => MenuCategory(id: catId, name: 'Specialty'));
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
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
                    Text(
                      'View Cart (${_orderCart.values.fold(0, (sum, q) => sum + q)} items)',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Row(
                      children: [
                        Text(
                          '₱${_cartGrandTotal.toStringAsFixed(0)}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward, color: Colors.white, size: 16),
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
              _buildNavItem(Icons.restaurant, 'Menu', isActive: true, onTap: () {}),
              _buildNavItem(Icons.shopping_bag_outlined, 'Cart', onTap: () {
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
              }),
              _buildNavItem(Icons.track_changes, 'Live Status', onTap: () {
                final dynamic activeLiveOrderId = UserSession.lastPlacedOrderId ?? UserSession.targetParentOrderId ?? UserSession.firstOrderId;

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OrderStatusScreen(
                      orderId: activeLiveOrderId,
                      isTakeout: _isTakeoutSelected,
                      tableId: _chosenTableNumber,
                      isAdditionalOrder: widget.isAdditionalOrder,
                    ),
                  ),
                );
              }),
              _buildNavItem(Icons.account_balance_wallet_outlined, 'Pay', onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SessionBillScreen(
                      tableId: _chosenTableNumber,
                      isTakeout: _isTakeoutSelected,
                    ),
                  ),
                );
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