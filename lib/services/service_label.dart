/// Shared labels para hindi na lumalabas ang virtual table/session number
/// (hal. 9090990) sa admin UI para sa Google takeout orders.
class ServiceLabel {
  const ServiceLabel._();

  /// Virtual table numbers assigned by customerAuth.ensureVirtualTable().
  /// Dine-in tables are only 1..15, kaya safe ang threshold na ito.
  static bool isVirtualTableNumber(int tableNumber) => tableNumber >= 900000;

  static String customerDisplay({
    String? customerName,
    String? customerEmail,
  }) {
    final String name = customerName?.trim() ?? '';
    final String email = customerEmail?.trim() ?? '';
    if (name.isNotEmpty && email.isNotEmpty) return '$name ($email)';
    if (name.isNotEmpty) return name;
    return email;
  }

  /// Label na ipinapakita sa admin cards, banners, at history.
  ///
  /// Takeout: `Takeout` o `Takeout — Name (email)`.
  /// Dine-in: `Table 07`.
  static String forAdmin({
    required bool isTakeout,
    required int tableNumber,
    String? customerName,
    String? customerEmail,
  }) {
    final bool takeout = isTakeout || isVirtualTableNumber(tableNumber);
    if (!takeout) {
      return 'Table ${tableNumber.toString().padLeft(2, '0')}';
    }
    final String who = customerDisplay(
      customerName: customerName,
      customerEmail: customerEmail,
    );
    return who.isEmpty ? 'Takeout' : 'Takeout — $who';
  }

  /// Mas maikling label para sa notification title (walang email).
  static String forAdminTitle({
    required bool isTakeout,
    required int tableNumber,
    String? customerName,
    String? customerEmail,
  }) {
    final bool takeout = isTakeout || isVirtualTableNumber(tableNumber);
    if (!takeout) {
      return 'Table ${tableNumber.toString().padLeft(2, '0')}';
    }
    final String name = customerName?.trim() ?? '';
    final String email = customerEmail?.trim() ?? '';
    final String who = name.isNotEmpty ? name : email;
    return who.isEmpty ? 'Takeout' : 'Takeout — $who';
  }
}
