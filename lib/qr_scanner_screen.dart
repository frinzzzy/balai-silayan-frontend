import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'order_type_selection_screen.dart';
import 'user_session.dart'; // import your new session file


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

  void _handleScan(String scannedValue) {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    int scannedTableId = 1;
    int scannedTableNumber = 1;
    String? qrToken;

    final String cleanVal = scannedValue.trim();

    // 1. Try extracting consecutive numbers (e.g., "TABLE-12", "table/05", "15")
    final RegExp digitRegExp = RegExp(r'\d+');
    final match = digitRegExp.firstMatch(cleanVal);

    if (match != null) {
      final parsed = int.tryParse(match.group(0)!);
      if (parsed != null && parsed > 0) {
        scannedTableId = parsed;
        scannedTableNumber = parsed;
      }
    }

    // 2. Extract QR token if present
    if (cleanVal.contains('/scan/')) {
      qrToken = cleanVal.split('/scan/').last;
    } else if (!cleanVal.toLowerCase().contains('table')) {
      qrToken = cleanVal;
    }

    // 3. Save directly to UserSession state so table ID persists across all screens
    UserSession.activeTableId = scannedTableId;
    UserSession.activeTableNumber = scannedTableNumber;
    UserSession.qrToken = qrToken;

    _scannerController.stop();

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => OrderTypeSelectionScreen(
            tableId: scannedTableId,
            tableNumber: scannedTableNumber,
            qrToken: qrToken,
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
        backgroundColor: const Color(0xFFFFFDFA),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Enter Table Code', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF203F35))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your table number or QR token below:',
              style: TextStyle(fontSize: 12, color: Color(0xFF788078)),
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
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF788078))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF203F35),
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

      if (image == null) return; // User closed picker

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
            backgroundColor: Color(0xFF8E5136),
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
      backgroundColor: const Color(0xFFF8F4EC),
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
                          color: const Color(0xFFE5DFD3),
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Color(0xFF203F35),
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
                            color: const Color(0xFFA47C3D),
                            width: 1.4,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.home_outlined,
                          size: 14,
                          color: Color(0xFFA47C3D),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'BALAI SILAYAN',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF203F35),
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFE5DFD3),
                      ),
                    ),
                    child: const Icon(
                      Icons.notifications_outlined,
                      color: Color(0xFF203F35),
                      size: 20,
                    ),
                  ),
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
                color: const Color(0xFFEEE7D9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.qr_code_scanner,
                        size: 14,
                        color: Color(0xFFA47C3D),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'SCAN TABLE QR',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF203F35),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'SESSION ACTIVE',
                    style: TextStyle(
                      fontSize: 10,
                      color: Color(0xFF788078),
                      fontWeight: FontWeight.w500,
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
                        color: Color(0xFFA47C3D),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),

                    const Text(
                      'Scan Table QR Code',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF203F35),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),

                    const Text(
                      'Position the QR code on your dining table within the box below.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF788078),
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
                                  color: const Color(0xFFA47C3D),
                                  width: 3,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),

                            Container(
                              width: 190,
                              height: 2,
                              color: const Color(0xFFD7BF91),
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
                            color: Color(0xFF788078),
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
                                    color: const Color(0xFFEEE7D9),
                                    border: Border.all(
                                      color: const Color(0xFFE5DFD3),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.photo_library_outlined,
                                    color: Color(0xFF203F35),
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
                                    color: const Color(0xFFFFFDFA),
                                    border: Border.all(
                                      color: const Color(0xFFE5DFD3),
                                    ),
                                  ),
                                  child: Icon(
                                    _isFlashOn
                                        ? Icons.flash_on
                                        : Icons.flash_off,
                                    color: const Color(0xFF203F35),
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
                        color: const Color(0xFFEAF0E9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            size: 18,
                            color: Color(0xFF53766C),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Scanning links your order to your specific dining table automatically.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF53766C),
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