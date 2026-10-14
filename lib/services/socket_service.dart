import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../models/user_session.dart';

class SocketService {
  late io.Socket _socket;
  bool _isConnected = false;

  String get _baseUrl {
    if (kIsWeb) return 'http://localhost:5000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5000';
    }
    return 'http://localhost:5000';
  }

  void connect({
    Function(dynamic)? onOrderUpdated,
    Function(dynamic)? onStatusUpdated,
    Function(dynamic)? onSessionClosed,
  }) {
    try {
      _socket = io.io(
        _baseUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .build(),
      );

      _socket.onConnect((_) {
        _isConnected = true;
        debugPrint('SocketService connected successfully.');

        // Auto join table room & session room if active
        if (UserSession.activeTableId != null) {
          joinTableRoom(UserSession.activeTableId!);
        }
        final int? sessionId = UserSession.activeSessionId ??
            int.tryParse(UserSession.sessionId ?? '');
        if (sessionId != null) {
          joinSessionRoom(sessionId);
        }
        if (UserSession.targetParentOrderId != null) {
          joinOrderRoom(UserSession.targetParentOrderId);
        }
      });

      _socket.onDisconnect((_) {
        _isConnected = false;
        debugPrint('SocketService disconnected.');
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
        _socket.on('bill_requested', (data) => onStatusUpdated(data));
      }

      if (onSessionClosed != null) {
        _socket.on('table_session_closed', (data) => onSessionClosed(data));
        _socket.on('session_cancelled', (data) => onSessionClosed(data));
      }

      _socket.connect();
    } catch (e) {
      debugPrint('SocketService initialization error: $e');
    }
  }

  void joinRoom(String roomName) {
    if (_isConnected) {
      _socket.emit('join_room', roomName);
      debugPrint('SocketService joined room: $roomName');
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
      debugPrint('SocketService left room: $roomName');
    }
  }

  void disconnect() {
    try {
      if (UserSession.activeTableId != null) {
        leaveRoom('table_${UserSession.activeTableId}');
      }
      final int? sessionId = UserSession.activeSessionId ??
          int.tryParse(UserSession.sessionId ?? '');
      if (sessionId != null) {
        leaveRoom('session_$sessionId');
      }
      _socket.disconnect();
      _socket.dispose();
      _isConnected = false;
      debugPrint('SocketService fully disconnected and cleaned up.');
    } catch (_) {}
  }
}
