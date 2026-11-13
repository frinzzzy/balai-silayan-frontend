import 'package:flutter/foundation.dart';

import '../user_session.dart';

/// Isang linya sa customer cart. Hindi ito naka-depende sa `FoodItem` para
/// maiwasan ang circular import sa `menu_screen.dart`.
class CartLine {
  final int itemDbId;
  final String name;
  final double price;
  final int categoryId;
  final bool isAvailable;
  final String? imageUrl;
  final int quantity;

  const CartLine({
    required this.itemDbId,
    required this.name,
    required this.price,
    required this.categoryId,
    required this.quantity,
    this.isAvailable = true,
    this.imageUrl,
  });
}

/// Session-scoped na imbakan ng cart items.
///
/// Ang `_orderCart` sa `MenuScreen` ay local state lang, kaya kapag nagawa ng
/// bago ang Menu (hal. galing sa Live Status o Bill), nawawala ang laman nito.
/// Dito natin ito ini-save para ma-restore sa bagong Menu instance.
class CustomerCartStore {
  CustomerCartStore._();

  /// Nagbabago tuwing may save/clear. Nakikinig ang aktibong MenuScreen para
  /// agad na mag-refresh ang cart badge kapag may nagbago mula sa ibang screen.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static final Map<int, CartLine> _lines = <int, CartLine>{};
  static String? _savedKey;

  static String _currentKey() {
    final dynamic id = UserSession.activeSessionId ??
        UserSession.sessionId ??
        UserSession.activeTableId ??
        UserSession.activeTableNumber;
    return id?.toString() ?? 'default';
  }

  /// Ibinabalik ang naka-save na cart para sa kasalukuyang session/table.
  static List<CartLine> restore() {
    final String key = _currentKey();
    if (_savedKey != null && _savedKey != key) {
      // Ibang session/table na — huwag dalhin ang lumang cart.
      _lines.clear();
    }
    _savedKey = key;
    return _lines.values.toList(growable: false);
  }

  static void save(Iterable<CartLine> lines) {
    _savedKey = _currentKey();
    _lines
      ..clear()
      ..addEntries(lines.map((line) => MapEntry(line.itemDbId, line)));
    revision.value++;
  }

  static void clear() {
    _savedKey = _currentKey();
    if (_lines.isEmpty) return;
    _lines.clear();
    revision.value++;
  }

  static bool get isEmpty => _lines.isEmpty;
}
