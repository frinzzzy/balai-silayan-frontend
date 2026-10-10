class UserSession {
  static String? sessionId;
  static int? activeSessionId;
  static int? activeTableId;
  static int? activeTableNumber;
  static bool isTakeout = false;
  static String? qrToken;
  static String? authToken;
  static String? customerSessionToken;

  // ITAMA ITO: Dapat false kapag nagsisimula ng bagong sesyon o bagong order
  static bool isAdditionalOrder = false;

  static String? targetParentOrderId;
  static dynamic firstOrderId;
  static dynamic lastPlacedOrderId;
  static double lastPlacedOrderTotal = 0.0;
  static List<dynamic> lastPlacedOrderItems = [];

  static bool get isLoggedIn => authToken != null && authToken!.isNotEmpty;
  static bool get hasActiveSession =>
      activeSessionId != null || sessionId != null;

  static void setSession({
    int? tableId,
    int? tableNumber,
    int? sessionNum,
    String? token,
    String? qr,
    bool takeout = false,
  }) {
    activeTableId = tableId;
    activeTableNumber = tableNumber;
    activeSessionId = sessionNum;
    if (token != null) authToken = token;
    if (qr != null) qrToken = qr;
    isTakeout = takeout;
  }

  // Idinagdag ito para linisin ang order flags tuwing New Order ang pinipili
  static void resetForNewOrder() {
    isAdditionalOrder = false;
    targetParentOrderId = null;
    firstOrderId = null;
    lastPlacedOrderId = null;
    lastPlacedOrderTotal = 0.0;
    lastPlacedOrderItems = [];
  }

  static void clearSession() {
    sessionId = null;
    activeSessionId = null;
    activeTableId = null;
    activeTableNumber = null;
    isTakeout = false;
    qrToken = null;
    authToken = null;
    customerSessionToken = null;
    isAdditionalOrder = false; // Naka-reset din dito
    targetParentOrderId = null;
    firstOrderId = null;
    lastPlacedOrderId = null;
    lastPlacedOrderTotal = 0.0;
    lastPlacedOrderItems = [];
  }
}