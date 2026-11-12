import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'order_status_screen.dart';
import 'shopping_cart_screen.dart';
import 'food_details_screen.dart';
import 'order_type_selection_screen.dart';
import 'session_bill_screen.dart';
import 'user_session.dart';
import '../widgets/finished_order_dialog.dart';
import 'services/audio_notification_service.dart';
import 'services/global_socket_listener.dart';
import 'services/socket_service.dart';
import 'services/order_context.dart';
import 'services/order_event_bus.dart';
import 'services/order_event_router.dart';
import 'config/api_config.dart';

class FoodItem {
  final int itemDbId;
  final String name;
  final double price;
  final int categoryId;
  final bool isAvailable;
  final String? imageUrl;

  static String getLocalMenuImage(String dishName) {
    final String clean = dishName.trim().toLowerCase();
    if (clean.contains('bibimbap')) return 'lib/menus/Bibimbap.jpg';
    if (clean.contains('chopsuey')) return 'lib/menus/Chopsuey.jpg';
    if (clean.contains('pinakbet')) return 'lib/menus/Pinakbet.jpg';
    if (clean.contains('tapsilog')) return 'lib/menus/Tapsilog.jpg';
    if (clean.contains('java rice')) return 'lib/menus/Java Rice.jpg';
    if (clean.contains('porksilog')) return 'lib/menus/Porksilog.jpg';
    if (clean.contains('bangusilog')) return 'lib/menus/Bangusilog.jpg';
    if (clean.contains('leche flan')) return 'lib/menus/Leche Flan.jpg';
    if (clean.contains('mike bihon')) return 'lib/menus/Mike Bihon.jpg';
    if (clean.contains('garlic rice')) return 'lib/menus/Garlic Rice.jpg';
    if (clean.contains('plain wings')) return 'lib/menus/Plain Wings.jpg';
    if (clean.contains('caesar salad')) return 'lib/menus/Caesar Salad.jpg';
    if (clean.contains('chickensilog')) return 'lib/menus/Chickensilog.jpg';
    if (clean.contains('coke')) return 'lib/menus/Coke Regular.jpg';
    if (clean.contains('fries')) return 'lib/menus/French Fries.jpg';
    if (clean.contains('bihon')) return 'lib/menus/Pancit Bihon.jpg';
    if (clean.contains('blue lemonade')) return 'lib/menus/Blue Lemonade.jpg';
    if (clean.contains('water') || clean.contains('bottled')) return 'lib/menus/Bottled Water.jpg';
    if (clean.contains('buffalo')) return 'lib/menus/Buffalo Wings.jpg';
    if (clean.contains('canton')) return 'lib/menus/Pansit Canton.jpg';
    if (clean.contains('tofu')) return 'lib/menus/Sizzling Tofu.jpg';
    if (clean.contains('macaroni') || clean.contains('mac')) return 'lib/menus/Baked Macaroni.jpg';
    if (clean.contains('bulalo')) return 'lib/menus/Bulalo Special.jpg';
    if (clean.contains('fish')) return 'lib/menus/Fish and Chips.jpg';
    if (clean.contains('nachos')) return 'lib/menus/Nachos Supreme.jpg';
    if (clean.contains('sprite')) return 'lib/menus/Sprite (330ml).jpg';
    if (clean.contains('tea')) return 'lib/menus/Iced Tea (Glass).jpg';
    if (clean.contains('sizzling chicken')) return 'lib/menus/Sizzling Chicken.jpg';
    if (clean.contains('carbonara') || clean.contains('carbonarra')) return 'lib/menus/Creamy Carbonarra.jpg';
    if (clean.contains('halo')) return 'lib/menus/Halo-Halo Special.jpg';
    if (clean.contains('hawaiian')) return 'lib/menus/Hawaiian Overload.jpg';
    if (clean.contains('kare')) return 'lib/menus/Kare-Kare (Labot).jpg';
    if (clean.contains('kimchi')) return 'lib/menus/Kimchi Fried Rice.jpg';
    if (clean.contains('mango') || clean.contains('panna cotta')) return 'lib/menus/Mango Panna Cotta.jpg';
    if (clean.contains('pepperoni')) return 'lib/menus/Pepperoni Classic.jpg';
    if (clean.contains('plain rice') || clean.contains('rice')) return 'lib/menus/Plain Rice (Solo).jpg';
    if (clean.contains('sinigang')) return 'lib/menus/Sinigang na Baboy.jpg';
    if (clean.contains('honey') || clean.contains('garlic wings')) return 'lib/menus/Honey Garlic Wings.jpg';
    if (clean.contains('tuna')) return 'lib/menus/Tuna Melt Sandwich.jpg';
    if (clean.contains('sisig')) return 'lib/menus/Sizzling Pork Sisig.jpg';
    if (clean.contains('supreme pizza') || clean.contains('pizza')) return 'lib/menus/Super Supreme Pizza.jpg';
    if (clean.contains('ham')) return 'lib/menus/Ham and Cheese Sandwich.jpg';
    if (clean.contains('spaghetti')) return 'lib/menus/Filipino Style Spaghetti.jpg';
    if (clean.contains('clubhouse') || clean.contains('sandwich')) return 'lib/menus/Clubhouse Sandwich with Fries.jpg';
    return 'lib/menus/Pancit Bihon.jpg';
  }

