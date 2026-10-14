class UserSession {
  static String? sessionId;
  static int? activeSessionId;
  static int? activeTableId;
  static int? activeTableNumber;
  static bool isTakeout = false;
  static String? qrToken;
  static String? authToken;
  static String? customerSessionToken;

  static bool isAdditionalOrder = false;
  static String? targetParentOrderId;
  static dynamic firstOrderId;
  static dynamic lastPlacedOrderId;
  static double lastPlacedOrderTotal = 0.0;
  static List<dynamic> lastPlacedOrderItems = [];

  static bool get isLoggedIn => authToken != null && authToken!.isNotEmpty;

  static String formatOrderCode(dynamic orderId) {
    if (orderId == null) return '#BS-0001';
    final str = orderId.toString().trim();
    if (str.startsWith('#')) return str;

    final intVal = int.tryParse(str);
    if (intVal != null) {
      if (intVal > 9999) {
        final code = intVal.toRadixString(36).toUpperCase().padLeft(5, '0');
        return '#BS-$code';
      }
      return '#BS-${intVal.toString().padLeft(4, '0')}';
    }

    final cleanStr = str.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    return '#BS-${cleanStr.length > 5 ? cleanStr.substring(0, 5) : cleanStr.padLeft(5, '0')}';
  }

  // Pinatibay na check para sa active session
  static bool get hasActiveSession =>
      (activeSessionId != null && activeSessionId! > 0) ||
          (sessionId != null && sessionId!.isNotEmpty);

  // Pinag-isang getter para sa lahat ng uri ng active token
  static String? get activeSessionToken =>
      customerSessionToken ?? authToken ?? qrToken;

  // Pinatibay na setSession para masigurong nasasalo kahit anong format ng ID o token
  static void setSession({
    int? tableId,
    int? tableNumber,
    dynamic sessionNum,
    String? token,
    String? qr,
    bool takeout = false,
  }) {
    if (tableId != null) activeTableId = tableId;
    if (tableNumber != null) {
      activeTableNumber = tableNumber;
    } else if (tableId != null) {
      activeTableNumber = tableId;
    }

    if (sessionNum != null) {
      activeSessionId = sessionNum is int ? sessionNum : int.tryParse(sessionNum.toString());
      sessionId = activeSessionId?.toString();
    }

    if (token != null && token.isNotEmpty) {
      customerSessionToken = token;
      authToken = token;
    }
    if (qr != null && qr.isNotEmpty) {
      qrToken = qr;
    }
    isTakeout = takeout;
  }

  // Ginagamit pagkatapos mag-submit ng order para i-store ang huling order details
  static void setLastPlacedOrder({
    required dynamic orderId,
    required double total,
    List<dynamic>? items,
  }) {
    lastPlacedOrderId = orderId;
    lastPlacedOrderTotal = total;
    if (items != null) {
      lastPlacedOrderItems = items;
    }
  }

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
    resetForNewOrder();
  }
}