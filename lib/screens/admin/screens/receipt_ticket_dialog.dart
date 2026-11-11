import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/admin_order_model.dart';
import '../../../config/business_info.dart';
import '../../../theme/app_theme.dart';

class ReceiptTicketDialog extends StatelessWidget {
  final AdminOrder order;
  final double grossTotal;
  final double discountAmount;
  final double netTotal;
  final double paid;
  final double change;
  final String discountType;
  final String paymentMethod;
  final int partySize;
  final int pwdCount;
  final String customerName;
  final String idNumber;
  final String cashierName;

  ReceiptTicketDialog({
    super.key,
    required this.order,
    required this.grossTotal,
    required this.discountAmount,
    required this.netTotal,
    required this.paid,
    required this.change,
    required this.discountType,
    required this.paymentMethod,
    required this.partySize,
    required this.pwdCount,
    required this.customerName,
    required this.idNumber,
    required this.cashierName,
  });

  static const int _maxItemsPerPage = 6;

  final Map<String, GlobalKey> _pageKeys = <String, GlobalKey>{
    'balai_receipt_page_0': GlobalKey(debugLabel: 'balai_receipt_page_0'),
  };

  // VAT / discount computation (VAT-inclusive pricing model).
  double get _coveredSales {
    if (discountType == 'NONE') return 0.0;
    if (partySize <= 0 || pwdCount <= 0) return 0.0;
    return grossTotal * (pwdCount / partySize);
  }

  double get _computedDiscount => (_coveredSales / 1.12) * 0.20;
  double get _vatableSales => (grossTotal - _coveredSales) / 1.12;
  double get _vatAmount => (grossTotal - _coveredSales) - _vatableSales;
  double get _vatExemptSales => _coveredSales;

  String get _receiptNo => 'BS-${order.id}';
  DateTime get _ticketDateTime => order.createdAt ?? DateTime.now();
  String get _dateStr => DateFormat('dd MMM yyyy').format(_ticketDateTime);
  String get _timeStr => DateFormat('hh:mm a').format(_ticketDateTime);