  static final Map<int, String> hardcodedImageUrls = {
    1: 'lib/menus/Pancit Bihon.jpg',
    2: 'lib/menus/Mike Bihon.jpg',
    3: 'lib/menus/Pansit Canton.jpg',
    4: 'lib/menus/Pancit Bihon.jpg',
    5: 'lib/menus/Filipino Style Spaghetti.jpg',
    6: 'lib/menus/Creamy Carbonarra.jpg',
    7: 'lib/menus/Baked Macaroni.jpg',
    8: 'lib/menus/Clubhouse Sandwich with Fries.jpg',
    9: 'lib/menus/Ham and Cheese Sandwich.jpg',
    10: 'lib/menus/Tuna Melt Sandwich.jpg',
    11: 'lib/menus/Plain Wings.jpg',
    12: 'lib/menus/Buffalo Wings.jpg',
    13: 'lib/menus/Honey Garlic Wings.jpg',
    14: 'lib/menus/Caesar Salad.jpg',
    15: 'lib/menus/Chopsuey.jpg',
    16: 'lib/menus/Pinakbet.jpg',
    17: 'lib/menus/Kare-Kare (Labot).jpg',
    18: 'lib/menus/Bulalo Special.jpg',
    19: 'lib/menus/Sinigang na Baboy.jpg',
    20: 'lib/menus/Sizzling Chicken.jpg',
    21: 'lib/menus/Sizzling Pork Sisig.jpg',
    22: 'lib/menus/Sizzling Tofu.jpg',
    23: 'lib/menus/French Fries.jpg',
    24: 'lib/menus/Nachos Supreme.jpg',
    25: 'lib/menus/Fish and Chips.jpg',
    26: 'lib/menus/Tapsilog.jpg',
    27: 'lib/menus/Porksilog.jpg',
    28: 'lib/menus/Chickensilog.jpg',
    29: 'lib/menus/Bangusilog.jpg',
    30: 'lib/menus/Super Supreme Pizza.jpg',
    31: 'lib/menus/Hawaiian Overload.jpg',
    32: 'lib/menus/Pepperoni Classic.jpg',
    33: 'lib/menus/Bottled Water.jpg',
    34: 'lib/menus/Iced Tea (Glass).jpg',
    35: 'lib/menus/Blue Lemonade.jpg',
    36: 'lib/menus/Coke Regular.jpg',
    37: 'lib/menus/Sprite (330ml).jpg',
    38: 'lib/menus/Plain Rice (Solo).jpg',
    39: 'lib/menus/Garlic Rice.jpg',
    40: 'lib/menus/Java Rice.jpg',
    41: 'lib/menus/Halo-Halo Special.jpg',
    42: 'lib/menus/Leche Flan.jpg',
    43: 'lib/menus/Mango Panna Cotta.jpg',
    44: 'lib/menus/Bibimbap.jpg',
    45: 'lib/menus/Kimchi Fried Rice.jpg',
    46: 'lib/menus/Tteokbokki.jpg',
    47: 'lib/menus/Ramen with Cheese.jpg',

  };

