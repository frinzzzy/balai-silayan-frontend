import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'order_type_selection_screen.dart';
import 'user_session.dart';
import 'theme/app_theme.dart';
import 'config/api_config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isFlashOn = false;
  bool _isProcessing = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _handleScan(String scannedValue) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final String cleanVal = scannedValue.trim();

      final Uri scanUri = Uri.parse(cleanVal.startsWith('http')
          ? cleanVal
          : '${ApiConfig.baseUrl}/api/session/scan/$cleanVal');

      final response = await http.get(scanUri);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        final int tableId = decoded['table_id'] ?? 1;
        final int tableNumber = decoded['table_number'] ?? tableId;
        final int sessionId = decoded['session_id'];
        final String sessionToken = decoded['session_token'];

        UserSession.setSession(
          tableId: tableId,
          tableNumber: tableNumber,
          sessionNum: sessionId,
          token: sessionToken,
          qr: cleanVal,
        );

        _scannerController.stop();

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => OrderTypeSelectionScreen(
                tableId: tableId,
                tableNumber: tableNumber,
                qrToken: sessionToken,
              ),
            ),
          );
        }
      } else {
        _handleManualFallback(cleanVal);
      }
    } catch (_) {
      _handleManualFallback(scannedValue);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _handleManualFallback(String val) {
    int scannedTableId = int.tryParse(val.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
    UserSession.setSession(
      tableId: scannedTableId,
      tableNumber: scannedTableId,
      qr: val,
    );
    _scannerController.stop();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => OrderTypeSelectionScreen(
            tableId: scannedTableId,
            tableNumber: scannedTableId,
          ),
        ),
      );
    }
  }

  void _promptManualQrCodeEntry() {
    final TextEditingController tokenController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceIvory,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Enter Table Code', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryCrimson)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your table number or QR token below:',
              style: TextStyle(fontSize: 12, color: AppTheme.mutedGray),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: tokenController,
              decoration: const InputDecoration(
                hintText: 'e.g. TABLE-07 or 7',
                labelText: 'Table Number / QR Token',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.mutedGray)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryCrimson,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final val = tokenController.text.trim();
              if (val.isNotEmpty) {
                Navigator.pop(ctx);
                _handleScan(val);
              }
            },
            child: const Text('Submit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadQrImageFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (image == null) return;

      setState(() => _isProcessing = true);

      final BarcodeCapture? capture = await _scannerController.analyzeImage(image.path);
      if (capture != null && capture.barcodes.isNotEmpty) {
        final String? rawValue = capture.barcodes.first.rawValue;
        if (rawValue != null && rawValue.isNotEmpty) {
          _handleScan(rawValue);
          return;
        }
      }

      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No QR code found in selected photo. Please select another image or enter table number.'),
            backgroundColor: AppTheme.errorRust,
          ),
        );
        _promptManualQrCodeEntry();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _promptManualQrCodeEntry();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundCream,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 12.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () => Navigator.maybePop(context),
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.borderWarm,
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: AppTheme.primaryCrimson,
                        size: 20,
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      Container(
                        width: 26,
                        height: 22,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppTheme.secondaryGold,
                            width: 1.4,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.home_outlined,
                          size: 14,
                          color: AppTheme.secondaryGold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'BALAI SILAYAN',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryCrimson,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 44), // Balancer
                ],
              ),
            ),

            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 8.0,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 10.0,
              ),
              decoration: BoxDecoration(
                color: AppTheme.warmTint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.qr_code_scanner,
                    size: 14,
                    color: AppTheme.secondaryGold,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'SCAN TABLE QR CODE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryCrimson,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TABLE IDENTIFICATION',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.secondaryGold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),

                    const Text(
                      'Scan Table QR Code',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryCrimson,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),

                    const Text(
                      'Position the QR code on your dining table within the box below.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.mutedGray,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 20),

                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            MobileScanner(
                              controller: _scannerController,
                              onDetect: (capture) {
                                final List<Barcode> barcodes =
                                    capture.barcodes;

                                for (final barcode in barcodes) {
                                  if (barcode.rawValue != null &&
                                      barcode.rawValue!.isNotEmpty) {
                                    _handleScan(barcode.rawValue!);
                                    break;
                                  }
                                }
                              },
                            ),

                            Container(
                              width: 210,
                              height: 210,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: AppTheme.secondaryGold,
                                  width: 3,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),

                            Container(
                              width: 190,
                              height: 2,
                              color: AppTheme.cherryPink,
                            ),

                            Positioned(
                              bottom: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Align QR code inside frame',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Having trouble scanning?',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.mutedGray,
                          ),
                        ),
                        Row(
                          children: [
                            Tooltip(
                              message: 'Upload QR Image from Gallery',
                              child: InkWell(
                                onTap: _uploadQrImageFromGallery,
                                borderRadius: BorderRadius.circular(22),
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppTheme.warmTint,
                                    border: Border.all(
                                      color: AppTheme.borderWarm,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.photo_library_outlined,
                                    color: AppTheme.primaryCrimson,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Tooltip(
                              message: 'Toggle Flashlight',
                              child: InkWell(
                                onTap: () {
                                  _scannerController.toggleTorch();
                                  setState(() {
                                    _isFlashOn = !_isFlashOn;
                                  });
                                },
                                borderRadius: BorderRadius.circular(22),
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppTheme.surfaceIvory,
                                    border: Border.all(
                                      color: AppTheme.borderWarm,
                                    ),
                                  ),
                                  child: Icon(
                                    _isFlashOn
                                        ? Icons.flash_on
                                        : Icons.flash_off,
                                    color: AppTheme.primaryCrimson,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7E6E9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            size: 18,
                            color: AppTheme.primaryCrimson,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Scanning links your order to your specific dining table automatically.',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.primaryCrimson,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
