import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../user_session.dart';

/// One-time (per session) reminder na lumalabas pagkatapos ng QR scan.
/// Dahilan: ang live order updates (socket + Supabase realtime) ay
/// gumagana lang habang buhay ang app process.
class SessionNotice {
  SessionNotice._();

  static int? _shownForSessionId;

  /// Ipakita lang kung bago ang session (o wala pang naipakitang notice).
  static Future<void> showIfNeeded(BuildContext context) async {
    final int? sessionId = UserSession.activeSessionId;
    if (sessionId != null && sessionId == _shownForSessionId) return;
    _shownForSessionId = sessionId;
    await showSessionNoticeSheet(context);
  }

  static Future<void> showSessionNoticeSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => const _SessionNoticeSheet(),
    );
  }
}

class _SessionNoticeSheet extends StatelessWidget {
  const _SessionNoticeSheet();

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Container(
      margin: const EdgeInsets.only(top: 60),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceIvory,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 12, 24, 20 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppTheme.borderWarm,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 22),

            // Hero icon
            Center(
              child: Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.primaryCrimson, Color(0xFFB8434A)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryCrimson.withValues(alpha: 0.28),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(height: 18),

            const Center(
              child: Text(
                'BEFORE YOU START',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.2,
                  color: AppTheme.secondaryGold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Para hindi ka ma-miss\nng order updates',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 23,
                height: 1.2,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: AppTheme.darkCharcoal,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Habang naka-background ang app, dito dumarating ang live\n'
              'status ng order mo. Sundin lang ang 4 na paalala:',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppTheme.mutedGray,
              ),
            ),
            const SizedBox(height: 22),

            const _NoticeItem(
              icon: Icons.smartphone_rounded,
              title: 'Huwag i-close ang app',
              caption:
                  'Pwede mong i-lock ang phone — basta huwag i-swipe close '
                  'ang app sa recents. Dito umaandar ang notification.',
              accent: AppTheme.primaryCrimson,
            ),
            const _NoticeItem(
              icon: Icons.table_restaurant_rounded,
              title: 'Manatili muna sa mesa',
              caption:
                  'Naka-link ang notifications sa session ng table mo. '
                  'Kapag lumipat, hindi na tama ang updates.',
              accent: AppTheme.infoBlueGray,
            ),
            const _NoticeItem(
              icon: Icons.notifications_none_rounded,
              title: 'Payagan ang notifications',
              caption:
                  'Kailangan ng notification permission para lumabas ang '
                  'status sa notification shade.',
              accent: AppTheme.warningAmber,
            ),
            const _NoticeItem(
              icon: Icons.wifi_rounded,
              title: 'Kailangan ng internet',
              caption:
                  'Kung walang data/Wi-Fi, hindi makakapasok ang updates. '
                  'I-off ang battery saver kung kaya.',
              accent: AppTheme.successGreen,
              isLast: true,
            ),

            const SizedBox(height: 24),
            SizedBox(
              height: 54,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryCrimson,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Got it, let\'s order',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                'Makikita mo rin ang status sa Order Status screen.',
                style: TextStyle(fontSize: 11, color: AppTheme.mutedGray),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoticeItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String caption;
  final Color accent;
  final bool isLast;

  const _NoticeItem({
    required this.icon,
    required this.title,
    required this.caption,
    required this.accent,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkCharcoal,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  caption,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: AppTheme.mutedGray,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
