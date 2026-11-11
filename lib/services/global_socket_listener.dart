import 'dart:async';

import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../models/user_session.dart';
import '../config/api_config.dart';
import 'audio_notification_service.dart';
import 'fcm_service.dart';
import 'order_event_router.dart';
import 'order_event_bus.dart';
import 'supabase_realtime_service.dart';

typedef GlobalOrderEventHandler = void Function(dynamic data);
typedef GlobalOrderStatusRefresh = void Function();
typedef GlobalStockRefresh = void Function();

/// Global Background Socket Listener for order status notifications.
/// Single socket connection for the whole app; UI screens just consume events.
/// Used after QR scan for aggressive notifications.
class GlobalSocketListener with WidgetsBindingObserver {
  GlobalSocketListener._() {
    // I-register ang app lifecycle observer para ma-recover agad ang socket
    // kapag bumalik ang app mula sa background/sleep (screen off).
    WidgetsBinding.instance.addObserver(this);
  }

  static final GlobalSocketListener instance = GlobalSocketListener._();

  io.Socket? _socket;
  bool _isConnected = false;
  bool _started = false;
  GlobalOrderEventHandler? _onOrderEvent;
  GlobalOrderStatusRefresh? _onOrderStatusChanged;
  GlobalStockRefresh? _onStockChanged;
  GlobalOrderEventHandler? _onSessionClosed;
  GlobalOrderEventHandler? _onBillRequested;
  GlobalOrderEventHandler? _fallbackOrderEventHandler;
  GlobalOrderStatusRefresh? _fallbackOrderStatusRefresh;
  GlobalOrderEventHandler? _fallbackOrderSessionClosed;

  /// Mga table identifier (PK `table_id` at display `table_number`) na
  /// kabilang sa kasalukuyang customer. Kailangan ito dahil may pagkakataong
  /// ang UI ay may table_number habang ang socket payload ay may table_id.
  final Set<int> _knownTableIds = <int>{};

  /// Mga room na naka-join na sa KASALUKUYANG connection (para hindi mag-spam
  /// ng join_room sa bawat event). Nililinis tuwing (re)connect.
  final Set<String> _joinedRooms = <String>{};

  DateTime? _lastStockHandledAt;

  String get _socketUrl {
    // Gagamitin ang mismong baseUrl (https://...) tulad ng SocketService.
    // MAHALAGA: Hindi ito iko-convert sa 'wss://' dahil ang Uri.parse('wss://host')
    // ay nagbabalik ng port 0 sa Dart, na nagdudulot ng 'wss://host:0/...' at
    // net::ERR_UNSAFE_PORT sa web. Ang socket_io_client mismo ang bahalang
    // mag-select ng wss transport kapag secure ang URL.
    return ApiConfig.baseUrl;
  }

