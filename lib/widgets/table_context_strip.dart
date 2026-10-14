import 'package:flutter/material.dart';

class TableContextStrip extends StatelessWidget {
  final int tableNumber;
  final bool isTakeout;
  final String? stateLabel;
  final VoidCallback? onTap;

  const TableContextStrip({
    super.key,
    required this.tableNumber,
    required this.isTakeout,
    this.stateLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String tableString = isTakeout
        ? 'Takeout / To-Go'
        : 'Table ${tableNumber.toString().padLeft(2, '0')} • verified';

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFEEE7D9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF53766C)),
                const SizedBox(width: 6),
                Text(
                  tableString,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Color(0xFF203F35)),
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  stateLabel ?? (isTakeout ? 'Takeout' : 'Dine-in'),
                  style: const TextStyle(fontSize: 10, color: Color(0xFF788078), fontWeight: FontWeight.w500),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.edit_outlined, size: 12, color: Color(0xFF788078)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
