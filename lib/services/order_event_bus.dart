import 'package:flutter/foundation.dart';

/// Broadcast bus para sa mga screen na kailangang mag-refresh kapag may order
/// event. Dati, isang `setOnOrderStatusChanged` slot lang ang meron — kaya
/// nag-aagawan at nag-o-overwrite ang mga screen (lalo na sa
/// `pushReplacement`). Dito, bawat screen ay may sariling token.
class OrderEventBus {
  OrderEventBus._();

  static final OrderEventBus instance = OrderEventBus._();

  final Map<int, VoidCallback> _refreshListeners = <int, VoidCallback>{};
  int _seq = 0;

  int subscribeRefresh(VoidCallback callback) {
    final int token = ++_seq;
    _refreshListeners[token] = callback;
    return token;
  }

  void unsubscribe(int token) {
    _refreshListeners.remove(token);
  }

  void notifyRefresh() {
    for (final VoidCallback callback in List<VoidCallback>.of(_refreshListeners.values)) {
      try {
        callback();
      } catch (e) {
        debugPrint('⚠️ [OrderEventBus] refresh listener error: $e');
      }
    }
  }
}
