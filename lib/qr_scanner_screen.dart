import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'order_type_selection_screen.dart';
import 'user_session.dart';
import 'theme/app_theme.dart';
import 'config/api_config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'services/supabase_realtime_service.dart';
import 'widgets/session_notice_sheet.dart';
import 'welcome_screen.dart';

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

  /// Palaging bumabalik sa Welcome/login — kahit itong scanner ang root page
  /// (walang route sa ilalim) o kahit may restored session mula sa nakaraang
  /// QR scan. `maybePop` lang dati kaya minsan walang nangyayari sa back.
  Future<void> _backToWelcome() async {
    UserSession.clearSession();
    if (!mounted) return;
    await Navigator.of(context).pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  Future<void> _handleScan(String scannedValue) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    // Itigil muna ang camera habang nagche-check para hindi paulit-ulit na
    // ma-detect ang parehong QR at para hindi magdoble ang dialog.
    try {
      await _scannerController.stop();
    } catch (_) {}

    bool navigated = false;

    try {
      final String cleanVal = scannedValue.trim();
      if (cleanVal.isEmpty) {
        await _showScanFailure(
          title: 'Invalid QR Code',
          message:
              'This QR is invalid. Please scan a Balai Silayan table QR code.',
        );
        return;
      }

      final Uri scanUri = Uri.parse(cleanVal.startsWith('http')
          ? cleanVal
          : '${ApiConfig.baseUrl}/api/session/scan/$cleanVal');

      // Login-first flow: ang Google identity token ang nagpapatunay kung
      // kaninong customer ang mesa. Ito ang basis ng customer_id sa session.
      final String? identityToken = UserSession.identityToken;
      final Map<String, String> scanHeaders = <String, String>{
        if (identityToken != null && identityToken.isNotEmpty)
          'Authorization': 'Bearer $identityToken',
      };

      final response = await http.get(scanUri, headers: scanHeaders).timeout(
            const Duration(seconds: 30),
          );

      if (response.statusCode == 200) {
        dynamic decoded;
        try {
          decoded = jsonDecode(response.body);
        } catch (_) {
          decoded = null;
        }

        final dynamic rawTableId =
            decoded is Map ? decoded['table_id'] : null;
        final dynamic rawTableNumber =
            decoded is Map ? decoded['table_number'] : null;
        final dynamic rawSessionId =
            decoded is Map ? decoded['session_id'] : null;
        final dynamic rawSessionToken =
            decoded is Map ? decoded['session_token'] : null;

        final int? sessionId = int.tryParse(rawSessionId?.toString() ?? '');
        final String sessionToken = rawSessionToken?.toString().trim() ?? '';

        // 200 pero kulang/malformed ang data = invalid pa rin.
        if (decoded is! Map ||
            sessionId == null ||
            sessionToken.isEmpty) {
          await _showScanFailure(
            title: 'Invalid QR Code',
            message:
                'This QR is invalid. Please scan a Balai Silayan table QR code.',
          );
          return;
        }

        final int tableId =
            int.tryParse(rawTableId?.toString() ?? '') ?? 1;
        final int tableNumber =
            int.tryParse(rawTableNumber?.toString() ?? '') ?? tableId;

        final dynamic rawCustomer = decoded['customer'];
        final Map<String, dynamic>? scannedCustomer =
            rawCustomer is Map ? Map<String, dynamic>.from(rawCustomer) : null;

        UserSession.setScannedSession(
          tableId: tableId,
          tableNumber: tableNumber,
          sessionNum: sessionId,
          token: sessionToken,
          qr: cleanVal,
          customer: scannedCustomer,
        );
        unawaited(SupabaseRealtimeService.instance.onSessionChanged());

        if (mounted) {
          await SessionNotice.showIfNeeded(context);
        }

        if (mounted) {
          navigated = true;
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
        return;
      }

      // Walang Google identity — pabalik sa Welcome para mag-sign in ulit.
      if (response.statusCode == 401) {
        if (mounted) {
          final bool? goLogin = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              backgroundColor: AppTheme.surfaceIvory,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Text(
                'Sign in required',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryCrimson,
                ),
              ),
              content: const Text(
                'Kailangan mag-sign in gamit ang Google bago mag-scan at '
                'mag-order. Subukan muli pagkatapos mag-sign in.',
                style: TextStyle(fontSize: 13, color: Color(0xFF203F35)),
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryCrimson,
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text(
                    'Back to Sign In',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          );
          if (goLogin == true) {
            _scannerController.stop();
            UserSession.clearSession();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const WelcomeScreen(),
                settings: const RouteSettings(name: 'welcome'),
              ),
            );
          }
        }
        return;
      }

      // 4xx = malamang invalid/expired/wrong table QR.
      if (response.statusCode >= 400 && response.statusCode < 500) {
        await _showScanFailure(
          title: 'Invalid QR Code',
          message:
              'This QR is invalid. Please scan a Balai Silayan table QR code.',
        );
        return;
      }

      // 5xx at iba pa = server issue, hindi kasalanan ng QR.
      await _showScanFailure(
        title: 'Unable to verify QR',
        message:
            'Unable to verify this QR right now. Please check your connection and try again.',
      );
    } on TimeoutException {
      await _showScanFailure(
        title: 'Unable to verify QR',
        message:
            'Unable to verify this QR right now. Please check your connection and try again.',
      );
    } catch (_) {
      await _showScanFailure(
        title: 'Unable to verify QR',
        message:
            'Unable to verify this QR right now. Please check your connection and try again.',
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
        // I-restart ang camera para makapag-scan muli pagkatapos ng error.
        if (!navigated) {
          try {
            await _scannerController.start();
          } catch (_) {}
        }
      }
    }
  }

  /// Dialog para sa invalid QR o network failure. Sarado lang kapag pinindot
  /// ng customer ang "Scan Again", at awtomatikong babalik sa scanning.
  Future<void> _showScanFailure({
    required String title,
    required String message,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceIvory,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(
              Icons.qr_code_2,
              color: AppTheme.primaryCrimson,
              size: 22,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryCrimson,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF203F35),
            height: 1.4,
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryCrimson,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Scan Again',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }


  Future<void> _handleManualFallback(String val) async {
    int scannedTableId = int.tryParse(val.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
    UserSession.setSession(
      tableId: scannedTableId,
      tableNumber: scannedTableId,
      qr: val,
    );
    unawaited(SupabaseRealtimeService.instance.onSessionChanged());
    _scannerController.stop();

    if (mounted) {
      await SessionNotice.showIfNeeded(context);
    }
    
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

  void _promptManualTableEntry() {
    if (!kDebugMode) return;
    final TextEditingController tableController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceIvory,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Enter Table Number', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryCrimson)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'For Testing: Enter the table number below.',
              style: TextStyle(fontSize: 12, color: AppTheme.mutedGray),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: tableController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Color(0xFF203F35), fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'e.g. 1, 7, 15',
                labelText: 'Table Number',
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
              final String val = tableController.text.trim();
              final int? parsedTableId = int.tryParse(val);
              if (parsedTableId == null || parsedTableId <= 0 || parsedTableId > 999) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid table number (1-999).'),
                    backgroundColor: Color(0xFF8E5136),
                  ),
                );
                return;
              }
              Navigator.pop(ctx);
              _handleManualFallback(val);
            },
            child: const Text('Continue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

      String? rawValue;

      if (kIsWeb) {
        // Sa Mobile Scanner 5.x pataas, hindi na ginagamit ang analyzeImageBytes
        // Ginagamit direktang analyzeImage kasama ang image.path (Blob URL) at ang
        // scanner engine sa ilalim ang humahawak ng browser-specific file loading.
        try {
          final BarcodeCapture? capture = await _scannerController.analyzeImage(image.path);
          if (capture != null && capture.barcodes.isNotEmpty) {
            rawValue = capture.barcodes.first.rawValue;
          }
        } catch (_) {}
      } else {
        // Para sa Android/iOS: Gamitin din ang file path
        try {
          final BarcodeCapture? capture = await _scannerController.analyzeImage(image.path);
          if (capture != null && capture.barcodes.isNotEmpty) {
            rawValue = capture.barcodes.first.rawValue;
          }
        } catch (_) {}
      }

      if (rawValue != null && rawValue.isNotEmpty) {
        // I-reset muna bago tawagin ang _handleScan (may sariling guard ito).
        if (mounted) setState(() => _isProcessing = false);
        await _handleScan(rawValue);
        return;
      }

      if (mounted) {
        setState(() => _isProcessing = false);
        await _showImageNoQrDialog();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        await _showImageNoQrDialog();
      }
    }
  }

  /// Kapag walang mabasang QR sa picture, hindi ito automatic na mag-o-open ng
  /// manual entry. Ipapakita muna kung bakit failed, pero may option pa rin
  /// para sa testing.
  Future<void> _showImageNoQrDialog() async {
    if (!mounted) return;
    final bool? enterManual = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceIvory,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(
              Icons.qr_code_2,
              color: AppTheme.primaryCrimson,
              size: 22,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Invalid QR Image',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryCrimson,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'No valid QR code found in this image. Please choose a clearer photo of the table QR code.',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF203F35),
            height: 1.4,
          ),
        ),
        actions: [
          // Testing-only fallback: hindi ito lumalabas sa release build.
          if (kDebugMode)
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Enter Table Manually',
                style: TextStyle(color: AppTheme.mutedGray),
              ),
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryCrimson,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Try Again',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (enterManual == true && mounted) {
      _promptManualTableEntry();
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
                    onTap: _backToWelcome,
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
                  const SizedBox(width: 44),
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

                            if (_isProcessing)
                              Positioned.fill(
                                child: ColoredBox(
                                  color: Colors.black54,
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 22,
                                        vertical: 18,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.surfaceIvory,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const SizedBox(
                                            width: 30,
                                            height: 30,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 3,
                                              color: AppTheme.primaryCrimson,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          const Text(
                                            'Scanning QR…',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.primaryCrimson,
                                            ),
                                          ),
                                        ],
                                      ),
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