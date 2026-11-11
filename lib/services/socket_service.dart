import 'package:flutter/widgets.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../models/user_session.dart';
import '../config/api_config.dart';

class SocketService with WidgetsBindingObserver {
  late io.Socket _socket;
  bool _isConnected = false;
  bool _joinAdminRooms = false;

  String get _baseUrl => ApiConfig.baseUrl;

  /// Ginagamit ang mismong _baseUrl para sa cloud/Render HTTPS deployments
  /// nang maiwasan ang maling port conversion o unsafe port errors.
  String get _socketUrl {
    return _baseUrl;
  }

  /// Normalizes an order/ticket ID (int o string, may kasamang '#BS-' o 'BS-'
  /// prefix) into isang canonical string upang hindi magulo ang integer vs string
  /// ticket formats (hal. int 12, '12', '#BS-0012', at 'BS-12' ay lahat ay '12').
  static String normalizeOrderId(dynamic orderId) {
    if (orderId == null) return '';
    final String stripped = orderId.toString().trim().replaceAll(RegExp(r'^#?BS-?', caseSensitive: false), '').trim();
    final int? parsed = int.tryParse(stripped);
    if (parsed != null) {
      return parsed.toString();
    }
    return stripped.toUpperCase();
  }

  /// Safe order/ticket comparison na umi-handle nang maayos ng integer at
  /// string ticket formats sa harap ng isa't isa.
  static bool isSameOrder(dynamic orderIdA, dynamic orderIdB) {
    final String normalizedA = normalizeOrderId(orderIdA);
    final String normalizedB = normalizeOrderId(orderIdB);
    if (normalizedA.isEmpty || normalizedB.isEmpty) return false;
    final int? intA = int.tryParse(normalizedA);
    final int? intB = int.tryParse(normalizedB);
    if (intA != null && intB != null) {
      return intA == intB;
    }
    return normalizedA == normalizedB;
  }

  void connect({
    Function(dynamic)? onOrderUpdated,
    Function(dynamic)? onStatusUpdated,
    Function(dynamic)? onSessionClosed,
    Function(dynamic)? onStockUpdated,
    Function(dynamic)? onBillRequested,
    bool joinAdminRooms = false,
  }) {
    _joinAdminRooms = joinAdminRooms;
    WidgetsBinding.instance.addObserver(this);
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

      _socket.onConnect((_) {
        _isConnected = true;
        debugPrint('⚡ [SocketService] Connected successfully to $_baseUrl (ID: ${_socket.id})');
        _rejoinRooms();
      });

      _socket.onConnectError((err) {
        _isConnected = false;
        debugPrint('❌ [SocketService] Connection Error to $_baseUrl: $err');
      });

      _socket.onError((err) {
        debugPrint('⚠️ [SocketService] Socket Error: $err');
      });

      _socket.onReconnect((attempt) {
        _isConnected = true;
        debugPrint('🔄 [SocketService] Reconnected successfully on attempt #$attempt');
        _rejoinRooms();
      });

      _socket.onReconnectAttempt((attempt) {
        debugPrint('⏳ [SocketService] Reconnection attempt #$attempt...');
      });

      _socket.onDisconnect((reason) {
        _isConnected = false;
        debugPrint('🔌 [SocketService] Disconnected from server. Reason: $reason');
      });

      if (onOrderUpdated != null) {
        _socket.on('order_updated', (data) => onOrderUpdated(data));
        _socket.on('additional_items_added', (data) => onOrderUpdated(data));
        _socket.on('new_order', (data) => onOrderUpdated(data));
      }

      if (onStatusUpdated != null) {
        _socket.on('order_status_updated', (data) => onStatusUpdated(data));
        _socket.on('orderStatusUpdated', (data) => onStatusUpdated(data));
        _socket.on('order_paid', (data) => onStatusUpdated(data));
        _socket.on('order_cancelled', (data) => onStatusUpdated(data));
      }

      // Dedicated handler para sa bill request events (hindi na ito dadaan sa
      // order status update para hindi malito ang live order tracking state).
      if (onBillRequested != null) {
        _socket.on('bill_requested', (data) => onBillRequested(data));
      }

      if (onSessionClosed != null) {
        _socket.on('table_session_closed', (data) => onSessionClosed(data));
        _socket.on('session_cancelled', (data) => onSessionClosed(data));
      }

      if (onStockUpdated != null) {
        _socket.on('stock_updated', (data) => onStockUpdated(data));
        _socket.on('menu_stock_updated', (data) => onStockUpdated(data));
      }

      _socket.connect();
    } catch (e) {
      debugPrint('❌ [SocketService] Initialization exception: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      try {
        if (!_isConnected) {
          _socket.connect();
        }
      } catch (e) {
        debugPrint('⚠️ [SocketService] Resume reconnect error: $e');
      }
      _rejoinRooms();
    }
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
      // Admin/kitchen monitoring rooms — kailangan ito para makarating pa rin
      // ang targeted emits ng backend kahit naka-scope na sa table/session.
      if (_joinAdminRooms) {
        joinRoom('admin_live_monitoring');
        joinRoom('kitchen_monitoring');
      }
    } catch (_) {}
  }

  void joinRoom(String roomName) {
    if (_isConnected) {
      _socket.emit('join_room', roomName);
      debugPrint('📂 [SocketService] Joined room: $roomName');
    } else {
      try {
        _socket.emit('join_room', roomName);
      } catch (_) {}
    }
  }

  void joinTableRoom(int tableId) {
    joinRoom('table_$tableId');
  }

  void joinSessionRoom(int sessionId) {
    joinRoom('session_$sessionId');
  }

  void joinOrderRoom(dynamic orderId) {
    if (orderId != null) {
      joinRoom('order_$orderId');
      joinRoom(orderId.toString());
    }
  }

  void leaveRoom(String roomName) {
    if (_isConnected) {
      _socket.emit('leave_room', roomName);
      debugPrint('📂 [SocketService] Left room: $roomName');
    }
  }

  void disconnect() {
    try {
      WidgetsBinding.instance.removeObserver(this);
      if (_joinAdminRooms) {
        leaveRoom('admin_live_monitoring');
        leaveRoom('kitchen_monitoring');
      }
      final int? tableId = UserSession.activeTableId ?? UserSession.activeTableNumber;
      if (tableId != null) {
        leaveRoom('table_$tableId');
      }
      final int? sessionId = UserSession.activeSessionId ?? int.tryParse(UserSession.sessionId ?? '');
      if (sessionId != null) {
        leaveRoom('session_$sessionId');
      }
      _socket.disconnect();
      _socket.dispose();
      _isConnected = false;
      debugPrint('🔌 [SocketService] Fully disconnected and cleaned up.');
    } catch (_) {}
  }
}