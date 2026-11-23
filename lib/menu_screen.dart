import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'order_status_screen.dart';
import 'shopping_cart_screen.dart';
import 'food_details_screen.dart';
import 'order_type_selection_screen.dart';
import 'session_bill_screen.dart';
import 'welcome_screen.dart';
import 'user_session.dart';
import '../widgets/customer_bottom_nav.dart';
import '../widgets/ticket_picker_dialog.dart';
import '../widgets/finished_order_dialog.dart';
import 'services/audio_notification_service.dart';
import 'services/global_socket_listener.dart';
import 'services/socket_service.dart';
import 'services/order_context.dart';
import 'services/order_event_bus.dart';
import 'services/order_event_router.dart';
import 'services/customer_cart_store.dart';
import 'services/customer_order_reset.dart';
import 'services/customer_ticket_service.dart';
import 'services/ordering_gate.dart';
import 'config/api_config.dart';
import 'utils/currency.dart';

class FoodItem {
  final int itemDbId;
  final String name;
  final double price;
  final int categoryId;
  final bool isAvailable;
  final String? imageUrl;
  final int? stockQuantity;

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
    this.stockQuantity,
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
      stockQuantity: int.tryParse(json['stock_quantity']?.toString() ?? '') ?? null,
      imageUrl: (dbImg != null && dbImg.isNotEmpty && !dbImg.startsWith('http')) ? dbImg : fallbackImg,
    );
  }

  /// Parehong menu item = parehong cart line, kahit muling nabuo ang object
  /// mula sa `CustomerCartStore` (hal. pag-restore pagkatapos gumawa ng bagong
  /// MenuScreen).
  ///
  /// Kapag `itemDbId == 0` (hal. local/test item na walang backend id), hindi
  /// pwedeng id lang ang basehan — magko-collide ang lahat ng item at
  /// magsasama-sama sa isang cart line. Fallback sa name + category + price.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FoodItem) return false;
    if (itemDbId > 0 && other.itemDbId > 0) {
      return itemDbId == other.itemDbId;
    }
    return other.itemDbId == itemDbId &&
        other.name.trim().toLowerCase() == name.trim().toLowerCase() &&
        other.categoryId == categoryId &&
        other.price == price;
  }

  @override
  int get hashCode => itemDbId > 0
      ? itemDbId.hashCode
      : Object.hash(name.trim().toLowerCase(), categoryId, price);
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

  /// `true` kapag galing sa "Order Online / Takeout" (Google Sign-In) door.
  /// Takeout ang fulfillment at naka-hide ang Bill tab.
  final bool isTakeout;

  /// Kapag `true`, sadyang nagsimula ng brand-new order ang customer (mula sa
  /// Order Type Selection). Nililinis nito ang dating additional-order flags.
  ///
  /// Kapag `false` (default), pinapanatili ang kasalukuyang order context at
  /// awtomatikong nagiging additional ang susunod na order kung may active
  /// ticket pa (`UserSession.autoAdditionalParentId`).
  final bool resetOrderContext;

  const MenuScreen({
    super.key,
    this.tableId,
    this.tableNumber,
    this.isAdditionalOrder = false,
    this.isTakeout = false,
    this.resetOrderContext = false,
  });

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  int _selectedCategoryId = 0;
  List<FoodItem> _menuRepository = [];
  final Map<FoodItem, int> _orderCart = {};
  bool _isLoading = true;
  String? _menuError;
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
  bool _ticketsLoading = false;
  int? _refreshToken;
  int? _contextToken;
  bool _pollInFlight = false;
  bool _popScopeCanPop = true;

  /// Additional ba ang kasalukuyang order flow? Kasama ang auto-additional na
  /// naka-set pagkatapos mag-place ng order habang nasa Menu pa lang.
  bool get _effectiveAdditional {
    // Manual takeout choice ang uunahin — kahit may autoAdditional mula sa
    // nakaraang order, ang pinili ng customer sa cart ang susundin.
    if (_isTakeoutSelected && _takeoutOrderTypeResolved) {
      return _takeoutChoseAdditional;
    }
    if (UserSession.autoAdditionalParentId != null) return true;
    if (_forceNewOrderMode) return false;
    return widget.isAdditionalOrder || UserSession.isAdditionalOrder;
  }

  /// Naka-set kapag pinili ng customer ang "Continue as New Order" matapos
  /// ma-block ang additional order (hal. PREPARING na ang parent).
  bool _forceNewOrderMode = false;

  /// Takeout: na-asks na ba ang customer ng New/Additional choice para sa
  /// kasalukuyang laman ng cart? I-reset kapag naubos ang cart (tapos mag-order).
  bool _takeoutOrderTypeResolved = false;
  bool _takeoutChoseAdditional = false;

  /// Ticket na pagdadagdag-an / iko-consider para sa bill at status gate.
  dynamic get _activeParentOrderId =>
      UserSession.targetParentOrderId ??
      UserSession.autoAdditionalParentId ??
      UserSession.lastPlacedOrderId ??
      UserSession.firstOrderId;

  /// Huling nakita na status per order (polling fallback detection).
  final Map<String, String> _polledOrderStatuses = <String, String>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _popScopeCanPop = Navigator.of(context).canPop();
  }

  @override
  void initState() {
    super.initState();
    GlobalSocketListener.instance.resetTableIdentity();
    AudioNotificationService.resetOrderNotificationDedupe();
    _polledOrderStatuses.clear();

    // Takeout (Google online) context: server-assigned virtual table + session.
    _isTakeoutSelected = widget.isTakeout || UserSession.isTakeout;
    if (_isTakeoutSelected) {
      UserSession.isTakeout = true;
    }

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

    // Initialisahin ang order context ayon sa pinanggalingan ng Menu.
    // Takeout: huwag ipagpalagay na additional ang susunod na order — manual
    // na pipiliin ng customer sa cart (New Order / Additional Order).
    if (_isTakeoutSelected && !widget.isAdditionalOrder) {
      UserSession.isAdditionalOrder = false;
      UserSession.targetParentOrderId = null;
      UserSession.autoAdditionalParentId = null;
    }

    if (widget.resetOrderContext) {
      // Sadyang brand-new order (mula sa Order Type Selection).
      UserSession.isAdditionalOrder = widget.isAdditionalOrder;
      if (!widget.isAdditionalOrder) {
        UserSession.targetParentOrderId = null;
        UserSession.lastPlacedOrderId = null;
        UserSession.autoAdditionalParentId = null;
      }
    } else {
      final dynamic autoParent = UserSession.autoAdditionalParentId;
      final bool autoAdditional = !widget.isAdditionalOrder &&
          autoParent != null &&
          autoParent.toString().isNotEmpty;
      if (autoAdditional) {
        // Nanatili ang customer sa Menu pagkatapos mag-order — ituring na
        // additional ang susunod na order sa parehong ticket.
        UserSession.isAdditionalOrder = true;
        UserSession.targetParentOrderId = autoParent.toString();
      } else {
        UserSession.isAdditionalOrder = widget.isAdditionalOrder ||
            (UserSession.isAdditionalOrder &&
                UserSession.targetParentOrderId != null);
      }
    }

    GlobalSocketListener.instance.registerTableIdentity(
      tableId: widget.tableId,
      tableNumber: widget.tableNumber ?? _chosenTableNumber,
    );

    _restoreCartFromStore();
    CustomerCartStore.revision.addListener(_onCartStoreChanged);
    CustomerOrderReset.epoch.addListener(_handleOrderReset);

    _fetchDatabaseCategories();
    _fetchLiveDatabaseMenu();
    _syncExistingOrdersForTable();
    if (!_isTakeoutSelected) {
      _fetchBillLockState();
    }
    _startHeartbeatTimer();
    _startStatusPollTimer();
    GlobalSocketListener.instance.start(context: context);
    // Cart tab mula sa Bill/Live Status: dito bubuksan ang cart para hindi
    // mawala ang kasalukuyang _orderCart ng Menu.
    MenuCartIntent.openCart.addListener(_handleOpenCartIntent);
    _handleOpenCartIntent();
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
      mode: _effectiveAdditional
          ? CustomerOrderMode.additionalOrder
          : CustomerOrderMode.newOrder,
      activeOrderId: UserSession.lastPlacedOrderId,
      linkedParentId: UserSession.targetParentOrderId ??
          UserSession.autoAdditionalParentId,
    );

    // Bagong pasok sa additional-order flow: i-reset ang popup dedupe ng
    // parent at sariling order para hindi barado ng lumang key ang susunod
    // na finished/declined update.
    if (_effectiveAdditional) {
      OrderEventRouter.instance.resetPopupDedupe(UserSession.targetParentOrderId);
      OrderEventRouter.instance.resetPopupDedupe(UserSession.autoAdditionalParentId);
      OrderEventRouter.instance.resetPopupDedupe(UserSession.lastPlacedOrderId);
    }
  }

  void _restoreCartFromStore() {
    _orderCart.clear();
    for (final CartLine line in CustomerCartStore.restore()) {
      final FoodItem item = FoodItem(
        itemDbId: line.itemDbId,
        name: line.name,
        price: line.price,
        categoryId: line.categoryId,
        isAvailable: line.isAvailable,
        imageUrl: line.imageUrl,
      );
      _orderCart[item] = line.quantity;
    }

    // Takeout: bagong cart cycle → tanungin muli ang New/Additional choice.
    if (_orderCart.isEmpty && _isTakeoutSelected) {
      _takeoutOrderTypeResolved = false;
      _takeoutChoseAdditional = false;
      _forceNewOrderMode = false;
    }
  }

  void _persistCart() {
    CustomerCartStore.save(
      _orderCart.entries.map(
        (entry) => CartLine(
          itemDbId: entry.key.itemDbId,
          name: entry.key.name,
          price: entry.key.price,
          categoryId: entry.key.categoryId,
          isAvailable: entry.key.isAvailable,
          imageUrl: entry.key.imageUrl,
          quantity: entry.value,
        ),
      ),
    );
  }

  void _onCartStoreChanged() {
    if (!mounted) return;
    setState(_restoreCartFromStore);
  }

  /// Kapag na-settle/na-decline ang ticket, i-reset ang additional-order state
  /// ng Menu instance na ito kahit `popUntil` lang ang nangyari (hindi na
  /// tumakbo ang `initState`). Kaya malinis na bagong order ang susunod.
  void _handleOrderReset() {
    if (!mounted) return;
    UserSession.isAdditionalOrder = false;
    UserSession.targetParentOrderId = null;
    UserSession.autoAdditionalParentId = null;
    UserSession.lastPlacedOrderId = null;
    UserSession.firstOrderId = null;
    _forceNewOrderMode = true;
    OrderingGate.invalidate();
    _polledOrderStatuses.clear();
    setState(() {});
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

  /// Takeout (Google sign-in) flow: manual order-type selection bago mag-checkout.
  ///
  /// - `new`        → bagong ticket (different ticket)
  /// - `additional` → idadagdag sa napiling unfinished takeout ticket (same ticket)
  /// - `view_tickets` → buksan ang My Tickets
  /// - `null`       → kinansela ng customer
  ///
  /// Kompakto na bottom sheet: walang mahabang paliwanag, at hindi lumalabas
  /// ang Additional Order kung wala pang existing ticket.
  Future<String?> _showTakeoutOrderTypeDialog({
    required bool hasOpenTickets,
  }) async {
    if (!mounted) return null;
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFFFFFDFA),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD8D0C2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Takeout order',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF203F35),
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Pumili kung paano ka mag-oorder.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF788078)),
                ),
                const SizedBox(height: 14),
                _buildTakeoutOption(
                  icon: Icons.add_circle_outline_rounded,
                  title: 'New Order',
                  subtitle: 'Bagong ticket',
                  onTap: () => Navigator.pop(sheetContext, 'new'),
                ),
                if (hasOpenTickets) ...<Widget>[
                  const SizedBox(height: 10),
                  _buildTakeoutOption(
                    icon: Icons.playlist_add_rounded,
                    title: 'Additional Order',
                    subtitle: 'Idagdag sa existing ticket',
                    onTap: () => Navigator.pop(sheetContext, 'additional'),
                  ),
                ],
                const SizedBox(height: 10),
                _buildTakeoutOption(
                  icon: Icons.receipt_long_rounded,
                  title: 'View My Tickets',
                  subtitle: 'Status ng mga orders',
                  onTap: () => Navigator.pop(sheetContext, 'view_tickets'),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => Navigator.pop(sheetContext, null),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Color(0xFF788078)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTakeoutOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F3EA),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5DCCB)),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFF203F35),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF203F35),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF788078),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFA47C3D),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Kunin ang bukas na takeout tickets ng session. Best-effort — empty list
  /// kung walang session, walang ticket, o bigo ang network.
  Future<List<dynamic>> _fetchOpenTakeoutTickets() async {
    final int tableId = _chosenTableNumber ?? 7;
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/api/v1/orders/unfinished?table_id=$tableId'),
            headers: _authHeaders,
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return <dynamic>[];

      final decoded = jsonDecode(response.body);
      final List raw = decoded['orders'] ?? decoded['data'] ?? <dynamic>[];
      // Karagdagang safety: kung may session id ang customer, i-filter lang
      // ang tickets ng session na 'yon (baka magkahalo ang virtual table).
      final int? sessionId = UserSession.activeSessionId ??
          int.tryParse(UserSession.sessionId ?? '');
      return raw.where((dynamic o) {
        if (o is! Map || sessionId == null) return o is Map;
        final dynamic orderSession = o['session_id'];
        if (orderSession == null) return true;
        return orderSession.toString() == sessionId.toString();
      }).toList();
    } catch (_) {
      return <dynamic>[];
    }
  }

  /// Pumili ng unfinished takeout ticket na pagdadaggan ng items.
  /// Na-scope sa kasalukuyang takeout table/session ng customer.
  Future<Map<dynamic, dynamic>?> _showTakeoutSelectTicketDialog({
    List<dynamic>? preloaded,
  }) async {
    final List<dynamic> ordersList =
        preloaded ?? await _fetchOpenTakeoutTickets();

    if (!mounted) return null;
    if (ordersList.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Wala pang existing takeout ticket. Gumawa muna ng New Order.',
            ),
            backgroundColor: Color(0xFF53766C),
          ),
        );
      return null;
    }

    return showTicketPickerDialog(
      context: context,
      orders: ordersList,
      title: 'Pumili ng Ticket',
      subtitle: 'Sa aling takeout ticket idadagdag ang mga items?',
    );
  }

  /// Takeout: listahan ng lahat ng orders (kabilang ang COMPLETED/PAID) mula
  /// sa secured session endpoint. Pwede itong buksan kahit walang laman ang cart.
  Future<void> _viewMyTickets() async {
    if (!mounted || _ticketsLoading) return;
    setState(() => _ticketsLoading = true);

    final Future<void> loader = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF203F35)),
        ),
      ),
    );

    List<dynamic> tickets = <dynamic>[];
    String? errorMessage;
    try {
      tickets = await CustomerTicketService.fetchRecentTickets();
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    }

    if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    await loader;
    if (!mounted) return;
    setState(() => _ticketsLoading = false);

    if (tickets.isEmpty) {
      final bool hasError = errorMessage != null;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              hasError
                  ? 'Hindi ma-load ang tickets ngayon. Subukan muli.'
                  : 'Wala ka pang order. Gumawa muna ng New Order para may ticket.',
            ),
            backgroundColor:
                hasError ? const Color(0xFF8E5136) : const Color(0xFF53766C),
          ),
        );
      return;
    }

    final Map<dynamic, dynamic>? selected = await showTicketPickerDialog(
      context: context,
      orders: tickets,
      title: 'My Tickets',
      subtitle: 'Pumili ng order para makita ang status at details.',
    );
    if (selected == null || !mounted) return;

    await _openTicketDetails(selected);
  }

  Future<void> _openTicketDetails(Map<dynamic, dynamic> ticket) async {
    final dynamic orderId = ticket['id'] ?? ticket['order_id'];
    final double totalAmount =
        double.tryParse(ticket['total_amount']?.toString() ?? '0') ?? 0.0;
    final List<dynamic> items = ticket['items'] is List
        ? List<dynamic>.from(ticket['items'] as List)
        : <dynamic>[];
    final bool isAdditional =
        ticket['is_additional_order'] == true ||
            ticket['parent_order_id'] != null ||
            ticket['order_type']?.toString() == 'ADDITIONAL';

    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => OrderStatusScreen(
          orderId: orderId,
          isTakeout: true,
          tableId: _chosenTableNumber ?? UserSession.activeTableId,
          totalAmount: totalAmount,
          isAdditionalOrder: isAdditional,
          initialOrderItems: items,
          initialNotes: (ticket['notes'] ?? '').toString(),
        ),
      ),
    );
  }

  Future<void> _openCartScreen() async {
    // Kung may laman ang cart, i-check ang gating bago payagang magpatuloy.
    // Kung wala, papayagan pa ring buksan ang Cart para makita ang active
    // tickets — kahit PREPARING na ang parent.
    if (!await _pruneUnavailableCartItems()) return;
    if (_orderCart.isNotEmpty && !await _ensureCanAddItems()) return;
    if (!mounted) return;

    // TAKE OUT: manual order type is kada cart cycle. "Additional" = same
    // ticket; "New" = hiwalay na bagong ticket.
    if (_isTakeoutSelected && _orderCart.isNotEmpty && !_takeoutOrderTypeResolved) {
      // Isang fetch lang: dito natin malalaman kung may existing ticket bago
      // ipakita ang Additional Order option.
      final List<dynamic> openTickets = await _fetchOpenTakeoutTickets();
      if (!mounted) return;
      final String? choice = await _showTakeoutOrderTypeDialog(
        hasOpenTickets: openTickets.isNotEmpty,
      );
      if (choice == null || !mounted) return;

      if (choice == 'view_tickets') {
        await _viewMyTickets();
        return;
      }

      if (choice == 'additional') {
        final Map<dynamic, dynamic>? ticket =
            await _showTakeoutSelectTicketDialog(preloaded: openTickets);
        if (ticket == null || !mounted) return;
        final dynamic parentId = ticket['id'] ?? ticket['order_id'];
        _takeoutChoseAdditional = true;
        UserSession.isAdditionalOrder = true;
        UserSession.targetParentOrderId = parentId?.toString();
        UserSession.autoAdditionalParentId = parentId;
      } else {
        _takeoutChoseAdditional = false;
        UserSession.isAdditionalOrder = false;
        UserSession.targetParentOrderId = null;
        UserSession.autoAdditionalParentId = null;
      }
      _takeoutOrderTypeResolved = true;
      setState(() {});
    }

    final Map<FoodItem, int>? updatedCart = await Navigator.push<Map<FoodItem, int>>(
      context,
      MaterialPageRoute(
        builder: (context) => ShoppingCartScreen(
          cart: _orderCart,
          total: _cartGrandTotal,
          tableId: _chosenTableNumber,
          isTakeout: _isTakeoutSelected,
          isAdditionalOrder: _effectiveAdditional,
        ),
      ),
    );

    if (updatedCart != null && mounted) {
      setState(() {
        _orderCart.clear();
        _orderCart.addAll(updatedCart);
      });
      _persistCart();
    }
  }

  /// Kapag naubusan ng stock ang item habang nasa cart, huwag hayaang
  /// mag-checkout. Ipaalam at alisin sa cart (kung pumayag ang customer).
  Future<bool> _pruneUnavailableCartItems() async {
    if (_orderCart.isEmpty || _menuRepository.isEmpty) return true;

    final Map<int, FoodItem> latestById = <int, FoodItem>{
      for (final FoodItem item in _menuRepository)
        if (item.itemDbId > 0) item.itemDbId: item,
    };
    final List<FoodItem> unavailable = _orderCart.keys
        .where((item) {
          final FoodItem? latest = latestById[item.itemDbId];
          return latest != null && !latest.isAvailable;
        })
        .toList(growable: false);

    if (unavailable.isEmpty) return true;
    if (!mounted) return false;

    final String names = unavailable.map((item) => item.name).join(', ');
    final bool? remove = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFFDFA),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Item sold out',
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF203F35)),
        ),
        content: Text(
          'Naubos na ang stock ng: $names.\n\nAalisin ba ito sa cart para makapagpatuloy?',
          style: const TextStyle(fontSize: 13, color: Color(0xFF203F35), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep', style: TextStyle(color: Color(0xFF788078))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF203F35)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Remove and continue',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (remove == true && mounted) {
      setState(() {
        for (final FoodItem item in unavailable) {
          _orderCart.remove(item);
        }
      });
      _persistCart();
      return true;
    }
    return false;
  }

  void _handleOpenCartIntent() {
    if (!MenuCartIntent.openCart.value) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!MenuCartIntent.consume()) return;
      _openCartScreen();
    });
  }

  /// Guard para hindi magdoble ang gate request/dialog kapag mabilis ang tap.
  bool _gateCheckInFlight = false;

  /// Pareho sa Order Type Selection ang gating bago magdagdag ng items:
  /// bill-requested at blocked ticket statuses.
  Future<bool> _ensureCanAddItems() async {
    // Takeout: hintayin muna ang manual New/Additional choice bago mag-gate.
    // Kapag "New Order" ang pipiliin, hiwalay na ticket kaya walang parent gate.
    if (_isTakeoutSelected && !_takeoutOrderTypeResolved) return true;
    if (!_effectiveAdditional) return true;
    if (_gateCheckInFlight) return false;
    _gateCheckInFlight = true;

    try {
      final int tableId = _chosenTableNumber ??
          UserSession.activeTableNumber ??
          UserSession.activeTableId ??
          7;
      final dynamic parentId = _activeParentOrderId;
      if (parentId == null || parentId.toString().trim().isEmpty) return true;

      final OrderingGateResult result = await OrderingGate.evaluate(
        tableId: tableId,
        parentOrderId: parentId,
      );

      if (!mounted || result.allowed) return true;

      if (result.isBillLocked) {
        await _showBillLockedDialog();
        return false;
      }

      if (result.isStatusBlocked) {
        final bool? proceed = await _showAdditionalOrderTransitionDialog(
          orderId: parentId,
          status: result.ticketStatus ?? 'PREPARING',
        );
        if (proceed == true) {
          _switchToNewOrderMode();
          return true;
        }
        return false;
      }

      return true;
    } finally {
      _gateCheckInFlight = false;
    }
  }

  Future<void> _showBillLockedDialog() async {
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
  }

  Future<bool?> _showAdditionalOrderTransitionDialog({
    required dynamic orderId,
    required String status,
  }) {
    final String orderCode = UserSession.formatOrderCode(orderId);
    return showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFFFDFA),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Additional Order Not Allowed',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF203F35),
            ),
          ),
          content: Text(
            'Order #$orderCode is currently $status, so it can no longer accept additional items. '
            'If you continue, your items will be placed as a NEW order instead.\n\n'
            'Are you sure you want to continue?',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF788078),
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF788078)),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF203F35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                'Continue as New Order',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _switchToNewOrderMode() {
    UserSession.isAdditionalOrder = false;
    UserSession.targetParentOrderId = null;
    UserSession.autoAdditionalParentId = null;
    UserSession.firstOrderId = null;
    _forceNewOrderMode = true;
    if (_isTakeoutSelected) {
      _takeoutOrderTypeResolved = true;
      _takeoutChoseAdditional = false;
    }
    OrderingGate.invalidate();
    if (mounted) setState(() {});
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

    // Huwag mag-pop-up habang nasa Order Type Selection (browsingTickets) ang
    // customer — listahan lang ang dapat makita doon.
    if (OrderContext.instance.mode == CustomerOrderMode.browsingTickets) {
      return;
    }
    
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

      final bool isAdd = _effectiveAdditional;
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
        orderId: (resolvedOrderId ?? UserSession.lastPlacedOrderId ?? '').toString(),
        // session_closed/session_cancelled event = tapos na ang buong table
        // session, kaya "Session Finished → Scan QR Again" ang ipakita.
        forceSessionFinished: true,
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
    MenuCartIntent.openCart.removeListener(_handleOpenCartIntent);
    CustomerCartStore.revision.removeListener(_onCartStoreChanged);
    CustomerOrderReset.epoch.removeListener(_handleOrderReset);
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
    // Spinner lang kapag wala pang laman, para hindi mag-flash ang buong menu
    // tuwing may stock update.
    if (mounted && _menuRepository.isEmpty) {
      setState(() {
        _isLoading = true;
        _menuError = null;
      });
    }

    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/v1/customer/menu')).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final Map<String, dynamic> decodedData = jsonDecode(response.body);
        final List menuList = decodedData['data'] ?? [];
        if (mounted && menuList.isNotEmpty) {
          setState(() {
            _menuRepository = menuList.map((item) => FoodItem.fromJson(item)).toList();
            _isLoading = false;
            _menuError = null;
          });
          return;
        }
      }
    } catch (_) {}

    if (!mounted) return;

    // Debug builds lang ang test data — sa release, dapat malinaw sa customer
    // na hindi available ang menu, at hindi mag-order ng pekeng item.
    if (kDebugMode && _menuRepository.isEmpty) {
      _loadFallbackSamples();
      return;
    }

    // Kung may dati nang menu (hal. stock refresh), huwag itong burahin.
    if (_menuRepository.isNotEmpty) return;

    setState(() {
      _isLoading = false;
      _menuError = 'Hindi ma-load ang menu ngayon. Check your connection and try again.';
    });
  }

  void _loadFallbackSamples() {
    if (!mounted) return;
    setState(() {
      _menuRepository = _testSamples;
      _isLoading = false;
      _menuError = null;
    });
  }

  void _retryLoadMenu() {
    _fetchLiveDatabaseMenu();
    _fetchDatabaseCategories();
  }

  Future<void> _handleQuantityTap(FoodItem item, int variance) async {
    if (variance > 0 && !item.isAvailable) {
      _showUnavailableSnack();
      return;
    }
    if (variance > 0 && !await _ensureCanAddItems()) return;
    if (!mounted) return;

    // Stock guard: basta pa lang tayo ay magdadagdag ng quantity na lumalampas
    // sa on-hand stock ng item, harangin muna bago mailipat sa cart.
    if (variance > 0) {
      final int currentQty = _orderCart[item] ?? 0;
      final int maxQty = item.stockQuantity ?? 999999;
      if (currentQty + variance > maxQty) {
        _showStockLimitSnack(maxQty);
        return;
      }
    }

    _modifyQuantity(item, variance);
  }

  void _showStockLimitSnack(int stockLimit) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Hindi kayang magdagdag ng higit sa stock. Hanggang sa stock limit lang (Stock: $stockLimit).',
          ),
          backgroundColor: const Color(0xFF8E5136),
        ),
      );
  }

  void _showUnavailableSnack() {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Sold out na ang item na ito. Please choose another dish.'),
          backgroundColor: Color(0xFF8E5136),
        ),
      );
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
    _persistCart();
  }

  double get _cartGrandTotal => _orderCart.entries.fold(0.0, (total, entry) => total + (entry.key.price * entry.value));

  /// Hindi na basta tumatalon sa Order Type Selection kapag pinindot ang back.
  /// Magtatanong muna, at kung walang ma-pop, saka lang sadyang babalik sa
  /// order options.
  Future<void> _confirmLeaveMenu() async {
    if (!mounted) return;
    final bool hasCart = _orderCart.isNotEmpty;

    final String? leave = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFFDFA),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          hasCart ? 'Leave without ordering?' : 'Leave the menu?',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF203F35)),
        ),
        content: Text(
          hasCart
              ? 'May laman pa ang cart mo. Mananatili ito hanggang makabalik ka sa menu.'
              : (_isTakeoutSelected
                  ? 'Babalik ka sa home. Kailangan mong mag-sign in muli para sa takeout.'
                  : 'Babalik ka sa order options.'),
          style: const TextStyle(fontSize: 13, color: Color(0xFF203F35), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'stay'),
            child: const Text('Continue ordering', style: TextStyle(color: Color(0xFF788078))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'welcome'),
            child: const Text(
              'Back to Welcome',
              style: TextStyle(color: Color(0xFF8E5136), fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF203F35)),
            onPressed: () => Navigator.pop(ctx, 'leave'),
            child: const Text(
              'Leave',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (leave == null || leave == 'stay' || !mounted) return;

    // Explicit na daan pabalik sa login/Welcome — kahit QR (manual) ang
    // pinanggalingan at kahit naka-restore ang session bilang root page.
    if (leave == 'welcome') {
      UserSession.clearSession();
      Navigator.of(context).pushAndRemoveUntil<void>(
        MaterialPageRoute<void>(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
      return;
    }

    if (_isTakeoutSelected) {
      final NavigatorState nav = Navigator.of(context);
      UserSession.clearSession();
      nav.pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const WelcomeScreen()),
        // Alisin lahat ng route (kasama ang Menu na naka-restore bilang home)
        // para hindi na makabalik ang customer sa lumang session gamit ang back.
        (route) => false,
      );
      return;
    }

    final NavigatorState nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
      return;
    }
    nav.pushReplacement(
      MaterialPageRoute(
        builder: (ctx) => OrderTypeSelectionScreen(
          tableNumber: _chosenTableNumber ?? 7,
          tableId: _chosenTableNumber ?? 7,
        ),
      ),
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

    return PopScope(
      canPop: _popScopeCanPop && _orderCart.isEmpty,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        _confirmLeaveMenu();
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
                  : (_menuError != null && _menuRepository.isEmpty)
                  ? _buildMenuErrorView()
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
            onTap: _confirmLeaveMenu,
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
              if (_isTakeoutSelected) ...[
                InkWell(
                  onTap: _viewMyTickets,
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE5DFD3)),
                    ),
                    child: const Icon(
                      Icons.receipt_long_outlined,
                      color: Color(0xFF203F35),
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
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

  Widget _buildMenuErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFEEE7D9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.restaurant_menu,
                size: 34,
                color: Color(0xFFA47C3D),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Menu unavailable',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF203F35),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _menuError ??
                  'Hindi ma-load ang menu ngayon. Please try again.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF788078),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF203F35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _retryLoadMenu,
              icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
              label: const Text(
                'Retry',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableContextStrip() {
    final bool takeout = _isTakeoutSelected;
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
                Icon(
                  takeout
                      ? Icons.shopping_bag_outlined
                      : Icons.check_circle_outline,
                  size: 14,
                  color: const Color(0xFF53766C),
                ),
                const SizedBox(width: 6),
                Text(
                  takeout
                      ? 'Takeout / Pickup • online order'
                      : (_chosenTableNumber != null
                          ? 'Table ${_chosenTableNumber.toString().padLeft(2, '0')} • verified'
                          : 'Table 07 • verified'),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Color(0xFF203F35)),
                ),
              ],
            ),
            Text(
              takeout ? 'Takeout' : 'Dine-in',
              style: const TextStyle(fontSize: 10, color: Color(0xFF788078), fontWeight: FontWeight.w500),
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
        // Bahagyang mas mataas para hindi mag-overflow kapag mahaba ang item
        // name o pinalaki ang font sa accessibility settings.
        childAspectRatio: 0.56,
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
                  onAddToCart: (item, qty, addOns) => _handleQuantityTap(item, qty),
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Flexible(
                                child: Text(foodItem.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF24382F)), maxLines: 2, overflow: TextOverflow.ellipsis),
                              ),
                              const SizedBox(height: 4),
                              Text(formatPeso(foodItem.price), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF203F35))),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: !foodItem.isAvailable
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEEE7D9),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'Sold out',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF8E5136)),
                                  ),
                                )
                              : productCount == 0
                              ? InkWell(
                                  onTap: () => _handleQuantityTap(foodItem, 1),
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
                                    IconButton(icon: const Icon(Icons.add, size: 14), onPressed: () => _handleQuantityTap(foodItem, 1)),
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
                onPressed: _openCartScreen,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('View Cart (${_orderCart.values.fold(0, (sum, q) => sum + q)} items)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(formatPeso(_cartGrandTotal, decimals: false), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
              ),
            ),
          ),
        CustomerBottomNav(
          activeTab: CustomerNavTab.menu,
          onMenu: () {},
          onCart: _openCartScreen,
          onLiveStatus: () {
            final dynamic activeLiveOrderId = UserSession.lastPlacedOrderId ?? UserSession.targetParentOrderId ?? UserSession.firstOrderId;
            Navigator.push(context, MaterialPageRoute(builder: (context) => OrderStatusScreen(orderId: activeLiveOrderId, isTakeout: _isTakeoutSelected, tableId: _chosenTableNumber, isAdditionalOrder: _effectiveAdditional)));
          },
          onBill: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (context) => SessionBillScreen(tableId: _chosenTableNumber, isTakeout: _isTakeoutSelected)));
            if (mounted) _fetchBillLockState();
          },
          showBill: !_isTakeoutSelected,
        ),
      ],
    );
  }
}