  FoodItem({
    required this.itemDbId,
    required this.name,
    required this.price,
    required this.categoryId,
    this.isAvailable = true,
    String? imageUrl,
  }) : imageUrl = imageUrl ?? hardcodedImageUrls[itemDbId] ?? getLocalMenuImage(name);

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    final int id = json['id'] ?? 0;
    final String name = json['name'] ?? 'Delicious Dish';
    final String? dbImg = json['image_url'];
    final String fallbackImg = hardcodedImageUrls[id] ?? getLocalMenuImage(name);

    return FoodItem(
      itemDbId: id,
      name: name,
      price: double.tryParse(json['price']?.toString() ?? '0.0') ?? 0.0,
      categoryId: json['category_id'] ?? 1,
      isAvailable: json['is_available'] ?? true,
      imageUrl: (dbImg != null && dbImg.isNotEmpty && !dbImg.startsWith('http')) ? dbImg : fallbackImg,
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
  Timer? _statusPollTimer;
  bool _dialogShown = false;
  int? _refreshToken;
  int? _contextToken;
  bool _pollInFlight = false;

  /// Huling nakita na status per order (polling fallback detection).
  final Map<String, String> _polledOrderStatuses = <String, String>{};

  @override
  void initState() {
    super.initState();
    GlobalSocketListener.instance.resetTableIdentity();
    AudioNotificationService.resetOrderNotificationDedupe();
    _polledOrderStatuses.clear();
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
    GlobalSocketListener.instance.registerTableIdentity(
      tableId: widget.tableId,
      tableNumber: widget.tableNumber ?? _chosenTableNumber,
    );
    if (!widget.isAdditionalOrder) {
      UserSession.targetParentOrderId = null;
      UserSession.lastPlacedOrderId = null;
    }

    _fetchDatabaseCategories();
    _fetchLiveDatabaseMenu();
    _syncExistingOrdersForTable();
    _fetchBillLockState();
    _startHeartbeatTimer();
    _startStatusPollTimer();
    GlobalSocketListener.instance.start(context: context);
    // I-set natin ang MenuScreen bilang ang default order handler. Ang mga
    // pushed screens (ex: OrderStatusScreen) ay nag-override nito habang naka-istante,
    // at ibabalik ang default kapag may nag-pop na naglalayong magreveal ng MenuScreen.
    GlobalSocketListener.instance.setFallbackOrderEventHandler(_handleTableOrderEvent);
    GlobalSocketListener.instance.setFallbackOrderSessionClosed(_handleTableOrderFinished);
    GlobalSocketListener.instance.setOnStockChanged(() { _fetchLiveDatabaseMenu(); });
    // Tanging isang screen-level handler lang dati ang nagsisilbing refresh.
    // Ngayon, bawat screen ay may sariling subscription sa OrderEventBus.
    _refreshToken = OrderEventBus.instance.subscribeRefresh(_syncExistingOrdersForTable);

    // Tukuyin ang order context ng screen na ito para tama ang pop-up policy.
    _contextToken = OrderContext.instance.enter(
      mode: widget.isAdditionalOrder || UserSession.isAdditionalOrder
          ? CustomerOrderMode.additionalOrder
          : CustomerOrderMode.newOrder,
      activeOrderId: UserSession.lastPlacedOrderId,
      linkedParentId: UserSession.targetParentOrderId,
    );

    // Bagong pasok sa additional-order flow: i-reset ang popup dedupe ng
    // parent at sariling order para hindi barado ng lumang key ang susunod
    // na finished/declined update.
    if (widget.isAdditionalOrder || UserSession.isAdditionalOrder) {
      OrderEventRouter.instance.resetPopupDedupe(UserSession.targetParentOrderId);
      OrderEventRouter.instance.resetPopupDedupe(UserSession.lastPlacedOrderId);
    }
  }

  bool _isCurrentTicketBillLocked() {
    if (!(widget.isAdditionalOrder || UserSession.isAdditionalOrder)) {
      return false;
    }
    final dynamic parentId =
        UserSession.targetParentOrderId ?? UserSession.lastPlacedOrderId;
    return UserSession.isTicketBillRequested(parentId);
  }

  Future<void> _fetchBillLockState() async {
    final int tableNum = _chosenTableNumber ??
        UserSession.activeTableNumber ??
        UserSession.activeTableId ??
        7;
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/v1/tables/$tableNum/bill'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return;

      final dynamic decoded = jsonDecode(response.body);
      final Map<String, dynamic> data =
          decoded is Map && decoded['data'] is Map
              ? Map<String, dynamic>.from(decoded['data'])
              : <String, dynamic>{};
      final List orders = data['orders'] is List ? data['orders'] : [];

      // Kung ibang session ang ibinalik ng backend (hal. luma/closed), huwag
      // i-overwrite ang flags ng kasalukuyang session ng customer.
      final int? responseSessionId = int.tryParse(
        (data['session_id'] ?? '').toString(),
      );
      final int? currentSessionId =
          UserSession.activeSessionId ?? int.tryParse(UserSession.sessionId ?? '');
      if (responseSessionId != null &&
          currentSessionId != null &&
          responseSessionId != currentSessionId) {
        return;
      }

      const Set<String> terminalStatuses = <String>{
        'PAID',
        'COMPLETED',
        'CLOSED',
        'SETTLED',
        'CANCELLED',
        'DECLINED',
        'REJECTED',
      };

      UserSession.clearAllBillRequests();
      for (final dynamic raw in orders) {
        if (raw is! Map) continue;
        final String status =
            (raw['status'] ?? raw['order_status'] ?? '').toString().toUpperCase();
        if (terminalStatuses.contains(status)) continue;
        final dynamic orderId = raw['order_id'] ?? raw['id'];
        final dynamic requestedAt = raw['bill_requested_at'];
        if (requestedAt != null) {
          UserSession.setTicketBillRequested(orderId, requestedAt);
        }
      }
      if (mounted) setState(() {});
    } catch (_) {
      // Best-effort lang: hindi dapat harangin ang menu kung offline.
    }
  }

