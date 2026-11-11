import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import '../user_session.dart';
import 'notification_center.dart';

class NotificationRecord {
  final String title;
  final String message;
  final DateTime timestamp;
  final Color backgroundColor;
  final IconData icon;

  /// Optional grouping key para sa Notification History. Kapag null, gagamitin
  /// ang ticket code na naka-extract mula sa title (legacy behavior).
  final String? groupKey;

  NotificationRecord({
    required this.title,
    required this.message,
    required this.timestamp,
    required this.backgroundColor,
    required this.icon,
    this.groupKey,
  });
}

class AudioNotificationService {
  static final AudioPlayer _audioPlayer = AudioPlayer();
  static final List<NotificationRecord> history = [];

  /// Bilang ng notifications na hindi pa nakikita sa Notification History.
  static int unseenHistoryCount = 0;

  static void markHistorySeen() => unseenHistoryCount = 0;

  static final Map<String, NotificationPayload> _pendingBanners =
      <String, NotificationPayload>{};
  static const int _maxPendingBanners = 20;

  /// Root messenger key — fallback lang ito. Ang pangunahing presentation ay
  /// overlay-based na (NotificationCenter).
  static GlobalKey<ScaffoldMessengerState> get messengerKey =>
      NotificationCenter.messengerKey;

  // Deduplication lock variables
  static String _lastBannerSignature = "";
  static DateTime _lastBannerTimestamp = DateTime.fromMillisecondsSinceEpoch(0);

  /// Foreground/background state ng app. Pinop ito ng [NotificationLifecycleObserver]
  /// (registered sa main) — kapag background, gumagamit ng system notification
  /// ang presentation instead of the in-app overlay banner.
  static bool _isAppInForeground = true;
  static bool get isAppInForeground => _isAppInForeground;
  static void setAppInForeground(bool value) => _isAppInForeground = value;

  /// Android 8.0+ notification channel — kailangan gawa bago mag-send ng
  /// system notification (walang channel, hindi lalabas ang notification).
  static const String orderNotificationChannelId = 'balai_silayan_orders';
  static const String orderNotificationChannelName =
      'Balai Silayan Order Alerts';

