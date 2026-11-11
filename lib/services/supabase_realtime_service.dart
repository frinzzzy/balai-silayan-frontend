import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/api_config.dart';
import '../user_session.dart';
import 'order_event_router.dart';

/// Live order updates mula sa Supabase Postgres (`public.orders`) gamit ang
/// **Postgres Changes (Realtime)** — hindi `broadcast` — dahil ang `orders`
/// table ay nasa Supabase Postgres na (DATABASE_URL ng backend ay galing doon).
///
/// Ang backend ay basta nag-UPDATE ng row sa DB (via pg Pool), at ang Supabase
/// Realtime ay awtomatikong nagpapa-fire ng event sa mga subscribed na client.
///
/// Hindi ito nakaka-wake ng patay na app (same limitation ng broadcast) — ang
/// FCM naman ang para sa killed-app. Pero para sa "app naka-background pero
/// buhay pa" (typical scenario ng customer notification), ito na ang pinakamadali.
class SupabaseRealtimeService {
  SupabaseRealtimeService._();

  static final SupabaseRealtimeService instance = SupabaseRealtimeService._();

  static const String ordersChannelName = 'orders-live';

  SupabaseClient? _client;
  RealtimeChannel? _channel;
  bool _started = false;
  int? _subscribedSessionId;

  Future<void> start() async {
    if (_started) {
      await _subscribeForCurrentSession();
      return;
    }

    final String url = ApiConfig.supabaseUrl;
    final String key = ApiConfig.supabaseAnonKey;
    if (url.isEmpty || key.isEmpty) {
      debugPrint('⚠️ [SupabaseRealtime] Walang credentials sa ApiConfig.');
      return;
    }

    _client = SupabaseClient(url, key);
    _started = true;
    await _subscribeForCurrentSession();
  }

  /// Tawagin pagkatapos ng bagong session (QR scan / new order) para
  /// mag-resubscribe sa tamang session-scoped na subscription.
  Future<void> onSessionChanged() async {
    if (!_started) return;
    final int? currentSessionId = UserSession.activeSessionId;
    if (currentSessionId == null) return;
    if (currentSessionId == _subscribedSessionId) return;
    await _subscribeForCurrentSession();
  }

  Future<void> _subscribeForCurrentSession() async {
    final int? sessionId = UserSession.activeSessionId;
    if (sessionId == null || sessionId <= 0) {
      debugPrint('⚠️ [SupabaseRealtime] Walang active session — hindi pa mag-subscribe.');
      return;
    }
    if (sessionId == _subscribedSessionId && _channel != null) return;

    await _unsubscribeChannel();

    try {
      final SupabaseClient client = _client!;

      final RealtimeChannel channel =
          client.channel('$ordersChannelName-$sessionId');

      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'orders',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'session_id',
          value: sessionId,
        ),
        callback: (PostgresChangePayload payload) {
          final Map<String, dynamic> row = payload.newRecord;
          if (row.isEmpty) return;

          // Double guard: isipin natin na ako mismo ang matching session.
          final dynamic rowSession = row['session_id'];
          if (rowSession != null &&
              int.tryParse(rowSession.toString()) != sessionId) {
            return;
          }

          final String status =
              (row['status'] ?? row['order_status'] ?? '').toString().trim();
          if (status.isEmpty) return;

          try {
            OrderEventRouter.instance.onOrderEvent(
              orderPayload: row,
              payload: row,
              eventType: 'supabase',
            );
          } catch (e) {
            debugPrint('⚠️ [SupabaseRealtime] dispatch error: $e');
          }
        },
      );

      // sync ang subscribe() sa supabase_flutter 2.x.
      channel.subscribe();
      _channel = channel;
      _subscribedSessionId = sessionId;
      debugPrint('✅ [SupabaseRealtime] Subscribed sa orders (session_id=$sessionId)');
    } catch (e) {
      debugPrint('⚠️ [SupabaseRealtime] Subscribe failed: $e');
    }
  }

  Future<void> _unsubscribeChannel() async {
    final RealtimeChannel? channel = _channel;
    _channel = null;
    _subscribedSessionId = null;
    if (channel == null) return;
    try {
      await channel.unsubscribe();
    } catch (_) {}
  }

  void stop() {
    _started = false;
    unawaited(_unsubscribeChannel());
  }
}
