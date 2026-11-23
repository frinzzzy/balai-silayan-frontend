import 'dart:async';

import 'package:flutter/foundation.dart';

import '../user_session.dart';
import 'session_persistence.dart';

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

  /// Para sa local persistence (mabuhay kahit i-kill ang app).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'itemDbId': itemDbId,
        'name': name,
        'price': price,
        'categoryId': categoryId,
        'isAvailable': isAvailable,
        'imageUrl': imageUrl,
        'quantity': quantity,
      };

  static CartLine? fromJson(Map<String, dynamic> json) {
    final int? id = int.tryParse('${json['itemDbId'] ?? ''}');
    final String name = '${json['name'] ?? ''}'.trim();
    if (id == null || name.isEmpty) return null;
    final double price =
        double.tryParse('${json['price'] ?? ''}') ?? 0.0;
    final int quantity = int.tryParse('${json['quantity'] ?? ''}') ?? 0;
    if (quantity <= 0) return null;
    return CartLine(
      itemDbId: id,
      name: name,
      price: price,
      categoryId: int.tryParse('${json['categoryId'] ?? ''}') ?? 0,
      quantity: quantity,
      isAvailable: json['isAvailable'] != false,
      imageUrl: json['imageUrl']?.toString(),
    );
  }
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
    _persistToDisk();
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
    _persistToDisk();
  }

  static void clear() {
    _savedKey = _currentKey();
    final bool hadNotes = _specialInstructions.isNotEmpty;
    final bool hadLines = _lines.isNotEmpty;
    if (hadNotes) {
      _specialInstructions = '';
      specialInstructionsNotifier.value = '';
    }
    if (!hadLines && !hadNotes) return;
    _lines.clear();
    revision.value++;
    _persistToDisk();
  }

  /// Isinusulat sa `SharedPreferences` ang cart at notes para mabuhay kahit
  /// ma-kill ang app.
  static void _persistToDisk() {
    unawaited(
      SessionPersistence.instance.saveCart(
        _currentKey(),
        _lines.values.map((line) => line.toJson()).toList(growable: false),
        _specialInstructions,
      ),
    );
  }

  /// Ibinabalik ang cart mula sa `SharedPreferences`. Tinatawag ito ng
  /// `SessionBootstrap` bago mag-`runApp`.
  static Future<void> restoreFromDisk() async {
    final String key = _currentKey();
    final List<Map<String, dynamic>> raw =
        await SessionPersistence.instance.loadCart(key);
    if (raw.isEmpty) {
      _savedKey = key;
      return;
    }
    final String notes = await SessionPersistence.instance.loadNotes(key);
    _lines.clear();
    for (final Map<String, dynamic> row in raw) {
      final CartLine? line = CartLine.fromJson(row);
      if (line != null) _lines[line.itemDbId] = line;
    }
    _specialInstructions = notes;
    specialInstructionsNotifier.value = notes;
    _savedKey = key;
    revision.value++;
  }

  static bool get isEmpty => _lines.isEmpty;
}
