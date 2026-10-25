import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NotificationRecord {
  final String title;
  final String message;
  final DateTime timestamp;
  final Color backgroundColor;
  final IconData icon;

  NotificationRecord({
    required this.title,
    required this.message,
    required this.timestamp,
    required this.backgroundColor,
    required this.icon,
  });
}

class AudioNotificationService {
  static final AudioPlayer _audioPlayer = AudioPlayer();
  static final List<NotificationRecord> history = [];

  /// Play sound chime and trigger built-in haptic vibration
  static Future<void> playStatusAlertSound() async {
    try {
      if (kIsWeb) {
        await _audioPlayer.stop();
        try {
          await _audioPlayer.play(UrlSource('https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3'), volume: 1.0);
        } catch (_) {
          await _audioPlayer.play(AssetSource('sounds/notification_ring.mp3'), volume: 1.0);
        }
      } else {
        await _audioPlayer.stop();
        await _audioPlayer.play(AssetSource('sounds/notification_ring.mp3'), volume: 1.0);
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
    // I-play ang alert sound sa background na hindi nahaharang ng banner flow.
    // Kapag walang audio asset o mag-fail ang playback, hindi ito dapat
    // hinaharang sa pagpapakita ng SnackBar notification.
    unawaited(playStatusAlertSound());

    _insertOrUpdateRecord(
      NotificationRecord(
        title: title,
        message: message,
        timestamp: DateTime.now(),
        backgroundColor: backgroundColor,
        icon: icon,
      ),
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
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
    );
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
      final String key = _extractOrderId(record.title);
      grouped.putIfAbsent(key, () => <NotificationRecord>[]).add(record);
    }
    final List<MapEntry<String, List<NotificationRecord>>> entries = grouped.entries.toList();
    entries.sort((a, b) {
      final DateTime timeA = a.value.isNotEmpty ? a.value.first.timestamp : DateTime.fromMillisecondsSinceEpoch(0);
      final DateTime timeB = b.value.isNotEmpty ? b.value.first.timestamp : DateTime.fromMillisecondsSinceEpoch(0);
      return timeB.compareTo(timeA);
    });
    return entries;
  }

  static void _insertOrUpdateRecord(NotificationRecord record) {
    final String newOrderId = _extractOrderId(record.title);
    final existingIndex = history.indexWhere((h) => _extractOrderId(h.title) == newOrderId);

    if (existingIndex != -1) {
      history[existingIndex] = record;
    } else {
      history.insert(0, record);
    }
    history.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// Ticket header widget for the notification history group.
  static Widget _buildHistoryTicketHeader(String orderKey) {
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
            child: const Icon(Icons.receipt_long_outlined, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Ticket $orderKey',
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
    final String timeStr = '${item.timestamp.hour > 12 ? item.timestamp.hour - 12 : (item.timestamp.hour == 0 ? 12 : item.timestamp.hour)}:${item.timestamp.minute.toString().padLeft(2, '0')} ${item.timestamp.hour >= 12 ? 'PM' : 'AM'}';

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
                      Icon(Icons.notifications_active, color: Color(0xFF203F35), size: 22),
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
                          style: TextStyle(fontFamily: 'Inter', color: Color(0xFF687368), fontSize: 13),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
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
