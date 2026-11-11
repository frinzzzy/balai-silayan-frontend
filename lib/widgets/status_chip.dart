import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Presentational status pill used by the admin order queue.
/// Purely visual — does NOT touch any order status logic.
class StatusChip extends StatelessWidget {
  final String status;
  final bool isPriority;

  const StatusChip({super.key, required this.status, this.isPriority = false});

  static _StatusPalette _resolve(String raw) {
    final String normalized = raw.trim().toUpperCase();
    switch (normalized) {
      case 'PREPARING':
        return _StatusPalette(background: AdminTheme.preparingBg, foreground: AdminTheme.danger);
      case 'READY':
      case 'SERVED':
      case 'PAID':
      case 'COMPLETED':
        return _StatusPalette(background: AdminTheme.successBg, foreground: AdminTheme.successFg);
      default:
        return _StatusPalette(background: AdminTheme.warningBg, foreground: AdminTheme.bronzeGold);
    }
  }

  @override
  Widget build(BuildContext context) {
    final _StatusPalette palette = _resolve(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: palette.foreground),
      ),
    );
  }
}

class _StatusPalette {
  final Color background;
  final Color foreground;

  const _StatusPalette({required this.background, required this.foreground});
}