  List<List<OrderLine>> _splitItemsIntoPages(List<OrderLine> items) {
    if (items.length <= _maxItemsPerPage) {
      return <List<OrderLine>>[items];
    }
    final List<List<OrderLine>> result = <List<OrderLine>>[];
    int i = 0;
    while (i < items.length) {
      final int end = (i + _maxItemsPerPage) < items.length ? (i + _maxItemsPerPage) : items.length;
      result.add(items.sublist(i, end));
      i = end;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final List<List<OrderLine>> pages = _splitItemsIntoPages(order.items);
    final List<Widget> pageWidgets = <Widget>[];
    for (int i = 0; i < pages.length; i++) {
      final GlobalKey key = _pageKeys.putIfAbsent(
        'balai_receipt_page_$i',
        () => GlobalKey(debugLabel: 'balai_receipt_page_$i'),
      );
      pageWidgets.add(
        RepaintBoundary(
          key: key,
          child: SizedBox(
            width: 340,
            child: _buildTicketColumn(
              items: pages[i],
              firstPage: i == 0,
              pageNo: i + 1,
              totalPages: pages.length,
            ),
          ),
        ),
      );
    }

    return AlertDialog(
      backgroundColor: AdminTheme.surfaceIvory,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.all(20),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: pageWidgets,
        ),
      ),
      actions: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.goldAccent,
                foregroundColor: AdminTheme.textDark,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.download_outlined, size: 18),
              label: const Text('Save Receipt as Image', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () async => await _saveReceipt(context),
            ),
            const SizedBox(height: 6),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.textDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.share, size: 18),
              label: const Text('Share Receipt', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              onPressed: () async => await _shareReceipt(context),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close & Complete', style: TextStyle(color: AdminTheme.mutedDark, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ],
    );
  }

  Future<List<File>> _captureReceiptPages() async {
    final List<List<OrderLine>> pages = _splitItemsIntoPages(order.items);
    final Directory tempDir = await getTemporaryDirectory();
    final List<File> savedFiles = <File>[];

    for (int i = 0; i < pages.length; i++) {
      final GlobalKey key = _pageKeys.putIfAbsent(
        'balai_receipt_page_$i',
        () => GlobalKey(debugLabel: 'balai_receipt_page_$i'),
      );
      final RenderRepaintBoundary? boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) break;

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) break;
      final Uint8List bytes = byteData.buffer.asUint8List();

      final File file = File('${tempDir.path}/balai_silayan_receipt_bs_${order.id}_p${i + 1}.png');
      await file.writeAsBytes(bytes);
      await Gal.putImageBytes(bytes, name: 'balai_silayan_receipt_bs_${order.id}_p${i + 1}.png');
      savedFiles.add(file);
    }

    return savedFiles;
  }

  Future<void> _saveReceipt(BuildContext context) async {
    final List<File> savedFiles = await _captureReceiptPages();
    if (!context.mounted) return;
    if (savedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save the receipt as an image.'), backgroundColor: AdminTheme.textDark),
      );
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Receipt saved as image! (${savedFiles.length} file${savedFiles.length > 1 ? 's' : ''})'), backgroundColor: AdminTheme.textDark),
    );
  }

  Future<void> _shareReceipt(BuildContext context) async {
    final List<File> savedFiles = await _captureReceiptPages();
    if (savedFiles.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to prepare the receipt for sharing.'), backgroundColor: AdminTheme.textDark),
      );
      return;
    }
    try {
      await SharePlus.instance.share(
        ShareParams(
          subject: 'Official Receipt - ${BusinessInfo.restaurantName}',
          text: 'Official Receipt - #BS-${order.id}',
          files: savedFiles.map((File f) => XFile(f.path)).toList(),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open the share sheet.'), backgroundColor: AdminTheme.textDark),
      );
    }
  }

  Widget _buildHeader({required bool compact}) {
    return Column(
      children: <Widget>[
        Text(
          BusinessInfo.restaurantName,
          style: const TextStyle(fontFamily: 'Libre Baskerville', fontWeight: FontWeight.bold, fontSize: 20, color: AdminTheme.textDark, letterSpacing: 1.2),
        ),
        const SizedBox(height: 2),
        Text(BusinessInfo.tagline, style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AdminTheme.mutedDark)),
        Text(BusinessInfo.receiptHeaderLine, style: const TextStyle(fontSize: 10, color: AdminTheme.mutedDark)),
        const SizedBox(height: 8),
        const Text('--------------------------------------------------', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 10)),
        const SizedBox(height: 4),
        const Text('OFFICIAL ORDER TICKET', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: AdminTheme.textDark)),
        const SizedBox(height: 4),
        const Text('--------------------------------------------------', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 10)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text('Date: $_dateStr', style: const TextStyle(fontSize: 11, color: AdminTheme.infoText)),
            Text('Time: $_timeStr', style: const TextStyle(fontSize: 11, color: AdminTheme.infoText)),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text('Order Code: #$_receiptNo', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AdminTheme.textDark)),
            Text('Table: ${order.tableNumber.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AdminTheme.textDark)),
          ],
        ),
        if (!compact) ...<Widget>[
          const SizedBox(height: 8),
          const Divider(thickness: 1, color: AdminTheme.border),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('ITEMS ORDERED:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[700])),
          ),
          const SizedBox(height: 4),
        ],
      ],
    );
  }

  Widget _buildItemRows(List<OrderLine> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: items.map((OrderLine line) => _buildItemRow(line)).toList(),
    );
  }

  Widget _buildItemRow(OrderLine line) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Expanded(
            child: Text(
              '${line.quantity}x ${line.name}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AdminTheme.textDark),
            ),
          ),
          Text(
            '₱${line.lineTotal.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AdminTheme.textDark),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(String title, String value, {bool isBold = false, bool isHighlight = false, bool isSmall = false, double fontSize = 12}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            title,
            style: TextStyle(fontSize: isSmall ? 10 : fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: isHighlight ? Colors.green[800] : (isSmall ? Colors.grey[600] : AdminTheme.textDark)),
          ),
          Text(
            value,
            style: TextStyle(fontSize: isSmall ? 10 : fontSize, fontWeight: isBold || isHighlight ? FontWeight.bold : FontWeight.normal, color: isHighlight ? Colors.green[800] : (isSmall ? Colors.grey[600] : AdminTheme.textDark)),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketColumn({
    required List<OrderLine> items,
    required bool firstPage,
    required int pageNo,
    required int totalPages,
  }) {
    final bool isLastPage = pageNo == totalPages;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        _buildHeader(compact: !firstPage),
        const SizedBox(height: 8),
        if (firstPage) ...<Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: Text('ITEMS ORDERED:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[700])),
          ),
          const SizedBox(height: 4),
        ],
        _buildItemRows(items),
        if (isLastPage) ...<Widget>[
          const SizedBox(height: 10),
          const Divider(thickness: 1, color: AdminTheme.border),
          const SizedBox(height: 6),
          _buildReceiptRow('Subtotal (Gross)', '₱${grossTotal.toStringAsFixed(2)}'),
          if (discountType != 'NONE')
            _buildReceiptRow('Discount ($discountType)', '-₱${_computedDiscount.toStringAsFixed(2)}', isHighlight: true),
          _buildReceiptRow('VATable Sales', '₱${_vatableSales.toStringAsFixed(2)}', isSmall: true),
          _buildReceiptRow('VAT Exempt Sales', '₱${_vatExemptSales.toStringAsFixed(2)}', isSmall: true),
          _buildReceiptRow('12% VAT', '₱${_vatAmount.toStringAsFixed(2)}', isSmall: true),
          const SizedBox(height: 4),
          _buildReceiptRow('TOTAL AMOUNT DUE', '₱${netTotal.toStringAsFixed(2)}', isBold: true, fontSize: 15),
          _buildReceiptRow('Amount Paid ($paymentMethod)', '₱${paid.toStringAsFixed(2)}'),
          _buildReceiptRow('Change', '₱${change.toStringAsFixed(2)}', isBold: true, isHighlight: true),
          const SizedBox(height: 14),
          const Text('--------------------------------------------------', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 10)),
          const SizedBox(height: 4),
          const Text('Salamat po sa pagtangkilik sa Balai Silayan!', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic, color: AdminTheme.textDark)),
          const SizedBox(height: 4),
          const Text('THIS RECEIPT SERVES AS AN OFFICIAL TICKET.\nPLEASE RETAIN THIS FOR TABLE SERVICE VALIDATION.', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, color: AdminTheme.mutedDark, height: 1.3)),
          if (totalPages > 1) ...<Widget>[
            const SizedBox(height: 8),
            Text('PAGE $pageNo OF $totalPages', textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AdminTheme.mutedDark)),
          ],
        ],
      ],
    );
  }
}
