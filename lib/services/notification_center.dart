import 'dart:async';

import 'package:flutter/material.dart';

/// Isang banner payload na ipinapakita sa itaas ng LAHAT ng route — kasama ang
/// mga nakabukas na dialog. Ito ang pumalit sa SnackBar na dati ay natatakpan
/// ng modal barrier ng `showDialog`.
class NotificationPayload {
  const NotificationPayload({
    required this.title,
    required this.message,
    required this.backgroundColor,
    required this.icon,
    this.duration = const Duration(seconds: 3),
    this.groupKey,
  });

  final String title;
  final String message;
  final Color backgroundColor;
  final IconData icon;
  final Duration duration;

  /// Optional grouping key para sa notification history.
  final String? groupKey;
}

/// Sentral na presentation at dedupe ng lahat ng notification.
///
/// - Overlay-based banner (laging nasa itaas, kahit may dialog)
/// - FIFO queue (walang banner na nagsasapawan)
/// - TTL dedupe (hindi permanenteng naka-block ang parehong status)
class NotificationCenter {
  NotificationCenter._();

  static final NotificationCenter instance = NotificationCenter._();

  /// Root navigator key — kailangang i-register sa `MaterialApp.navigatorKey`
  /// para makapag-insert ng overlay kahit saan.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Fallback kung hindi pa available ang overlay (hal. sobrang aga ng event).
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static const Duration defaultDedupeTtl = Duration(minutes: 15);
  static const int maxDedupeEntries = 500;

  final Map<String, DateTime> _dedupe = <String, DateTime>{};
  final List<NotificationPayload> _queue = <NotificationPayload>[];

  OverlayEntry? _activeEntry;
  bool _isShowing = false;
  Timer? _retryTimer;
  int _retryCount = 0;

  /// `true` kung hindi pa na-notify ang key sa loob ng TTL. Side effect: ito na
  /// rin ang nagre-record ng bagong notification.
  bool shouldNotify(String key, {Duration ttl = defaultDedupeTtl}) {
    final DateTime now = DateTime.now();
    _prune(now, ttl);

    final DateTime? last = _dedupe[key];
    if (last != null && now.difference(last) < ttl) {
      return false;
    }

    _dedupe[key] = now;
    _enforceCap();
    return true;
  }

  void resetDedupe() {
    _dedupe.clear();
  }

  /// Alisin ang dedupe record para sa isang key. Ginagamit kapag na-queue ang
  /// notification habang background (hindi pa talaga naipakita) — para may
  /// chance pang lumabas ito sa resume/flush.
  void forget(String key) {
    _dedupe.remove(key);
  }

  void show(NotificationPayload payload) {
    _queue.add(payload);
    _showNextIfIdle();
  }

  void clear() {
    _queue.clear();
    _activeEntry?.remove();
    _activeEntry = null;
    _isShowing = false;
    _retryTimer?.cancel();
  }

  void _showNextIfIdle() {
    if (_isShowing) return;
    if (_queue.isEmpty) return;

    final OverlayState? overlay = navigatorKey.currentState?.overlay;
    if (overlay == null) {
      _scheduleRetry();
      return;
    }

    _retryTimer?.cancel();
    _retryCount = 0;

    final NotificationPayload payload = _queue.removeAt(0);
    _isShowing = true;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _BannerOverlay(
        payload: payload,
        onDismissed: () {
          if (_activeEntry == entry) {
            _activeEntry = null;
          }
          entry.remove();
          _isShowing = false;
          _showNextIfIdle();
        },
      ),
    );

    _activeEntry = entry;
    overlay.insert(entry);
  }

  void _scheduleRetry() {
    if (_retryCount >= 20) {
      // Sobrang tagal nang walang overlay — i-drop ang banner pero itago pa rin
      // sa history (history ang bahala sa AudioNotificationService).
      _retryCount = 0;
      final NotificationPayload? pending = _queue.isNotEmpty
          ? _queue.first
          : null;
      _queue.clear();
      if (pending != null) _fallbackToMessenger(pending);
      return;
    }
    _retryCount++;
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(milliseconds: 300), _showNextIfIdle);
  }

  void _fallbackToMessenger(NotificationPayload last) {
    final ScaffoldMessengerState? messenger = messengerKey.currentState;
    if (messenger == null) return;
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: last.backgroundColor,
        content: Text('${last.title}\n${last.message}'),
      ),
    );
  }

  void _prune(DateTime now, Duration ttl) {
    _dedupe.removeWhere((_, time) => now.difference(time) >= ttl);
  }

  void _enforceCap() {
    if (_dedupe.length <= maxDedupeEntries) return;
    final List<MapEntry<String, DateTime>> entries = _dedupe.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final int excess = _dedupe.length - maxDedupeEntries;
    for (int i = 0; i < excess; i++) {
      _dedupe.remove(entries[i].key);
    }
  }
}

class _BannerOverlay extends StatefulWidget {
  const _BannerOverlay({required this.payload, required this.onDismissed});

  final NotificationPayload payload;
  final VoidCallback onDismissed;

  @override
  State<_BannerOverlay> createState() => _BannerOverlayState();
}

class _BannerOverlayState extends State<_BannerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offset;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _offset = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
    Future<void>.delayed(widget.payload.duration, _dismiss);
  }

  Future<void> _dismiss() async {
    if (!mounted || _dismissing) return;
    _dismissing = true;
    try {
      await _controller.reverse();
    } catch (_) {}
    if (mounted) widget.onDismissed();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: SlideTransition(
          position: _offset,
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: GestureDetector(
                onTap: _dismiss,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: widget.payload.backgroundColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.white24,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          widget.payload.icon,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.payload.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.payload.message,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
