import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../user_session.dart';
import 'notification_center.dart';
import 'notification_router.dart';

class NotificationRecord {
  final String title;
  final String message;
  final DateTime timestamp;
  final Color backgroundColor;
  final IconData icon;

  /// Optional grouping key para sa Notification History. Kapag null, gagamitin
  /// ang ticket code na naka-extract mula sa title (legacy behavior).
  final String? groupKey;

  /// Navigation metadata para sa IN-APP Notification History taps.
  /// Null = customer/legacy notification na walang admin destination.
  final String? routeType;
  final String? orderId;
  final String? itemName;
  final String? itemId;

  NotificationRecord({
    required this.title,
    required this.message,
    required this.timestamp,
    required this.backgroundColor,
    required this.icon,
    this.groupKey,
    this.routeType,
    this.orderId,
    this.itemName,
    this.itemId,
  });

  /// Kung may tamang destination ito pag tinap sa history.
  ///
  /// Basta may `order_id`, order-related pa rin ito kahit walang `type`
  /// (lumang backend payload) — kaya napipindot pa rin papunta sa ticket.
  bool get hasRoute =>
      (routeType ?? '').trim().isNotEmpty || (orderId ?? '').trim().isNotEmpty;

  /// Payload na inaabot kay NotificationRouter pag tinap ang history tile.
  Map<String, dynamic> get routeData => <String, dynamic>{
        'type': routeType ?? '',
        if (orderId != null) 'order_id': orderId,
        if (itemName != null) 'item_name': itemName,
        if (itemId != null) 'item_id': itemId,
      };
}

class AudioNotificationService {
  static final AudioPlayer _audioPlayer = AudioPlayer();
  static final List<NotificationRecord> history = [];

  /// Bilang ng notifications na hindi pa nakikita sa Notification History.
  static int unseenHistoryCount = 0;

  static void markHistorySeen() => unseenHistoryCount = 0;

  /// History ay sine-save sa disk kaya hindi nawawala kapag pinatay ang app.
  /// Ito ang nagbibigay ng "alam ko kung anong nangyari" pagbalik ng customer.
  static const String _historyStorageKey = 'balai_notification_history_v2';