  void start({BuildContext? context}) {
    // Ang `context` ay tinatanggap pa rin para compatible sa mga caller, pero
    // hindi na ito kailangan ng banners (root ScaffoldMessenger na ang gamit).
    if (_started) {
      // Idempotent start: kung naka-connect na o naka-set up na ang global
      // listener, huwag gumawa ng bago pang socket (i-rejoin lang ang rooms).
      _rejoinRooms();
      return;
    }
    _started = true;
    try {
      _socket = io.io(
        _socketUrl,
        io.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .setPath('/socket.io')
            .enableAutoConnect()
            .setReconnectionAttempts(99999)
            .setReconnectionDelay(1000)
            .setReconnectionDelayMax(5000)
            .build(),
      );

      _socket?.onConnect((_) {
        _isConnected = true;
        _joinedRooms.clear();
        debugPrint('⚡ [GlobalSocketListener] Connected successfully to $_socketUrl (ID: ${_socket?.id})');
        _rejoinRooms();
      });

      _socket?.onDisconnect((_) {
        _isConnected = false;
        debugPrint('🔌 [GlobalSocketListener] Disconnected from server.');
      });

      _socket?.onError((err) {
        debugPrint('⚠️ [GlobalSocketListener] Socket Error: $err');
      });

      _socket?.on('order_updated', (data) => _dispatchOrderEvent(data, 'updated'));
      _socket?.on('additional_items_added', (data) => _dispatchOrderEvent(data, 'additional'));
      _socket?.on('new_order', (data) => _dispatchOrderEvent(data, 'new'));
      _socket?.on('order_status_updated', (data) => _dispatchOrderEvent(data, 'status'));
      _socket?.on('orderStatusUpdated', (data) => _dispatchOrderEvent(data, 'status'));
      _socket?.on('order_paid', (data) => _dispatchOrderEvent(data, 'paid'));
      _socket?.on('order_cancelled', (data) => _dispatchOrderEvent(data, 'cancelled'));
      _socket?.on('bill_requested', (data) {
        try {
          if (data is Map) {
            final Map<String, dynamic> payload = Map<String, dynamic>.from(data);
            final dynamic orderId = payload['order_id'] ??
                payload['ticket_order_id'] ??
                payload['id'];
            final dynamic requestedAt =
                payload['bill_requested_at'] ?? payload['requested_at'];
            if (orderId != null && requestedAt != null) {
              UserSession.setTicketBillRequested(orderId, requestedAt);
            }
          }
        } catch (e) {
          debugPrint('⚠️ [GlobalSocketListener] bill state cache error: $e');
        }
        try {
          _notifyBillRequested(data);
        } catch (e) {
          debugPrint('⚠️ [GlobalSocketListener] bill_requested error: $e');
        }
        try {
          _onBillRequested?.call(data);
        } catch (e) {
          debugPrint('⚠️ [GlobalSocketListener] bill handler error: $e');
        }
        try {
          OrderEventBus.instance.notifyRefresh();
        } catch (_) {}
      });
      _socket?.on('bill_reopened', (data) {
        try {
          if (data is Map) {
            final Map<String, dynamic> payload = Map<String, dynamic>.from(data);
            final dynamic orderId = payload['order_id'] ??
                payload['ticket_order_id'] ??
                payload['id'];
            if (orderId != null) {
              UserSession.clearTicketBillRequested(orderId);
            }
          }
          OrderEventBus.instance.notifyRefresh();
        } catch (e) {
          debugPrint('⚠️ [GlobalSocketListener] bill_reopened error: $e');
        }
      });
      _socket?.on('table_session_closed', (data) {
        try {
          _notifySessionClosed(data);
        } catch (e) {
          debugPrint('⚠️ [GlobalSocketListener] session_closed error: $e');
        }
        try {
          (_onSessionClosed ?? _fallbackOrderSessionClosed)?.call(data);
        } catch (e) {
          debugPrint('⚠️ [GlobalSocketListener] session handler error: $e');
        }
      });
      _socket?.on('session_cancelled', (data) {
        try {
          _notifySessionClosed(data);
        } catch (e) {
          debugPrint('⚠️ [GlobalSocketListener] session_cancelled error: $e');
        }
        try {
          (_onSessionClosed ?? _fallbackOrderSessionClosed)?.call(data);
        } catch (e) {
          debugPrint('⚠️ [GlobalSocketListener] session handler error: $e');
        }
      });
      _socket?.on('stock_updated', (data) => _handleStockUpdate(data));
      _socket?.on('menu_stock_updated', (data) => _handleStockUpdate(data));

      _socket?.connect();
    } catch (e) {
      debugPrint('❌ [GlobalSocketListener] Initialization exception: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      debugPrint('🔄 [GlobalSocketListener] App resumed — sinusigurong connected ang socket...');
      // Kapag natutulog ang device, madalas na patay ang underlying websocket.
      // I-force ang reconnect kung disconnected, pagkatapos ay i-rejoin ang rooms.
      try {
        if (_socket != null && !_socket!.connected) {
          _socket!.connect();
        }
      } catch (e) {
        debugPrint('⚠️ [GlobalSocketListener] Resume reconnect error: $e');
      }
      _rejoinRooms();
    }
  }

  /// Nililinis ang dating table identity (hal. bagong QR scan / bagong table)
  /// para hindi mag-cross-talk ang events ng lumang table.
  void resetTableIdentity() => _knownTableIds.clear();

  /// Ipinaparehistro ang table identity (PK at display number) para tama ang
  /// pag-filter ng events kahit magkaiba ang format ng id na dala ng payload.
  void registerTableIdentity({int? tableId, int? tableNumber}) {
    if (tableId != null) _knownTableIds.add(tableId);
    if (tableNumber != null) _knownTableIds.add(tableNumber);
    final int? activeId = UserSession.activeTableId;
    final int? activeNumber = UserSession.activeTableNumber;
    if (activeId != null) _knownTableIds.add(activeId);
    if (activeNumber != null) _knownTableIds.add(activeNumber);
  }

  static int? _parseTableValue(dynamic value) {
    if (value == null) return null;
    return int.tryParse(value.toString().trim());
  }

  /// Tinutukoy kung ang isang event ay para sa kasalukuyang table/session ng
  /// customer. Permissive ito: hindi itinatapon ang event kapag walang malinaw
  /// na ebidensya ng mismatch (mas mabuting may notif kaysa mawala ito).
  bool isEventForCurrentTable(Map<String, dynamic> orderPayload, Map<String, dynamic> payload) {
    final int? eventTableId = _parseTableValue(orderPayload['table_id'] ?? payload['table_id']);
    final int? eventTableNumber = _parseTableValue(orderPayload['table_number'] ?? payload['table_number']);
    final dynamic eventSessionId = orderPayload['session_id'] ?? payload['session_id'];

    if (eventTableId == null && eventTableNumber == null) {
      // Walang table info — fallback sa session scoping kung meron.
      if (eventSessionId != null) {
        final int? currentSessionId = UserSession.activeSessionId ?? int.tryParse(UserSession.sessionId ?? '');
        final int? parsedEventSession = int.tryParse(eventSessionId.toString());
        if (currentSessionId != null && parsedEventSession != null && parsedEventSession != currentSessionId) {
          return false;
        }
      }
      return true;
    }

    final Set<int> known = <int>{
      ..._knownTableIds,
      if (UserSession.activeTableId != null) UserSession.activeTableId!,
      if (UserSession.activeTableNumber != null) UserSession.activeTableNumber!,
    };
    if (known.isEmpty) return true; // Walang alam na table — huwag itapon.

    if (eventTableId != null && known.contains(eventTableId)) return true;
    if (eventTableNumber != null && known.contains(eventTableNumber)) return true;
    return false;
  }

  void _dispatchOrderEvent(dynamic data, [String eventType = 'status']) {
    if (data == null) return;

    try {
      final Map<String, dynamic> payload = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
      final Map<String, dynamic> orderPayload = payload['order'] is Map ? Map<String, dynamic>.from(payload['order']) : payload;

      // Table/session scoping LANG dito. WALANG ticket filter — kaya ang notif ay
      // lumalabas para sa LAHAT ng tickets/orders ng table na ito, anong screen
      // man ang bukas (ito ang dating dahilan ng "isang notif lang").
      if (!isEventForCurrentTable(orderPayload, payload)) return;

      // Self-healing room join mula sa payload mismo (hindi lang sa UserSession).
      _selfHealRooms(orderPayload, payload);

      // CENTRAL POLICY — banner, pop-up policy, at refresh broadcast.
      OrderEventRouter.instance.onOrderEvent(
        orderPayload: orderPayload,
        payload: payload,
        eventType: eventType,
      );

      // Saka lang i-delegate sa screen para sa UI refresh (walang banner/pop-up;
      // ang OrderEventRouter na ang may hawak ng presentation).
      final handler = _onOrderEvent ?? _fallbackOrderEventHandler;
      if (handler != null) {
        handler(data);
      }
      try {
        _onOrderStatusChanged?.call();
      } catch (e) {
        debugPrint('⚠️ [GlobalSocketListener] status refresh error: $e');
      }
    } catch (e, stack) {
      // Exception isolation: isang masamang payload ay hindi dapat pumatay ng
      // buong socket stream.
      debugPrint('⚠️ [GlobalSocketListener] dispatch error ($eventType): $e\n$stack');
    }
  }

  void _selfHealRooms(Map<String, dynamic> orderPayload, Map<String, dynamic> payload) {
    try {
      final int? tableId = _parseTableValue(orderPayload['table_id'] ?? payload['table_id']);
      final int? sessionId = _parseTableValue(orderPayload['session_id'] ?? payload['session_id']);
      final dynamic orderId = orderPayload['order_id'] ?? orderPayload['id'] ?? payload['order_id'] ?? payload['id'];

      if (tableId != null) joinTableRoom(tableId);
      if (sessionId != null) joinSessionRoom(sessionId);
      if (orderId != null) joinOrderRoom(orderId);
    } catch (_) {}
  }

  void _notifyBillRequested(dynamic data) {
    if (data is! Map) return;
    final Map<String, dynamic> payload = Map<String, dynamic>.from(data);
    final dynamic orderId = payload['order_id'] ?? payload['id'];
    final String orderCode = orderId != null
        ? UserSession.formatOrderCode(orderId)
        : (payload['order_code']?.toString() ?? 'Bill');
    AudioNotificationService.showBillRequestedBanner(
      orderCode: orderCode,
      orderId: orderId,
      grandTotal: payload['grand_total'] ?? payload['total_amount'],
      tableId: _parseTableValue(payload['table_id']),
      sessionId: _parseTableValue(payload['session_id']),
    );
  }

  void _notifySessionClosed(dynamic data) {
    if (data is Map) {
      final Map<String, dynamic> payload = Map<String, dynamic>.from(data);
      final dynamic orderId = payload['order_id'] ?? payload['id'];
      final String orderCode = orderId != null
          ? UserSession.formatOrderCode(orderId)
          : (payload['order_code']?.toString() ?? 'Session');
      AudioNotificationService.showSessionClosedBanner(
        orderCode: orderCode,
        orderId: orderId,
        tableId: _parseTableValue(payload['table_id']),
        sessionId: _parseTableValue(payload['session_id']),
      );
    } else {
      AudioNotificationService.showSessionClosedBanner(orderCode: 'Session');
    }
  }

  void _handleStockUpdate(dynamic data) {
    // Dedupe: ang parehong stock update ay maaaring dumating sa dalawang event
    // name (stock_updated at menu_stock_updated). Iwasan ang dobleng refresh.
    final DateTime now = DateTime.now();
    if (_lastStockHandledAt != null && now.difference(_lastStockHandledAt!) < const Duration(milliseconds: 300)) {
      return;
    }
    _lastStockHandledAt = now;
    _onStockChanged?.call();
  }

  void _rejoinRooms() {
    try {
      final int? tableId = UserSession.activeTableId ?? UserSession.activeTableNumber;
      if (tableId != null) {
        joinTableRoom(tableId);
      }
      final int? sessionId = UserSession.activeSessionId ?? int.tryParse(UserSession.sessionId ?? '');
      if (sessionId != null) {
        joinSessionRoom(sessionId);
      }
      if (UserSession.targetParentOrderId != null) {
        joinOrderRoom(UserSession.targetParentOrderId);
      }
      if (UserSession.lastPlacedOrderId != null) {
        joinOrderRoom(UserSession.lastPlacedOrderId);
      }
    } catch (_) {}
  }

  void joinRoom(String roomName) {
    // Isang beses lang i-emit ang join_room per connection.
    if (!_joinedRooms.add(roomName)) return;
    try {
      _socket?.emit('join_room', roomName);
      debugPrint('📂 [GlobalSocketListener] Joined room: $roomName');
    } catch (_) {}
  }

  void joinTableRoom(int tableId) => joinRoom('table_$tableId');

  void joinSessionRoom(int sessionId) {
    joinRoom('session_$sessionId');
    // Supabase realtime subscription — auto re-subscribe sa bagong session.
    unawaited(SupabaseRealtimeService.instance.onSessionChanged());
    // I-re-register ang FCM token sa bagong session/table.
    unawaited(FcmService.registerCurrentSession());
  }

  void joinOrderRoom(dynamic orderId) {
    if (orderId != null) {
      joinRoom('order_$orderId');
      joinRoom(orderId.toString());
    }
  }

  void stop() {
    _started = false;
    _knownTableIds.clear();
    _joinedRooms.clear();
    try {
      final int? tableId = UserSession.activeTableId ?? UserSession.activeTableNumber;
      if (tableId != null) {
        leaveRoom('table_$tableId');
      }
      final int? sessionId = UserSession.activeSessionId ?? int.tryParse(UserSession.sessionId ?? '');
      if (sessionId != null) {
        leaveRoom('session_$sessionId');
      }
      _socket?.disconnect();
      _socket?.dispose();
      _isConnected = false;
      debugPrint('🔌 [GlobalSocketListener] Fully disconnected and cleaned up.');
    } catch (_) {}
  }

  void leaveRoom(String roomName) {
    if (_isConnected) {
      _socket?.emit('leave_room', roomName);
      debugPrint('📂 [GlobalSocketListener] Left room: $roomName');
    }
  }

  void setOnOrderEvent(GlobalOrderEventHandler? handler) => _onOrderEvent = handler;

  void setOnOrderStatusChanged(GlobalOrderStatusRefresh? cb) => _onOrderStatusChanged = cb;

  void setOnStockChanged(GlobalStockRefresh? cb) => _onStockChanged = cb;

  void setOnSessionClosed(GlobalOrderEventHandler? cb) => _onSessionClosed = cb;

  void setOnBillRequested(GlobalOrderEventHandler? cb) => _onBillRequested = cb;

  /// Default order event handler (ex: ang handler ng MenuScreen) na gagamitin
  /// kapag walang aktibong screen-level handler na naka-set (hal. kapag bumalik
  /// ang customer sa MenuScreen mula sa isang pushed screen tulad ng OrderStatus).
  GlobalOrderEventHandler? get defaultOrderEventHandler => _fallbackOrderEventHandler;

  GlobalOrderStatusRefresh? get defaultOrderStatusRefresh => _fallbackOrderStatusRefresh;

  void setFallbackOrderEventHandler(GlobalOrderEventHandler? handler) => _fallbackOrderEventHandler = handler;

  void setFallbackOrderStatusRefresh(GlobalOrderStatusRefresh? cb) => _fallbackOrderStatusRefresh = cb;

  GlobalOrderEventHandler? get defaultOrderSessionClosed => _fallbackOrderSessionClosed;

  void setFallbackOrderSessionClosed(GlobalOrderEventHandler? handler) => _fallbackOrderSessionClosed = handler;
}

/// Global Navigator observer na nagre-restore ng default order handlers
/// kapag may nag-pop na naglalayong magreveal ng isang screen (ex: nag-back
/// mula sa OrderStatusScreen papunta sa MenuScreen).
class GlobalOrderRouteObserver extends NavigatorObserver {
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // I-restore ang default order handlers (MenuScreen) kapag ang revealed
    // route ay ang MenuScreen, para mabuhay ulit ang notifications.
    if (previousRoute?.settings.name == 'menu') {
      GlobalSocketListener.instance.setOnOrderEvent(GlobalSocketListener.instance.defaultOrderEventHandler);
      GlobalSocketListener.instance.setOnOrderStatusChanged(GlobalSocketListener.instance.defaultOrderStatusRefresh);
      GlobalSocketListener.instance.setOnSessionClosed(GlobalSocketListener.instance.defaultOrderSessionClosed);
      GlobalSocketListener.instance.setOnBillRequested(null);
    }
  }
}