  /// I-initialize ang flutter_local_notifications: notification channel +
  /// Android plugin init. Ito ang dapat i-call bago mag-show ng notification.
  static Future<void> initializeLocalNotifications() async {
    try {
      final FlutterLocalNotificationsPlugin plugin =
          FlutterLocalNotificationsPlugin();
      await plugin.initialize(
        settings: InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      debugPrint(
        '✅ [AudioNotificationService] Local notifications initialized.',
      );
    } catch (e) {
      debugPrint(
        '⚠️ [AudioNotificationService] Local notifications init failed: $e',
      );
    }
  }

  /// Request ang POST_NOTIFICATIONS permission (Android 13+) para sa system
  /// notifications kapag background ang app.
  static Future<bool> requestNotificationPermission() async {
    try {
      final PermissionStatus status = await Permission.notification.request();
      return status.isGranted;
    } catch (e) {
      debugPrint('⚠️ [NotificationPermission] request failed: $e');
      return false;
    }
  }

  /// Show system-level notification (flutter_local_notifications) — ipinakita
  /// ito kapag background ang app (overlay ay hindi mag-render sa background).
  static Future<void> showSystemNotification({
    required String title,
    required String message,
    required Color backgroundColor,
    required IconData icon,
    String? orderId,
  }) async {
    try {
      final FlutterLocalNotificationsPlugin plugin =
          FlutterLocalNotificationsPlugin();
      final int notificationId = (orderId ?? title).hashCode;
      await plugin.show(
        id: notificationId,
        title: title,
        body: message,
        notificationDetails: NotificationDetails(
          android: const AndroidNotificationDetails(
            orderNotificationChannelId,
            orderNotificationChannelName,
            channelDescription: 'Balai Silayan order status alerts',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            icon: 'ic_stat_balai',
          ),
        ),
        payload: orderId,
      );
    } catch (e) {
      debugPrint('⚠️ [AudioNotificationService] system notification error: $e');
    }
  }

  /// Tinatawag kapag bagong table/session (hal. bagong QR scan) para hindi
  /// ma-block ng dating status ang mga bagong notification.
  static void resetOrderNotificationDedupe() =>
      NotificationCenter.instance.resetDedupe();

  /// Play sound chime and trigger built-in haptic vibration
  static Future<void> playStatusAlertSound() async {
    try {
      if (kIsWeb) {
        await _audioPlayer.stop();
        try {
          await _audioPlayer.play(
            UrlSource(
              'https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3',
            ),
            volume: 1.0,
          );
        } catch (_) {
          await _audioPlayer.play(
            AssetSource('sounds/notification_ring.mp3'),
            volume: 1.0,
          );
        }
      } else {
        await _audioPlayer.stop();
        await _audioPlayer.play(
          AssetSource('sounds/notification_ring.mp3'),
          volume: 1.0,
        );
      }
    } catch (e) {
      debugPrint("Error playing notification sound: $e");
    }

    try {
      HapticFeedback.vibrate();
    } catch (_) {}
  }

  /// Show an aggressive banner overlay notification and store in history (newest at top)
  static void showAggressiveBanner({
    required BuildContext context,
    required String title,
    required String message,
    required Color backgroundColor,
    IconData icon = Icons.notifications_active,
  }) {
    final String currentSignature = "$title|$message";
    final DateTime now = DateTime.now();

    // DEDUPLICATION LOCK: Prevent multiple active socket listeners from
    // triggering the exact same banner within 1000 milliseconds.
    if (_lastBannerSignature == currentSignature &&
        now.difference(_lastBannerTimestamp).inMilliseconds < 1000) {
      return; // Silently ignore duplicate request
    }

    _lastBannerSignature = currentSignature;
    _lastBannerTimestamp = now;

    unawaited(
      _presentBanner(
        title: title,
        message: message,
        backgroundColor: backgroundColor,
        icon: icon,
      ),
    );
  }

  /// Central order-status banner. Ito ang TANGING source of truth para sa
  /// customer notifications — tinatawag mula sa GlobalSocketListener at sa
  /// polling fallback. Sakop ang LAHAT ng status (may generic fallback).
  static bool showOrderStatusBanner({
    required String status,
    required String orderCode,
    dynamic orderId,
    String? reason,
    int? tableId,
    int? sessionId,
    String? eventType,
  }) {
    final String normalized = status.trim().toUpperCase();
    if (normalized.isEmpty) return false;

    final String sessionKey =
        (UserSession.activeSessionId ?? UserSession.sessionId ?? '').toString();
    final String dedupeKey =
        'status|$sessionKey|${orderId ?? orderCode}|$normalized';

    String title;
    String message;
    Color background;
    IconData icon;

    switch (normalized) {
      case 'NEW':
      case 'PENDING':
        title = '$orderCode: New Order';
        message = 'A new order has been received for your table.';
        background = const Color(0xFF8B5CF6);
        icon = Icons.fastfood;
        break;
      case 'PREPARING':
      case 'IN_PROGRESS':
        title = '$orderCode: Order Status: PREPARING';
        message = 'The kitchen is now preparing your delicious meal.';
        background = const Color(0xFFD7BC86);
        icon = Icons.kitchen;
        break;
      case 'READY':
        title = '$orderCode: Order Status: READY';
        message = 'Your order is ready for pickup / service.';
        background = const Color(0xFF22C55E);
        icon = Icons.restaurant;
        break;
      case 'SERVED':
        title = '$orderCode: Order Status: SERVED';
        message = 'Your order is hot and ready for your table.';
        background = const Color(0xFF22C55E);
        icon = Icons.restaurant;
        break;
      case 'COMPLETED':
      case 'PAID':
      case 'CLOSED':
      case 'SETTLED':
        title = '$orderCode: Payment Completed';
        message = 'Your table session receipt has been settled.';
        background = const Color(0xFF10B981);
        icon = Icons.check_circle;
        break;
      case 'DECLINED':
      case 'REJECTED':
      case 'CANCELLED':
        title = '$orderCode: Order Status: DECLINED';
        message = (reason != null && reason.trim().isNotEmpty)
            ? 'Reason: $reason'
            : 'Please check with staff for details.';
        background = const Color(0xFFEF4444);
        icon = Icons.cancel;
        break;
      default:
        title = '$orderCode: Order Status: $normalized';
        message = 'Your order status changed to $normalized.';
        background = const Color(0xFF203F35);
        icon = Icons.restaurant_menu;
    }

    final NotificationPayload payload = NotificationPayload(
      title: title,
      message: message,
      backgroundColor: background,
      icon: icon,
      duration: const Duration(seconds: 4),
    );

    // Background handling — bago pa man ang dedupe consumption, para hindi
    // mawala ang banner na in-queue (web) o inagad sa system notification (mobile).
    if (!_isAppInForeground) {
      // Web background tab: i-queue; i-flush ito ng flushPendingBanners sa resume.
      if (kIsWeb) {
        if (_pendingBanners.length >= _maxPendingBanners) {
          _pendingBanners.remove(_pendingBanners.keys.first);
        }
        _pendingBanners[dedupeKey] = payload;
        return true;
      }

      unawaited(
        (() async {
          final PermissionStatus notificationStatus =
              await Permission.notification.status;
          if (notificationStatus.isGranted) {
            if (!NotificationCenter.instance.shouldNotify(dedupeKey)) return;
            unawaited(playStatusAlertSound());
            _insertOrUpdateRecord(
              NotificationRecord(
                title: title,
                message: message,
                timestamp: DateTime.now(),
                backgroundColor: background,
                icon: icon,
              ),
            );
            await showSystemNotification(
              title: title,
              message: message,
              backgroundColor: background,
              icon: icon,
              orderId: orderId?.toString() ?? orderCode,
            );
          } else {
            _pendingBanners[dedupeKey] = payload;
          }
        })(),
      );
      return true;
    }

    // Foreground lang dito — single dedupe check, per status key.
    if (!NotificationCenter.instance.shouldNotify(dedupeKey)) return false;

    _presentBanner(
      title: title,
      message: message,
      backgroundColor: background,
      icon: icon,
    );
    return true;
  }

  static void flushPendingBanners() {
    if (_pendingBanners.isEmpty) return;
    final List<MapEntry<String, NotificationPayload>> entries = _pendingBanners
        .entries
        .toList();
    _pendingBanners.clear();
    for (final entry in entries) {
      if (!NotificationCenter.instance.shouldNotify(entry.key)) continue;
      // I-replay ito pinaagi ng _presentBanner para hindi mawawala ang sound +
      // notification history (kung direktang NotificationCenter.instance.show lang).
      _presentBanner(
        title: entry.value.title,
        message: entry.value.message,
        backgroundColor: entry.value.backgroundColor,
        icon: entry.value.icon,
        dedupeKey: entry.key,
        groupKey: entry.value.groupKey,
      );
    }
  }

  /// Banner kapag nag-request ng bill ang customer.
  static bool showBillRequestedBanner({
    required String orderCode,
    dynamic orderId,
    dynamic grandTotal,
    int? tableId,
    int? sessionId,
  }) {
    final String sessionKey =
        (UserSession.activeSessionId ?? UserSession.sessionId ?? '').toString();
    final String dedupeKey = 'bill|$sessionKey|${orderId ?? orderCode}';
    if (!NotificationCenter.instance.shouldNotify(dedupeKey)) return false;

    final String total =
        (grandTotal != null && grandTotal.toString().isNotEmpty)
        ? ' Total: ₱$grandTotal'
        : '';
    unawaited(
      _presentBanner(
        title: '$orderCode: Bill Requested',
        message: 'Naipadala na ang request ninyong bill sa staff.$total',
        backgroundColor: const Color(0xFF0EA5E9),
        icon: Icons.receipt_long,
      ),
    );
    return true;
  }

  /// Banner kapag natapos/na-settle na ang buong table session.
  static bool showSessionClosedBanner({
    required String orderCode,
    dynamic orderId,
    int? tableId,
    int? sessionId,
  }) {
    final String sessionKey =
        (UserSession.activeSessionId ?? UserSession.sessionId ?? '').toString();
    final String dedupeKey =
        'session_closed|$sessionKey|${orderId ?? orderCode}';
    if (!NotificationCenter.instance.shouldNotify(dedupeKey)) return false;

    unawaited(
      _presentBanner(
        title: 'Session Closed',
        message: 'Na-settle na ang inyong table session. Salamat po!',
        backgroundColor: const Color(0xFF10B981),
        icon: Icons.verified,
      ),
    );
    return true;
  }

  /// Banner para sa admin kapag may customer na nag-request ng bill.
  /// Dedupe key: `admin_bill|sessionId|billRequestedAt` — kaya refresh, back,
  /// o tab switch ay hindi nagdodoble ng notification para sa parehong request.
  static bool showAdminBillRequestedBanner({
    required int tableNumber,
    int? sessionId,
    int? orderId,
    int? parentOrderId,
    DateTime? billRequestedAt,
    dynamic grandTotal,
    String? customerName,
  }) {
    final String requestStamp = billRequestedAt != null
        ? billRequestedAt.toUtc().toIso8601String().substring(0, 19)
        : 'no_timestamp';
    final String sessionKey = sessionId != null && sessionId > 0
        ? 'session_$sessionId'
        : 'table_$tableNumber';
    // Isang alert lang per root ticket — kahit parent at child tickets ang
    // mag-request ng bill sa parehong oras.
    final int? rootOrderId = parentOrderId != null && parentOrderId > 0
        ? parentOrderId
        : orderId;
    final String ticketKey = rootOrderId != null && rootOrderId > 0
        ? 'order_$rootOrderId'
        : 'order_any';
    final String dedupeKey = 'admin_bill|$sessionKey|$ticketKey|$requestStamp';
    // Mahabang TTL: ang isang bill request ay dapat minsan lang ma-alert sa
    // buong shift, kahit maraming refresh/tab switch ang admin.
    if (!NotificationCenter.instance.shouldNotify(
      dedupeKey,
      ttl: const Duration(hours: 24),
    )) {
      return false;
    }

    final String total =
        (grandTotal != null && grandTotal.toString().isNotEmpty)
        ? ' • ₱$grandTotal'
        : '';
    final String who = (customerName != null && customerName.trim().isNotEmpty)
        ? ' ($customerName)'
        : '';

    unawaited(
      _presentBanner(
        title:
            'Bill Requested — Table ${tableNumber.toString().padLeft(2, '0')}',
        message:
            'May customer na humihingi ng bill$who.$total Pumunta na sa table.',
        backgroundColor: const Color(0xFF0EA5E9),
        icon: Icons.receipt_long,
        dedupeKey: dedupeKey,
        groupKey: rootOrderId != null && rootOrderId > 0
            ? UserSession.formatOrderCode(rootOrderId)
            : 'BILL-TABLE-${tableNumber.toString().padLeft(2, '0')}',
      ),
    );
    return true;
  }

  /// Admin alert kapag may bagong order (regular o additional).
  static bool showAdminNewOrderBanner({
    required int tableNumber,
    required dynamic orderId,
    int? parentOrderId,
    bool isAdditional = false,
    String? itemsSummary,
    dynamic totalAmount,
  }) {
    final String orderCode = UserSession.formatOrderCode(orderId);
    final int? rootOrderId = parentOrderId != null && parentOrderId > 0
        ? parentOrderId
        : (orderId is int ? orderId : int.tryParse(orderId.toString()));
    final String rootCode = rootOrderId != null
        ? UserSession.formatOrderCode(rootOrderId)
        : orderCode;
    final String dedupeKey = 'admin_new_order|$orderCode';
    // Isang beses lang per ticket sa buong shift.
    if (!NotificationCenter.instance.shouldNotify(
      dedupeKey,
      ttl: const Duration(hours: 24),
    )) {
      return false;
    }

    final String total =
        (totalAmount != null &&
            totalAmount.toString().isNotEmpty &&
            totalAmount != '0')
        ? ' • ₱$totalAmount'
        : '';
    final String items =
        (itemsSummary != null && itemsSummary.trim().isNotEmpty)
        ? ' ${itemsSummary.trim()}'
        : '';
    final String parentNote = isAdditional
        ? ' • Additional sa Ticket $rootCode'
        : '';
    final String title = isAdditional
        ? 'Additional Order — $orderCode'
        : 'New Order — $orderCode';
    final String tableLabel = 'Table ${tableNumber.toString().padLeft(2, '0')}';

    unawaited(
      _presentBanner(
        title: title,
        message: '$tableLabel$parentNote.$items$total',
        backgroundColor: isAdditional
            ? const Color(0xFF8B5CF6)
            : const Color(0xFF0F766E),
        icon: isAdditional ? Icons.add_shopping_cart : Icons.fastfood,
        dedupeKey: dedupeKey,
        groupKey: rootCode,
      ),
    );
    return true;
  }

  /// Admin alert para sa low/out-of-stock items. Isang banner per batch ng
  /// mga bagong-bumaba sa threshold para hindi mag-spam.
  static bool showAdminLowStockBanner({
    required List<Map<String, dynamic>> items,
  }) {
    if (items.isEmpty) return false;

    final List<String> labels = items.map((item) {
      final String name = (item['name'] ?? item['item_name'] ?? 'Item')
          .toString();
      final int stock = int.tryParse((item['stock'] ?? 0).toString()) ?? 0;
      return '$name (${stock <= 0 ? 'out of stock' : '$stock left'})';
    }).toList();

    final String dedupeKey =
        'admin_low_stock|${items.map((i) {
          final String id = (i['id'] ?? i['name'] ?? '').toString();
          final String stock = (i['stock'] ?? '').toString();
          return '$id:$stock';
        }).join(',')}';
    if (!NotificationCenter.instance.shouldNotify(
      dedupeKey,
      ttl: const Duration(hours: 12),
    )) {
      return false;
    }

    final int outOfStock = items
        .where((i) => (int.tryParse((i['stock'] ?? 0).toString()) ?? 0) <= 0)
        .length;
    final String title = items.length == 1
        ? (outOfStock == 1 ? 'Out of Stock' : 'Low Stock')
        : (outOfStock > 0
              ? 'Stock Alert — $outOfStock out of stock'
              : 'Low Stock — ${items.length} items');
    final String preview = labels.take(3).join(', ');
    final String more = labels.length > 3 ? ' +${labels.length - 3} more' : '';

    unawaited(
      _presentBanner(
        title: title,
        message: '$preview$more. Check Stock Management.',
        backgroundColor: outOfStock > 0
            ? const Color(0xFFEF4444)
            : const Color(0xFFF59E0B),
        icon: outOfStock > 0 ? Icons.remove_shopping_cart : Icons.inventory_2,
        dedupeKey: dedupeKey,
        groupKey: 'STOCK',
      ),
    );
    return true;
  }

  /// Ang nag-iisang presentation path ng lahat ng banner. Gumagamit ng root
  /// ScaffoldMessenger para hindi mawala ang notif kapag na-dispose ang screen
  /// na nag-register ng listener.
  static Future<void> _presentBanner({
    required String title,
    required String message,
    required Color backgroundColor,
    required IconData icon,
    String? dedupeKey,
    String? groupKey,
  }) async {
    final NotificationPayload payload = NotificationPayload(
      title: title,
      message: message,
      backgroundColor: backgroundColor,
      icon: icon,
      duration: const Duration(seconds: 4),
      groupKey: groupKey,
    );

    // Kapag background ang app, huwag agad i-consume ang dedupe. Sa web,
    // walang system notification — i-queue para lumabas pag-resume. Sa mobile,
    // subukan ang system notification; kung walang permission, i-queue din.
    if (!isAppInForeground) {
      bool presentedBySystem = false;
      if (!kIsWeb) {
        final PermissionStatus notificationStatus =
            await Permission.notification.status;
        if (notificationStatus.isGranted) {
          unawaited(playStatusAlertSound());
          _insertOrUpdateRecord(
            NotificationRecord(
              title: title,
              message: message,
              timestamp: DateTime.now(),
              backgroundColor: backgroundColor,
              icon: icon,
              groupKey: groupKey,
            ),
          );
          await showSystemNotification(
            title: title,
            message: message,
            backgroundColor: backgroundColor,
            icon: icon,
          );
          presentedBySystem = true;
        }
      }

      if (!presentedBySystem) {
        final String queueKey = dedupeKey ?? '$title|$message';
        if (_pendingBanners.length >= _maxPendingBanners) {
          _pendingBanners.remove(_pendingBanners.keys.first);
        }
        _pendingBanners[queueKey] = payload;
        // Hindi pa naipakita -> ibalik ang dedupe slot para makalabas ito
        // kapag nag-flush sa resume.
        if (dedupeKey != null) {
          NotificationCenter.instance.forget(dedupeKey);
        }
      }
      return;
    }

    unawaited(playStatusAlertSound());

    _insertOrUpdateRecord(
      NotificationRecord(
        title: title,
        message: message,
        timestamp: DateTime.now(),
        backgroundColor: backgroundColor,
        icon: icon,
        groupKey: groupKey,
      ),
    );

    // Overlay-based banner: nasa itaas ng LAHAT ng route, kasama ang
    // nakabukas na dialog (dating natatakpan ng modal barrier ang SnackBar).
    NotificationCenter.instance.show(payload);
  }

  static String _extractOrderId(String text) {
    // Kunin ang ticket/order code na naka-prefix sa title (hal. "#BS-101: ...").
    final ticketMatch = RegExp(r'#BS-[A-Za-z0-9_-]+').firstMatch(text);
    if (ticketMatch != null) {
      return ticketMatch.group(0)!.toUpperCase();
    }
    final fallbackMatch = RegExp(r'#?([0-9a-zA-Z_-]+)').firstMatch(text);
    return fallbackMatch?.group(1) ?? text;
  }

  /// Aggregated history records grouped by ticket/order code so ang lahat ng
  /// active tickets ng session ay nakikita nang walang pag-ooverwrite.
  static List<MapEntry<String, List<NotificationRecord>>> get historyGroups {
    final Map<String, List<NotificationRecord>> grouped = {};
    for (final NotificationRecord record in history) {
      final String key = record.groupKey?.trim().isNotEmpty == true
          ? record.groupKey!.trim()
          : _extractOrderId(record.title);
      grouped.putIfAbsent(key, () => <NotificationRecord>[]).add(record);
    }
    final List<MapEntry<String, List<NotificationRecord>>> entries = grouped
        .entries
        .toList();
    entries.sort((a, b) {
      final DateTime timeA = a.value.isNotEmpty
          ? a.value.first.timestamp
          : DateTime.fromMillisecondsSinceEpoch(0);
      final DateTime timeB = b.value.isNotEmpty
          ? b.value.first.timestamp
          : DateTime.fromMillisecondsSinceEpoch(0);
      return timeB.compareTo(timeA);
    });
    return entries;
  }

  static void _insertOrUpdateRecord(NotificationRecord record) {
    // APPEND (hindi overwrite) para makita ang BUONG timeline ng statuses ng
    // isang ticket sa Notification History — hindi lang ang huling status.
    history.insert(0, record);
    unseenHistoryCount++;

    // Safety cap para hindi lumaki nang walang hanggan sa mahabang session.
    const int maxRecords = 200;
    if (history.length > maxRecords) {
      history.removeRange(maxRecords, history.length);
    }

    history.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// Ticket header widget for the notification history group.
  static Widget _buildHistoryTicketHeader(String orderKey) {
    final bool isStock = orderKey == 'STOCK';
    final bool isBill = !isStock && orderKey.startsWith('BILL');
    final String label = isStock
        ? 'Stock Alerts'
        : isBill
        ? 'Bill Requests'
        : 'Ticket $orderKey';
    final IconData icon = isStock
        ? Icons.inventory_2_outlined
        : isBill
        ? Icons.receipt_long_outlined
        : Icons.confirmation_number_outlined;

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Color(0xFF203F35),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF203F35),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Single notification history tile widget.
  static Widget _buildHistoryTile(NotificationRecord item) {
    final String timeStr =
        '${item.timestamp.hour > 12 ? item.timestamp.hour - 12 : (item.timestamp.hour == 0 ? 12 : item.timestamp.hour)}:${item.timestamp.minute.toString().padLeft(2, '0')} ${item.timestamp.hour >= 12 ? 'PM' : 'AM'}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F4EC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5DFD3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: item.backgroundColor,
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFF203F35),
                        ),
                      ),
                    ),
                    Text(
                      timeStr,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: Color(0xFF687368),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.message,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: Color(0xFF4A5568),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Show Notification History Bottom Sheet from in-memory real-time records
  static void showNotificationHistory(BuildContext context) {
    if (!context.mounted) return;
    markHistorySeen();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFFFDFA),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          constraints: const BoxConstraints(maxHeight: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.notifications_active,
                        color: Color(0xFF203F35),
                        size: 22,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Notification History',
                        style: TextStyle(
                          fontFamily: 'Libre Baskerville',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF203F35),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF203F35)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(color: Color(0xFFE5DFD3), height: 20),
              Expanded(
                child: historyGroups.isEmpty
                    ? const Center(
                        child: Text(
                          'No notifications yet.',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: Color(0xFF687368),
                            fontSize: 13,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 8),
                        itemCount: historyGroups.length,
                        itemBuilder: (context, index) {
                          final entry = historyGroups[index];
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHistoryTicketHeader(entry.key),
                              ...entry.value.map(_buildHistoryTile),
                              const SizedBox(height: 8),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lifecycle observer na nagdadala ng foreground/background state ng app sa
/// [AudioNotificationService] at nagre-request ng notification permission sa
/// resume. Ito ang dahilan kung bakit gumagamit ng system notification ang app
/// (lalo na kapag background) para sa order alerts.
class NotificationLifecycleObserver with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final bool isForeground = state == AppLifecycleState.resumed;
    AudioNotificationService.setAppInForeground(isForeground);
    if (isForeground) {
      unawaited(AudioNotificationService.requestNotificationPermission());
      AudioNotificationService.flushPendingBanners();
    }
  }
}
