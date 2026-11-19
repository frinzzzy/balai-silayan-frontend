import 'package:flutter/material.dart';

import '../models/admin_order_model.dart';
import '../services/admin_service.dart';
import '../../../theme/app_theme.dart';

/// Per-item checklist para sa isang order.
///
/// Bawat order line item ay may sariling checkbox. Pwedeng mag-check ang
/// kitchen, waiter, at admin (role-gated sa [canCheck]). Kapag naka-[enlarged]
/// mode, mas malaki ang text at checkbox para madaling makita sa kitchen.
class OrderItemChecklist extends StatefulWidget {
  final AdminOrder order;
  final bool canCheck;
  final bool enlarged;
  final bool showHeader;
  final VoidCallback? onChanged;
  final VoidCallback? onEnlarge;

  const OrderItemChecklist({
    super.key,
    required this.order,
    this.canCheck = false,
    this.enlarged = false,
    this.showHeader = true,
    this.onChanged,
    this.onEnlarge,
  });

  @override
  State<OrderItemChecklist> createState() => _OrderItemChecklistState();
}

class _OrderItemChecklistState extends State<OrderItemChecklist> {
  late List<OrderLine> _items;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _items = List<OrderLine>.of(widget.order.items);
  }

  @override
  void didUpdateWidget(covariant OrderItemChecklist oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameItems(oldWidget.order.items, widget.order.items)) {
      _items = List<OrderLine>.of(widget.order.items);
    }
  }

  bool _sameItems(List<OrderLine> a, List<OrderLine> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id || a[i].isChecked != b[i].isChecked) {
        return false;
      }
    }
    return true;
  }

  int get _checkedCount => _items.where((item) => item.isChecked).length;

  bool get _allChecked => _items.isNotEmpty && _checkedCount == _items.length;

  String get _staffLabel => AdminService.staffName ?? 'Staff';

  void _showError() {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text('Hindi na-save ang checklist. Subukan ulit.'),
      ),
    );
  }

  Future<void> _toggle(int index, bool value) async {
    if (!widget.canCheck || _saving) return;
    final OrderLine item = _items[index];
    if (item.id == null) return;

    setState(() {
      _saving = true;
      _items[index] = item.copyWith(
        isChecked: value,
        checkedAt: value ? DateTime.now() : null,
        checkedBy: value ? _staffLabel : '',
      );
    });

    final bool ok = await AdminService().setOrderItemChecked(
      orderId: widget.order.id,
      itemId: item.id!,
      checked: value,
    );

    if (!mounted) return;
    setState(() {
      _saving = false;
      if (!ok) {
        // Ibalik sa dating state kapag bigo ang API call.
        _items[index] = item;
      }
    });

    if (!ok) {
      _showError();
    } else {
      widget.onChanged?.call();
    }
  }

  Future<void> _setAll(bool value) async {
    if (!widget.canCheck || _saving) return;

    final List<int> itemIds = _items
        .where((item) => item.id != null)
        .map((item) => item.id!)
        .toList();
    if (itemIds.isEmpty) return;

    setState(() {
      _saving = true;
      _items = _items
          .map(
            (item) => item.copyWith(
              isChecked: value,
              checkedAt: value ? DateTime.now() : null,
              checkedBy: value ? _staffLabel : '',
            ),
          )
          .toList();
    });

    bool allOk = true;
    for (final int itemId in itemIds) {
      final bool ok = await AdminService().setOrderItemChecked(
        orderId: widget.order.id,
        itemId: itemId,
        checked: value,
      );
      if (!ok) allOk = false;
    }

    if (!mounted) return;
    setState(() {
      _saving = false;
      if (!allOk) {
        _items = List<OrderLine>.of(widget.order.items);
      }
    });

    if (!allOk) {
      _showError();
    } else {
      widget.onChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return const SizedBox.shrink();
    }

    final double titleSize = widget.enlarged ? 18 : 13.5;
    final double metaSize = widget.enlarged ? 12.5 : 10.5;
    final double boxScale = widget.enlarged ? 1.4 : 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showHeader) ...[
          Row(
            children: [
              Icon(
                Icons.checklist_rtl,
                size: widget.enlarged ? 26 : 18,
                color: AdminTheme.priorityFg,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.enlarged ? 'ITEM CHECKLIST' : 'Item checklist',
                  style: TextStyle(
                    fontSize: widget.enlarged ? 16 : 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: widget.enlarged ? 1.0 : 0.6,
                    color: AdminTheme.priorityFg,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _allChecked
                      ? const Color(0xFFE3F3E7)
                      : const Color(0xFFFFF4D6),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: _allChecked
                        ? const Color(0xFF7FB08A)
                        : AdminTheme.goldAccent,
                  ),
                ),
                child: Text(
                  '$_checkedCount/${_items.length} done',
                  style: TextStyle(
                    fontSize: widget.enlarged ? 12.5 : 10,
                    fontWeight: FontWeight.bold,
                    color: _allChecked
                        ? const Color(0xFF256B3A)
                        : AdminTheme.priorityFg,
                  ),
                ),
              ),
              if (widget.onEnlarge != null) ...[
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: widget.onEnlarge,
                  icon: Icon(
                    Icons.open_in_full,
                    size: widget.enlarged ? 20 : 15,
                  ),
                  label: Text(
                    'Enlarge',
                    style: TextStyle(fontSize: widget.enlarged ? 14 : 11),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AdminTheme.priorityFg,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: const Size(0, 32),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: _items.isEmpty ? 0 : _checkedCount / _items.length,
              minHeight: widget.enlarged ? 8 : 5,
              backgroundColor: const Color(0xFFE8E2D6),
              valueColor: AlwaysStoppedAnimation<Color>(
                _allChecked
                    ? const Color(0xFF4C9A63)
                    : AdminTheme.goldAccent,
              ),
            ),
          ),
          if (widget.canCheck) ...[
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _saving ? null : () => _setAll(!_allChecked),
                style: TextButton.styleFrom(
                  foregroundColor: AdminTheme.priorityFg,
                  minimumSize: const Size(0, 30),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(
                  _allChecked ? 'Clear all' : 'Check all items',
                  style: TextStyle(
                    fontSize: widget.enlarged ? 14 : 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
        ...List<Widget>.generate(_items.length, (int index) {
          final OrderLine item = _items[index];
          return Container(
            margin: EdgeInsets.only(top: widget.enlarged ? 12 : 6),
            decoration: BoxDecoration(
              color: item.isChecked
                  ? const Color(0xFFEAF5EC)
                  : const Color(0xFFFFFDF8),
              borderRadius: BorderRadius.circular(widget.enlarged ? 14 : 10),
              border: Border.all(
                color: item.isChecked
                    ? const Color(0xFF8ABF97)
                    : AdminTheme.border,
                width: item.isChecked ? 1.5 : 1,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(widget.enlarged ? 14 : 10),
              onTap: widget.canCheck && !_saving
                  ? () => _toggle(index, !item.isChecked)
                  : null,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.enlarged ? 12 : 8,
                  vertical: widget.enlarged ? 12 : 4,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Transform.scale(
                      scale: boxScale,
                      child: Checkbox(
                        value: item.isChecked,
                        activeColor: const Color(0xFF3E7D52),
                        onChanged: widget.canCheck && !_saving
                            ? (bool? value) => _toggle(index, value ?? false)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item.quantity}x ${item.name}',
                            style: TextStyle(
                              fontSize: titleSize,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                              color: item.isChecked
                                  ? AdminTheme.mutedDark
                                  : AdminTheme.textDark,
                              decoration: item.isChecked
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          if (item.addons.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              item.addons
                                  .map((addon) => '+ ${addon.name}')
                                  .join(' • '),
                              style: TextStyle(
                                fontSize: metaSize,
                                color: AdminTheme.mutedDark,
                              ),
                            ),
                          ],
                          if (item.isChecked && item.checkedBy.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              '✓ Na-check ni ${item.checkedBy}',
                              style: TextStyle(
                                fontSize: metaSize,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF2E6B40),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        if (widget.enlarged) ...[
          const SizedBox(height: 18),
          Text(
            widget.canCheck
                ? 'Tap an item para i-mark na tapos. Pwedeng i-check ng kitchen, waiter, at admin.'
                : 'View only — ang kitchen, waiter, at admin ang pwedeng mag-check ng items.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: AdminTheme.mutedDark,
            ),
          ),
        ],
      ],
    );
  }
}