  Future<bool> _ensureOrderingNotLocked() async {
    if (!_isCurrentTicketBillLocked()) return true;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFFDFA),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Bill already requested',
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF203F35)),
        ),
        content: const Text(
          'Naka-request na ang bill para sa ticket na ito. Ask staff to reopen ordering bago magdagdag ng items.',
          style: TextStyle(fontSize: 13, color: Color(0xFF203F35), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    return false;
  }

  void _handleTableOrderEvent(dynamic data) {
    // LAHAT ng finished/declined pop-ups ay hawak na ng OrderEventRouter
    // (socket at polling) ayon sa OrderContext. Keep this as a lightweight
    // fallback handler para may ma-restore ang route observer pagbalik sa menu.
    if (!mounted || data == null) return;
    final Map<String, dynamic> payload = data is Map<String, dynamic>
        ? data
        : Map<String, dynamic>.from(data as Map);
    final Map<String, dynamic> orderPayload = payload['order'] is Map
        ? Map<String, dynamic>.from(payload['order'])
        : payload;
    GlobalSocketListener.instance.registerTableIdentity(
      tableId: widget.tableId,
      tableNumber: widget.tableNumber ?? _chosenTableNumber,
    );
    if (!GlobalSocketListener.instance.isEventForCurrentTable(
      orderPayload,
      payload,
    )) {
      return;
    }
  }

  void _handleTableOrderFinished(dynamic eventPayloadData) {
    if (!mounted) return;
    
    // Strict Scoping check before showing finished dialog
    if (eventPayloadData != null) {
      final Map<String, dynamic> data = eventPayloadData is Map<String, dynamic>
          ? eventPayloadData
          : (eventPayloadData is Map ? Map<String, dynamic>.from(eventPayloadData) : {});
      final Map<String, dynamic> orderPayload = data['order'] is Map ? Map<String, dynamic>.from(data['order']) : data;

      final dynamic eventSessionId = orderPayload['session_id'] ?? data['session_id'];

      if (!GlobalSocketListener.instance.isEventForCurrentTable(orderPayload, data)) {
        return; // Ibang table, ignore
      }
      
      final int? eventTableFromPayload = int.tryParse(orderPayload['table_id']?.toString() ?? data['table_id']?.toString() ?? '');

      if (eventTableFromPayload == null && eventSessionId != null) {
        final int? currentSessionId = UserSession.activeSessionId ?? int.tryParse(UserSession.sessionId ?? '');
        if (currentSessionId != null && int.tryParse(eventSessionId.toString()) != currentSessionId) {
          return; // Ignore events for other sessions
        }
      }

      final dynamic eventOrderId = orderPayload['order_id'] ?? orderPayload['id'] ?? data['order_id'] ?? data['id'];

      final bool isAdd = widget.isAdditionalOrder || UserSession.isAdditionalOrder;
      final dynamic targetId = isAdd
          ? UserSession.targetParentOrderId
          : UserSession.lastPlacedOrderId;

      if (eventOrderId != null && targetId != null) {
        if (!SocketService.isSameOrder(eventOrderId, targetId)) {
          return; // Ignore events for other tickets/orders
        }
      }
    }
    
    final dynamic resolvedOrderId = eventPayloadData is Map
        ? (eventPayloadData['order_id'] ?? eventPayloadData['id'])
        : null;
    final String resolvedOrderCode = eventPayloadData is Map
        ? (eventPayloadData['order_code']?.toString() ?? '#BS-${resolvedOrderId ?? ""}').trim()
        : 'Ticket';

    if (_dialogShown) return;
    _dialogShown = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FinishedOrderDialog.show(
        orderCode: resolvedOrderCode,
        orderId: UserSession.formatOrderCode(resolvedOrderId ?? UserSession.lastPlacedOrderId),
      );
    });
  }

  /// Polling fallback para sa notifications: kahit patay/disconnected ang
  /// socket, nakikita pa rin ang status changes at nagpapakita ng banner.
  void _startStatusPollTimer() {
    _statusPollTimer?.cancel();
    _statusPollTimer = Timer.periodic(const Duration(seconds: 12), (timer) {
      if (!mounted) return;
      _syncExistingOrdersForTable();
    });
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
        await http.post(Uri.parse('$_baseUrl/api/v1/customer/sessions/$sessionId/activity'), headers: headers).timeout(const Duration(seconds: 10));
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _statusPollTimer?.cancel();
    if (_refreshToken != null) {
      OrderEventBus.instance.unsubscribe(_refreshToken!);
      _refreshToken = null;
    }
    if (_contextToken != null) {
      OrderContext.instance.leave(_contextToken!);
      _contextToken = null;
    }
    _searchController.dispose();
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
      final response = await http.get(Uri.parse('$_baseUrl/api/v1/categories'), headers: _authHeaders).timeout(const Duration(seconds: 10));
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
    if (_pollInFlight) return;
    _pollInFlight = true;
    final int tableId = _chosenTableNumber ?? 7;
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/v1/orders/unfinished?table_id=$tableId')).timeout(const Duration(seconds: 10));
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

        final Set<String> seenIds = <String>{};

        // Polling fallback: i-detect ang status changes at mag-notify kahit
        // patay/disconnected ang socket (dedupe ang humaharang sa doble).
        for (final dynamic raw in ordersList) {
          if (raw is! Map) continue;
          final dynamic orderId = raw['order_id'] ?? raw['id'];
          final String status =
              (raw['order_status'] ?? raw['status'] ?? '').toString().toUpperCase();
          if (orderId == null || status.isEmpty) continue;

          final String key = orderId.toString();
          seenIds.add(key);
          final String? previousStatus = _polledOrderStatuses[key];
          _polledOrderStatuses[key] = status;

          if (previousStatus != null && previousStatus != status) {
            OrderEventRouter.instance.onStatusObserved(
              status: status,
              orderId: orderId,
              reason: raw['decline_reason']?.toString() ?? raw['reason']?.toString(),
              parentOrderId: raw['parent_order_id'],
              eventType: 'poll',
            );
          }
        }

        // Ang COMPLETED/PAID ay tinatanggal sa /unfinished kaya hindi na
        // lumalabas dito. I-check ang mga dating nakita pero nawala na, para
        // hindi mawala ang notification kapag namiss ng socket ang event.
        final List<String> vanished = _polledOrderStatuses.keys
            .where((id) => !seenIds.contains(id))
            .toList();
        for (final String orderId in vanished) {
          await _detectVanishedOrder(orderId);
        }
      }
    } catch (_) {
    } finally {
      _pollInFlight = false;
    }
    if (_categoriesList.isEmpty && mounted) setState(() => _categoriesList = _categoriesFallback);
  }

  /// Kapag nawala ang order sa `/unfinished`, malamang na-settle na ito.
  /// Kunin ang final status para makapag-notify at makapag-pop-up nang tama.
  Future<void> _detectVanishedOrder(String orderId) async {
    try {
      final response =
          await http.get(Uri.parse('$_baseUrl/api/v1/orders/$orderId')).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        _polledOrderStatuses.remove(orderId);
        return;
      }
      final dynamic decoded = jsonDecode(response.body);
      final dynamic rawOrder = decoded is Map
          ? (decoded['data']?['order'] ?? decoded['data'] ?? decoded['order'])
          : null;
      if (rawOrder is! Map) {
        _polledOrderStatuses.remove(orderId);
        return;
      }
      final String finalStatus =
          (rawOrder['order_status'] ?? rawOrder['status'] ?? '').toString().toUpperCase();
      final String previousStatus = _polledOrderStatuses[orderId] ?? '';
      if (finalStatus.isNotEmpty && finalStatus != previousStatus) {
        OrderEventRouter.instance.onStatusObserved(
          status: finalStatus,
          orderId: rawOrder['order_id'] ?? rawOrder['id'] ?? orderId,
          reason: rawOrder['decline_reason']?.toString() ?? rawOrder['reason']?.toString(),
          parentOrderId: rawOrder['parent_order_id'],
          eventType: 'poll',
        );
      }
      _polledOrderStatuses[orderId] = finalStatus;
    } catch (_) {
      _polledOrderStatuses.remove(orderId);
    }
  }

  Future<void> _fetchLiveDatabaseMenu() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/v1/customer/menu')).timeout(const Duration(seconds: 10));
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

        final String? imgUrl = foodItem.imageUrl;
        Widget imageWidget;
        if (imgUrl != null && imgUrl.startsWith('lib/menus/')) {
          imageWidget = Image.asset(
            imgUrl,
            width: double.infinity,
            height: 120,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              height: 120,
              color: const Color(0xFFEEE7D9),
              child: const Icon(Icons.restaurant, color: Color(0xFF203F35), size: 32),
            ),
          );
        } else if (imgUrl != null && imgUrl.startsWith('http')) {
          imageWidget = Image.network(
            imgUrl,
            width: double.infinity,
            height: 120,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              height: 120,
              color: const Color(0xFFEEE7D9),
              child: const Icon(Icons.restaurant, color: Color(0xFF203F35), size: 32),
            ),
          );
        } else {
          imageWidget = Container(
            height: 120,
            color: const Color(0xFFEEE7D9),
            child: const Icon(Icons.restaurant, color: Color(0xFF203F35), size: 32),
          );
        }

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
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
                  child: imageWidget,
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
                onPressed: () async {
                  if (!await _ensureOrderingNotLocked()) return;
                  if (!mounted) return;
                  final updatedCart = await Navigator.push<Map<FoodItem, int>>(
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

                  if (updatedCart != null && mounted) {
                    setState(() {
                      _orderCart.clear();
                      _orderCart.addAll(updatedCart);
                    });
                  }
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
              _buildNavItem(Icons.shopping_bag_outlined, 'Cart', onTap: () async {
                if (!await _ensureOrderingNotLocked()) return;
                if (!mounted) return;
                Navigator.push(context, MaterialPageRoute(builder: (context) => ShoppingCartScreen(cart: _orderCart, total: _cartGrandTotal, tableId: _chosenTableNumber, isTakeout: _isTakeoutSelected, isAdditionalOrder: widget.isAdditionalOrder)));
              }),
              _buildNavItem(Icons.track_changes, 'Live Status', onTap: () {
                final dynamic activeLiveOrderId = UserSession.lastPlacedOrderId ?? UserSession.targetParentOrderId ?? UserSession.firstOrderId;
                Navigator.push(context, MaterialPageRoute(builder: (context) => OrderStatusScreen(orderId: activeLiveOrderId, isTakeout: _isTakeoutSelected, tableId: _chosenTableNumber, isAdditionalOrder: widget.isAdditionalOrder)));
              }),
              _buildNavItem(Icons.account_balance_wallet_outlined, 'Bill', onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (context) => SessionBillScreen(tableId: _chosenTableNumber, isTakeout: _isTakeoutSelected)));
                if (mounted) _fetchBillLockState();
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
