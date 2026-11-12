import '../user_session.dart';

/// Isang source of truth para sa "ano ang ginagawa ng customer ngayon".
///
/// Dati ay mahilig mag-overload ang `UserSession.targetParentOrderId` (minsan
/// parent ticket, minsan bagong order id) kaya nagkakamali ang pag-decide kung
/// dapat mag-pop-up ng "Finished Order". Dito, hiwalay ang bawat konsepto.
enum CustomerOrderMode {
  /// Walang aktibong order flow.
  idle,

  /// Bagong order (hindi naka-link sa lumang ticket).
  newOrder,

  /// Additional order na naka-link sa isang parent ticket.
  additionalOrder,

  /// Tinitingnan ang isang ticket (OrderStatusScreen).
  viewingOrder,

  /// Nasa listahan ng unfinished tickets (OrderTypeSelectionScreen).
  browsingTickets,
}

class OrderContext {
  OrderContext._();

  static final OrderContext instance = OrderContext._();

  int _tokenSeq = 0;
  int _activeToken = 0;

  CustomerOrderMode _mode = CustomerOrderMode.idle;
  String? _activeOrderId;
  String? _linkedParentId;
  String? _viewingOrderId;
  String? _viewedParentId;

  CustomerOrderMode get mode => _mode;
  String? get activeOrderId => _activeOrderId;
  String? get linkedParentId => _linkedParentId;
  String? get viewingOrderId => _viewingOrderId;
  String? get viewedParentId => _viewedParentId;

  /// Nagre-register ng context. Bumabalik ng token na kailangang ipasa sa
  /// [leave]. Mahalaga ito sa `pushReplacement`: ang `initState` ng bagong
  /// screen ay tumatakbo BAGO ang `dispose` ng luma, kaya kapag stale ang
  /// token, hindi nito mabubura ang bagong context.
  int enter({
    required CustomerOrderMode mode,
    dynamic activeOrderId,
    dynamic linkedParentId,
    dynamic viewingOrderId,
    dynamic viewedParentId,
  }) {
    _activeToken = ++_tokenSeq;
    _mode = mode;
    _activeOrderId = _clean(activeOrderId);
    _linkedParentId = _clean(linkedParentId);
    _viewingOrderId = _clean(viewingOrderId);
    _viewedParentId = _clean(viewedParentId);
    return _activeToken;
  }

  /// Nag-uupdate ng context nang hindi nagpapalit ng token/owner.
  void update({
    dynamic activeOrderId,
    dynamic linkedParentId,
    dynamic viewingOrderId,
    dynamic viewedParentId,
  }) {
    final String? nextActive = _clean(activeOrderId);
    final String? nextLinked = _clean(linkedParentId);
    final String? nextViewing = _clean(viewingOrderId);
    final String? nextViewedParent = _clean(viewedParentId);
    if (nextActive != null) _activeOrderId = nextActive;
    if (nextLinked != null) _linkedParentId = nextLinked;
    if (nextViewing != null) _viewingOrderId = nextViewing;
    if (nextViewedParent != null) _viewedParentId = nextViewedParent;
  }

  /// Inalis ang context — pero tanging ang kasalukuyang owner lang.
  void leave(int token) {
    if (token != _activeToken) return; // stale dispose — huwag galawin
    _mode = CustomerOrderMode.idle;
    _activeOrderId = null;
    _linkedParentId = null;
    _viewingOrderId = null;
    _viewedParentId = null;
  }

  /// Ibinabalik ang context ng aktibong order flow mula sa `UserSession`.
  ///
  /// Ginagamit kapag bumalik ang customer sa MenuScreen mula sa isang pushed
  /// screen (hal. OrderStatusScreen/Cart). Kung hindi ito gawin, nagle-leave
  /// ang pushed screen at nagiging `idle` ang mode — kaya hindi na lumalabas
  /// ang finished/declined pop-up kahit nasa additional-order flow pa rin.
  void restoreFromSession() {
    if (UserSession.isAdditionalOrder) {
      enter(
        mode: CustomerOrderMode.additionalOrder,
        activeOrderId: UserSession.lastPlacedOrderId,
        linkedParentId: UserSession.targetParentOrderId,
      );
      return;
    }
    if (UserSession.lastPlacedOrderId != null) {
      enter(
        mode: CustomerOrderMode.newOrder,
        activeOrderId: UserSession.lastPlacedOrderId,
      );
      return;
    }
    reset();
  }

  /// Full reset (hal. bagong QR scan / session closed).
  void reset() {
    _activeToken = ++_tokenSeq;
    _mode = CustomerOrderMode.idle;
    _activeOrderId = null;
    _linkedParentId = null;
    _viewingOrderId = null;
    _viewedParentId = null;
  }

  /// Ang isang finished/declined event ba ay para sa ticket na kasalukuyang
  /// ginagawa o tinitingnan ng customer?
  ///
  /// - additionalOrder: parent ticket o ang sariling order
  /// - viewingOrder: ang tinitingnan, o ang parent nito
  /// - newOrder: sariling order lang (hindi kasama ang lumang ticket)
  bool isTicketRelevant(dynamic eventOrderId, {dynamic eventParentOrderId}) {
    final String? eventId = _clean(eventOrderId);
    if (eventId == null) return false;

    switch (_mode) {
      case CustomerOrderMode.additionalOrder:
        return eventId == _linkedParentId || eventId == _activeOrderId;

      case CustomerOrderMode.viewingOrder:
        if (eventId == _viewingOrderId) return true;
        if (eventId == _viewedParentId) return true;
        // Kung ang event ay parent din ng tinitingnang order.
        final String? eventParent = _clean(eventParentOrderId);
        if (eventParent != null && eventParent == _viewingOrderId) return true;
        return false;

      case CustomerOrderMode.newOrder:
        return eventId == _activeOrderId;

      case CustomerOrderMode.browsingTickets:
      case CustomerOrderMode.idle:
        return false;
    }
  }

  static String? _clean(dynamic value) {
    if (value == null) return null;
    final String raw = value.toString().trim();
    if (raw.isEmpty || raw.toLowerCase() == 'null') return null;
    final String stripped = raw
        .replaceAll(RegExp(r'^#?BS-?', caseSensitive: false), '')
        .trim();
    final int? numeric = int.tryParse(stripped);
    if (numeric != null) return numeric.toString();
    return stripped.toUpperCase();
  }
}
