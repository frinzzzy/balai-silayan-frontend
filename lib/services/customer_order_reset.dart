import 'package:flutter/foundation.dart';

/// Signal para i-reset ng aktibong `MenuScreen` ang additional-order state
/// nito kahit `popUntil` lang ang nangyari (hindi na tumatakbo ang `initState`).
///
/// Ginagamit ito kapag na-settle/na-decline ang ticket: kailangang maging
/// malinis na bagong order ang susunod na add, kahit ang Menu instance ay
/// ginawa pa bilang additional order.
class CustomerOrderReset {
  CustomerOrderReset._();

  /// Tumaas ang value tuwing may nagre-request ng reset.
  static final ValueNotifier<int> epoch = ValueNotifier<int>(0);

  static void request() {
    epoch.value++;
  }
}
