import 'package:flutter/material.dart';

import '../menu_screen.dart';
import '../user_session.dart';

/// Sentral na paraan ng pagbabalik sa MenuScreen.
///
/// Kung may existing na `menu` route sa stack, doon lang babalik (popUntil) —
/// kaya hindi nawawala ang `_orderCart` at iba pang state. Kung wala, gagawa
/// ng bagong Menu na nagre-restore ng cart mula sa `CustomerCartStore`.
class CustomerNavigation {
  CustomerNavigation._();

  static void openMenu(
    BuildContext context, {
    int? tableId,
    int? tableNumber,
    bool isAdditionalOrder = false,
    bool resetOrderContext = false,
  }) {
    final NavigatorState navigator = Navigator.of(context);
    final int resolvedTable = tableId ??
        UserSession.activeTableId ??
        UserSession.activeTableNumber ??
        7;
    final int resolvedTableNumber =
        tableNumber ?? UserSession.activeTableNumber ?? resolvedTable;

    bool foundMenu = false;
    if (navigator.canPop()) {
      navigator.popUntil((route) {
        if (route.settings.name == 'menu') {
          foundMenu = true;
          return true;
        }
        // Huwag lalampas sa pinaka-unang route — delikado ang popUntil kapag
        // walang match (puwedeng mag-loop/pop lahat).
        return route.isFirst;
      });
    }

    if (foundMenu) return;

    navigator.pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => MenuScreen(
          tableId: resolvedTable,
          tableNumber: resolvedTableNumber,
          isAdditionalOrder: isAdditionalOrder,
          resetOrderContext: resetOrderContext,
        ),
        settings: const RouteSettings(name: 'menu'),
      ),
    );
  }
}
