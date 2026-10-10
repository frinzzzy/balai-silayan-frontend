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
  }
}