  /// I-load ang na-save na history. Returns bilang ng BAGONG records na
  /// na-load (gagamitin para magpakita ng resume summary banner).
  static Future<int> loadPersistedHistory() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_historyStorageKey);
      if (raw == null || raw.isEmpty) return 0;

      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      final Set<String> existing = history
          .map(
            (NotificationRecord r) =>
                '${r.timestamp.microsecondsSinceEpoch}|${r.title}|${r.message}',
          )
          .toSet();

      int added = 0;
      for (final dynamic item in decoded) {
        if (item is! Map<String, dynamic>) continue;
        final int? micros = item['timestamp'] is int
            ? item['timestamp'] as int
            : int.tryParse(item['timestamp']?.toString() ?? '');
        if (micros == null) continue;
        final String title = (item['title'] ?? '').toString();
        final String message = (item['message'] ?? '').toString();
        final String key = '$micros|$title|$message';
        if (existing.contains(key)) continue;

        final int argb = item['color'] is int
            ? item['color'] as int
            : 0xFF203F35;
        history.add(
          NotificationRecord(
            title: title,
            message: message,
            timestamp: DateTime.fromMicrosecondsSinceEpoch(micros),
            backgroundColor: Color.fromARGB(
              (argb >> 24) & 0xFF,
              (argb >> 16) & 0xFF,
              (argb >> 8) & 0xFF,
              argb & 0xFF,
            ),
            icon: Icons.notifications_active,
            groupKey: item['groupKey']?.toString(),
            routeType: item['routeType']?.toString(),
            orderId: item['orderId']?.toString(),
            itemName: item['itemName']?.toString(),
            itemId: item['itemId']?.toString(),
          ),
        );
        unseenHistoryCount++;
        added++;
      }

      if (added > 0) {
        history.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        const int maxRecords = 200;
        if (history.length > maxRecords) {
          history.removeRange(maxRecords, history.length);
        }
      }
      return added;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> _persistHistory() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> payload = history
          .take(200)
          .map(
            (NotificationRecord r) => <String, dynamic>{
              'title': r.title,
              'message': r.message,
              'timestamp': r.timestamp.microsecondsSinceEpoch,
              'color': r.backgroundColor.toARGB32(),
              'groupKey': r.groupKey,
              'routeType': r.routeType,
              'orderId': r.orderId,
              'itemName': r.itemName,
              'itemId': r.itemId,
            },
          )
          .toList();
      await prefs.setString(_historyStorageKey, jsonEncode(payload));
    } catch (_) {
      // Best-effort lang — hindi dapat mabigo ang notification dahil sa storage.
    }
  }

  /// Pagbalik sa foreground: i-load ang history mula sa disk at ipaalam sa
  /// customer kung may bago habang nasa background/killed ang app.
  static Future<void> restoreHistoryOnResume() async {
    final int added = await loadPersistedHistory();
    if (added <= 0) return;
    NotificationCenter.instance.show(
      NotificationPayload(
        title: 'May bagong update',
        message: '$added na bagong notification mula nang umalis ka sa app. '
            'I-tap ang bell para makita.',
        backgroundColor: const Color(0xFF203F35),
        icon: Icons.notifications_active,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  /// Buksan ang Notification History kapag tinap ang push notification.
  /// Hintayin muna ang navigator key (cold start case) bago mag-navigate.
  static Future<void> openNotificationHistoryFromPush() async {
    await loadPersistedHistory();

    BuildContext? context = NotificationCenter.navigatorKey.currentContext;
    for (int attempt = 0; attempt < 12 && context == null; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      context = NotificationCenter.navigatorKey.currentContext;
    }
    if (context == null || !context.mounted) return;

    showNotificationHistory(context);
  }

  /// I-record ang FCM push (foreground man o background/killed) sa history
  /// para makita ito ng customer sa bell pagbalik ng app.
  static Future<void> recordRemoteMessage({
    required String title,
    required String body,
    String? groupKey,
    Map<String, dynamic>? data,
  }) async {
    if (title.trim().isEmpty && body.trim().isEmpty) return;
    final Map<String, dynamic> payload = data ?? <String, dynamic>{};
    final String rawType = (payload['type'] ?? '').toString().toLowerCase();
    _insertOrUpdateRecord(
      NotificationRecord(
        title: title.trim().isEmpty ? 'Balai Silayan' : title.trim(),
        message: body.trim(),
        timestamp: DateTime.now(),
        backgroundColor: const Color(0xFF203F35),
        icon: Icons.notifications_active,
        groupKey: groupKey ?? payload['order_id']?.toString(),
        routeType: rawType.isEmpty ? null : rawType,
        orderId:
            payload['order_id']?.toString() ?? payload['id']?.toString(),
        itemName: payload['item_name']?.toString(),
        itemId: payload['item_id']?.toString(),
      ),
    );
  }

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
  ///
  /// MAHALAGA: ang tunog ng channel ay **naka-lock** pagkatapos ma-create sa
  /// device. Kapag pinalitan ang sound file, taasan ang version suffix
  /// (v2 → v3) para makagawa ng BAGONG channel na may bagong tunog. Kung
  /// hindi, mananatiling luma ang tunog sa mga naka-install nang device.
  static const String orderNotificationChannelId = 'balai_silayan_orders_v2';

  /// Legacy channel id na ginagamit pa rin ng deployed backend sa FCM
  /// `android.notification.channelId`. Kung wala ito sa device, **dating
  /// tinatanggihan ng Android ang push notification** (walang lumalabas).
  /// Ginagawa natin ito bilang compatibility bridge hanggang ma-deploy ang
  /// backend na gumagamit na ng `v2`.
  static const String legacyOrderNotificationChannelId =
      'balai_silayan_orders';
  static const String orderNotificationChannelName =
      'Balai Silayan Order Alerts';
  static const String orderNotificationChannelDescription =
      'Balai Silayan order status alerts';

  /// Bundled in-app chime (assets/sounds/…). Asset path ay relative sa
  /// `assets/` folder dahil iyon ang default prefix ng audioplayers.
  static const String notificationSoundAsset = 'sounds/notification_ring.mp3';

  /// System notification sound mula sa `android/app/src/main/res/raw/`
  /// (filename lang, walang extension).
  static const String orderNotificationSoundRaw = 'notification_ring';

  /// Fallback kung hindi ma-load ang bundled asset (hal. offline build issue).
  static const String _notificationSoundRemoteUrl =
      'https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3';

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
        // Kapag tinap ang system notification (foreground/background), buksan
        // ang Notification History — kahit naka-kill ang app.
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          NotificationRouter.handlePayload(response.payload);
        },
      );

      // Android 8+ (API 26+): gawin agad ang channel na may explicit custom
      // sound. Kung iasa lang sa unang show(), puwedeng ma-lock ang channel
      // sa default notification sound — at hindi na ito mababago.
      if (!kIsWeb) {
        final AndroidFlutterLocalNotificationsPlugin? android =
            plugin.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        await android?.createNotificationChannel(
          const AndroidNotificationChannel(
            orderNotificationChannelId,
            orderNotificationChannelName,
            description: orderNotificationChannelDescription,
            importance: Importance.high,
            playSound: true,
            sound: RawResourceAndroidNotificationSound(
              orderNotificationSoundRaw,
            ),
            enableVibration: true,
          ),
        );

        // Compatibility: ang FCM push mula sa kasalukuyang deployed backend ay
        // naka-target sa lumang channel id. Kung wala ito sa device, hindi
        // lumalabas ang new order / additional / bill / low stock alerts.
        await android?.createNotificationChannel(
          const AndroidNotificationChannel(
            legacyOrderNotificationChannelId,
            '$orderNotificationChannelName (legacy)',
            description: 'Compatibility channel para sa FCM push alerts',
            importance: Importance.high,
            playSound: true,
            sound: RawResourceAndroidNotificationSound(
              orderNotificationSoundRaw,
            ),
            enableVibration: true,
          ),
        );
      }

      debugPrint(
        '✅ [AudioNotificationService] Local notifications initialized.',
      );
    } catch (e) {
      debugPrint(
        '⚠️ [AudioNotificationService] Local notifications init failed: $e',
      );
    }

    // I-cache nang maaga ang chime: mas mabilis ang unang alert at agad na
    // lumalabas sa log kung hindi na-bundle/na-load ang sound asset.
    await preloadAlertSound();
  }

  /// I-load sa audio cache ang notification chime.
  static Future<void> preloadAlertSound() async {
    try {
      await AudioCache.instance.load(notificationSoundAsset);
      debugPrint('✅ [AudioNotificationService] Alert sound cached.');
    } catch (e) {
      debugPrint(
        '⚠️ [AudioNotificationService] alert sound failed to load '
        '($notificationSoundAsset): $e',
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
            channelDescription: orderNotificationChannelDescription,
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            sound: RawResourceAndroidNotificationSound(
              orderNotificationSoundRaw,
            ),
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
      await _audioPlayer.stop();

      // Android: gamitin ang notification stream (hindi media) para hindi
      // dipende sa media volume at hindi makipag-away sa audio focus ng iba.
      if (!kIsWeb) {
        await _audioPlayer.setAudioContext(
          AudioContext(
            android: const AudioContextAndroid(
              contentType: AndroidContentType.sonification,
              usageType: AndroidUsageType.notificationEvent,
              audioFocus: AndroidAudioFocus.gainTransientMayDuck,
            ),
          ),
        );
        await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      }

      // Asset-first sa LAHAT ng platform para pareho ang tunog at gumana kahit
      // offline. Remote URL na lang ang fallback kung mabigo ang asset load.
      bool played = false;
      try {
        await _audioPlayer.play(
          AssetSource(notificationSoundAsset),
          volume: 1.0,
        );
        played = true;
      } catch (assetError) {
        debugPrint(
          '⚠️ [AudioNotificationService] asset sound failed '
          '($notificationSoundAsset): $assetError',
        );
      }

      if (!played) {
        await _audioPlayer.play(
          UrlSource(_notificationSoundRemoteUrl),
          volume: 1.0,
        );
      }
    } catch (e, stackTrace) {
      debugPrint(
        '❌ [AudioNotificationService] Error playing notification sound: '
        '$e\n$stackTrace',
      );
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
      // Naka-queue na ito — huwag nang i-check ang dedupe dahil naka-record na
      // ang key noong na-queue. Kung i-check pa, hindi na ito lalabas.
      // I-replay ito pinaagi ng _presentBanner para hindi mawawala ang sound +
      // notification history (kung direktang NotificationCenter.instance.show lang).
      _presentBanner(
        title: entry.value.title,
        message: entry.value.message,
        backgroundColor: entry.value.backgroundColor,
        icon: entry.value.icon,
        dedupeKey: entry.key,
        groupKey: entry.value.groupKey,
        routeType: entry.value.routeType,
        orderId: entry.value.orderId,
        itemName: entry.value.itemName,
        itemId: entry.value.itemId,
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

  /// Dedupe key para sa admin bill request alert.
  /// Isang alert lang per root ticket — kahit parent at child tickets ang
  /// mag-request ng bill sa parehong oras.
  static String _adminBillDedupeKey({
    required int tableNumber,
    int? sessionId,
    int? orderId,
    int? parentOrderId,
    DateTime? billRequestedAt,
  }) {
    final String requestStamp = billRequestedAt != null
        ? billRequestedAt.toUtc().toIso8601String().substring(0, 19)
        : 'no_timestamp';
    final String sessionKey = sessionId != null && sessionId > 0
        ? 'session_$sessionId'
        : 'table_$tableNumber';
    final int? rootOrderId = parentOrderId != null && parentOrderId > 0
        ? parentOrderId
        : orderId;
    final String ticketKey = rootOrderId != null && rootOrderId > 0
        ? 'order_$rootOrderId'
        : 'order_any';
    return 'admin_bill|$sessionKey|$ticketKey|$requestStamp';
  }

  /// I-record lang ang dedupe key ng isang pending bill request nang WALANG
  /// banner o tunog. Gamit ito sa unang load/login para hindi mag-replay nang
  /// isa-isa ang lahat ng lumang requests; ang mga bagong request lang ang
  /// mag-a-alert pagkatapos.
  static void seedAdminBillRequested({
    required int tableNumber,
    int? sessionId,
    int? orderId,
    int? parentOrderId,
    DateTime? billRequestedAt,
  }) {
    final String dedupeKey = _adminBillDedupeKey(
      tableNumber: tableNumber,
      sessionId: sessionId,
      orderId: orderId,
      parentOrderId: parentOrderId,
      billRequestedAt: billRequestedAt,
    );
    // Kung na-seed/naka-alert na ito, huwag nang magdagdag ng history record.
    if (!NotificationCenter.instance.shouldNotify(
      dedupeKey,
      ttl: const Duration(hours: 24),
    )) {
      return;
    }

    final int? rootOrderId = parentOrderId != null && parentOrderId > 0
        ? parentOrderId
        : orderId;
    final String ticketCode = rootOrderId != null && rootOrderId > 0
        ? UserSession.formatOrderCode(rootOrderId)
        : (orderId != null && orderId > 0
              ? UserSession.formatOrderCode(orderId)
              : 'BILL');
    final String groupKey = rootOrderId != null && rootOrderId > 0
        ? UserSession.formatOrderCode(rootOrderId)
        : 'BILL-TABLE-${tableNumber.toString().padLeft(2, '0')}';

    // Walang banner at tunog — record lang para may laman agad ang bell/history
    // pagka-login ng admin, kahit hindi pa nag-po-poll ang bagong order.
    _insertOrUpdateRecord(
      NotificationRecord(
        title:
            'Bill Requested — $ticketCode • Table ${tableNumber.toString().padLeft(2, '0')}',
        message: 'Existing bill request. Waiting for staff to settle.',
        timestamp: billRequestedAt ?? DateTime.now(),
        backgroundColor: const Color(0xFF0EA5E9),
        icon: Icons.receipt_long,
        groupKey: groupKey,
        routeType: 'bill_requested',
        orderId: rootOrderId?.toString() ?? orderId?.toString(),
      ),
    );
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
    final String dedupeKey = _adminBillDedupeKey(
      tableNumber: tableNumber,
      sessionId: sessionId,
      orderId: orderId,
      parentOrderId: parentOrderId,
      billRequestedAt: billRequestedAt,
    );
    final int? rootOrderId = parentOrderId != null && parentOrderId > 0
        ? parentOrderId
        : orderId;
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
    final String ticketCode = rootOrderId != null && rootOrderId > 0
        ? UserSession.formatOrderCode(rootOrderId)
        : (orderId != null && orderId > 0
              ? UserSession.formatOrderCode(orderId)
              : 'BILL');

    unawaited(
      _presentBanner(
        title:
            'Bill Requested — $ticketCode • Table ${tableNumber.toString().padLeft(2, '0')}',
        message:
            'May customer na humihingi ng bill$who.$total Pumunta na sa table.',
        backgroundColor: const Color(0xFF0EA5E9),
        icon: Icons.receipt_long,
        dedupeKey: dedupeKey,
        groupKey: rootOrderId != null && rootOrderId > 0
            ? UserSession.formatOrderCode(rootOrderId)
            : 'BILL-TABLE-${tableNumber.toString().padLeft(2, '0')}',
        routeType: 'bill_requested',
        orderId: rootOrderId?.toString() ?? orderId?.toString(),
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
    // Additional orders: isama ang total sa dedupe key para may bagong alert
    // sa bawat pagdagdag ng items — kahit PENDING/NEW pa ang parent at
    // parehong order row lang ang na-update (merged additional items).
    final String dedupeKey = isAdditional
        ? 'admin_additional|$orderCode|${totalAmount ?? ''}'
        : 'admin_new_order|$orderCode';
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
        routeType: isAdditional ? 'additional_order' : 'new_order',
        orderId: rootOrderId?.toString() ?? orderId.toString(),
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

    // Unang item ang itatakda para hanapin agad sa Stock Management pag tinap.
    final Map<String, dynamic> first = items.first;
    final String firstName =
        (first['name'] ?? first['item_name'] ?? '').toString();
    final String firstId = (first['id'] ?? first['item_id'] ?? '').toString();

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
        routeType: 'low_stock',
        itemName: firstName,
        itemId: firstId,
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
    String? routeType,
    String? orderId,
    String? itemName,
    String? itemId,
  }) async {
    NotificationRecord buildRecord() => NotificationRecord(
          title: title,
          message: message,
          timestamp: DateTime.now(),
          backgroundColor: backgroundColor,
          icon: icon,
          groupKey: groupKey,
          routeType: routeType,
          orderId: orderId,
          itemName: itemName,
          itemId: itemId,
        );

    final NotificationPayload payload = NotificationPayload(
      title: title,
      message: message,
      backgroundColor: backgroundColor,
      icon: icon,
      duration: const Duration(seconds: 4),
      groupKey: groupKey,
      routeType: routeType,
      orderId: orderId,
      itemName: itemName,
      itemId: itemId,
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
          _insertOrUpdateRecord(buildRecord());
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
        // Huwag i-forget ang dedupe key. Kung i-forget ito, muling papasa ang
        // shouldNotify sa susunod na poll at magiging infinite ang notif.
        // Naka-queue na ang banner at doon ito lalabas pag-resume.
      }
      return;
    }

    unawaited(playStatusAlertSound());

    _insertOrUpdateRecord(buildRecord());

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
    unawaited(_persistHistory());
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
  /// May [onTap] kapag may tamang destination — tinatap para diretsong
  /// pumunta sa Order Queue / Stock Management.
  static Widget _buildHistoryTile(
    NotificationRecord item, {
    VoidCallback? onTap,
  }) {
    final String timeStr =
        '${item.timestamp.hour > 12 ? item.timestamp.hour - 12 : (item.timestamp.hour == 0 ? 12 : item.timestamp.hour)}:${item.timestamp.minute.toString().padLeft(2, '0')} ${item.timestamp.hour >= 12 ? 'PM' : 'AM'}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F4EC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5DFD3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
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
                    if (onTap != null) ...[
                      const SizedBox(height: 5),
                      const Text(
                        'Tap to view',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: Color(0xFF687368),
                ),
            ],
          ),
        ),
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
                              ...entry.value.map(
                                (NotificationRecord item) => _buildHistoryTile(
                                  item,
                                  onTap: item.hasRoute
                                      ? () {
                                          // Isara muna ang sheet bago mag-navigate
                                          // para hindi matakpan ng modal barrier.
                                          Navigator.pop(ctx);
                                          NotificationRouter.handleFromHistory(
                                            item.routeData,
                                          );
                                        }
                                      : null,
                                ),
                              ),
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
