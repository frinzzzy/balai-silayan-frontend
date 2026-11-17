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

  /// Order-level special instructions (hal. "Allergic to peanuts").
  /// Isang note lang kada ticket, kaya kasama ito sa cart store para hindi
  /// mawala kapag nag-navigate sa pagitan ng Menu, Cart, at Checkout.
  static final ValueNotifier<String> specialInstructionsNotifier =
      ValueNotifier<String>('');
  static String _specialInstructions = '';

  static String get specialInstructions => _specialInstructions;

  static void setSpecialInstructions(String value) {
    final String normalized = value.trim();
    if (normalized == _specialInstructions) return;
    _specialInstructions = normalized;
    specialInstructionsNotifier.value = normalized;
  }

  static String _currentKey() {
    // Table id ang primary key: stable ito kahit magbago ang session id
    // (hal. bagong session pagkatapos mag-request ng bill o mag-reconnect).
    // Dati ay session id ang nauuna, kaya nawawala ang cart sa gitna ng order
    // kapag nag-refresh ang session.
    final dynamic tableId =
        UserSession.activeTableId ?? UserSession.activeTableNumber;
    if (tableId != null) return 'table:$tableId';

    final dynamic sessionId =
        UserSession.activeSessionId ?? UserSession.sessionId;
    return sessionId != null ? 'session:$sessionId' : 'default';
  }

  /// Ibinabalik ang naka-save na cart para sa kasalukuyang session/table.
  static List<CartLine> restore() {
    final String key = _currentKey();
    if (_savedKey != null && _savedKey != key) {
      // Ibang session/table na — huwag dalhin ang lumang cart.
      _lines.clear();
      _specialInstructions = '';
      specialInstructionsNotifier.value = '';
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
    final bool hadNotes = _specialInstructions.isNotEmpty;
    if (hadNotes) {
      _specialInstructions = '';
      specialInstructionsNotifier.value = '';
    }
    if (_lines.isEmpty) return;
    _lines.clear();
    revision.value++;
  }

  static bool get isEmpty => _lines.isEmpty;
}
