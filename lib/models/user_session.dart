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

  static String? get activeSessionToken => customerSessionToken ?? authToken;

  static void clearSession() {
    sessionId = null;
    activeSessionId = null;
    activeTableId = null;
    activeTableNumber = null;
    isTakeout = false;
    qrToken = null;
    authToken = null;
    customerSessionToken = null;
    isAdditionalOrder = false;
    targetParentOrderId = null;
    firstOrderId = null;
  }
}
