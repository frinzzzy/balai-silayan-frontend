import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'qr_scanner_screen.dart';
import 'services/google_auth_service.dart';
import 'services/google_web_button.dart';
import 'theme/app_theme.dart';

/// Landing / welcome screen.
///
/// Isang door lang: Google Sign-In muna bago ang table QR scan. Ang Dine In /
/// Take Out choice ay nasa checkout na, hindi na dito.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _isSigningIn = false;
  StreamSubscription<GoogleCustomerIdentity>? _webSignInSubscription;

  @override
  void initState() {
    super.initState();
    // Sa web, ang Google-rendered na button ang may hawak ng sign-in; dito
    // natin pinakikinggan ang successful sign-in events.
    if (kIsWeb) _listenForWebSignIn();
  }

  @override
  void dispose() {
    _webSignInSubscription?.cancel();
    super.dispose();
  }

  Future<void> _listenForWebSignIn() async {
    _webSignInSubscription = GoogleAuthService.webIdentityResults().listen(
      (GoogleCustomerIdentity identity) {
        if (!mounted) return;
        _openScanner(identity.displayName);
      },
      onError: (Object error) {
        if (!mounted) return;
        _showSignInError(
          error is GoogleAuthException
              ? error.message
              : 'Hindi natuloy ang Google Sign-In. Subukan muli.',
        );
      },
    );
  }

  void _openScanner(String displayName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Welcome, $displayName! I-scan ang QR ng inyong mesa.'),
        backgroundColor: const Color(0xFF203F35),
      ),
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const QrScannerScreen(),
        settings: const RouteSettings(name: 'qr_scanner'),
      ),
    );
  }

  Future<void> _signInAndContinue() async {
    if (_isSigningIn) return;
    setState(() => _isSigningIn = true);

    try {
      final GoogleCustomerIdentity identity =
          await GoogleAuthService.signInCustomerIdentity();
      if (!mounted) return;

      _openScanner(identity.displayName);
    } on GoogleAuthException catch (error) {
      if (!mounted) return;
      _showSignInError(error.message);
    } catch (_) {
      if (!mounted) return;
      _showSignInError('Hindi natuloy ang Google Sign-In. Subukan muli.');
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  void _showSignInError(String message) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFFDFA),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Sign-in failed',
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF203F35)),
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 13, color: Color(0xFF203F35), height: 1.4),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF203F35)),
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'OK',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundCream,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFFDF9),
              AppTheme.backgroundCream,
              Color(0xFFF1E9DE),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool isWide = constraints.maxWidth >= 900;
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 64 : 22,
                  vertical: isWide ? 48 : 30,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: isWide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Expanded(flex: 6, child: _BrandHero()),
                              const SizedBox(width: 52),
                              Expanded(
                                flex: 5,
                                child: _StartPanel(
                                  onSignIn: _signInAndContinue,
                                  isSigningIn: _isSigningIn,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const _BrandHero(compact: true),
                              const SizedBox(height: 30),
                              _StartPanel(
                                onSignIn: _signInAndContinue,
                                isSigningIn: _isSigningIn,
                              ),
                            ],
                          ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Brand side
// ─────────────────────────────────────────────────────────────

class _BrandHero extends StatelessWidget {
  final bool compact;
  const _BrandHero({this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surfaceIvory,
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.borderWarm),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'lib/logo/BalaiSilayanLogo_512.png',
              width: compact ? 78 : 92,
              height: compact ? 78 : 92,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(
                Icons.restaurant,
                size: compact ? 64 : 76,
                color: AppTheme.primaryCrimson,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        Text(
          'WELCOME TO',
          textAlign: compact ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.4,
            color: AppTheme.secondaryGold.withValues(alpha: 0.95),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Balai Silayan',
          textAlign: compact ? TextAlign.center : TextAlign.start,
          style: const TextStyle(
            fontSize: 34,
            height: 1.05,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
            color: AppTheme.darkCharcoal,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Korean & Filipino Cuisine',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
            color: AppTheme.mutedGray,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Taste the warmth of a home-cooked meal — order straight from your table, '
          'walang pila, walang hintay.',
          textAlign: compact ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            fontSize: 14.5,
            height: 1.55,
            color: AppTheme.textDark.withValues(alpha: 0.8),
          ),
        ),
        SizedBox(height: compact ? 26 : 36),

        // 3 steps
        const _StepsRow(),
      ],
    );
  }
}

class _StepsRow extends StatelessWidget {
  const _StepsRow();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        _StepTile(
          number: '1',
          icon: Icons.qr_code_scanner_rounded,
          title: 'Scan',
          caption: 'Table QR',
        ),
        _StepTile(
          number: '2',
          icon: Icons.restaurant_menu_rounded,
          title: 'Choose',
          caption: 'Your dishes',
        ),
        _StepTile(
          number: '3',
          icon: Icons.notifications_active_rounded,
          title: 'Track',
          caption: 'Live status',
        ),
      ],
    );
  }
}

class _StepTile extends StatelessWidget {
  final String number;
  final IconData icon;
  final String title;
  final String caption;

  const _StepTile({
    required this.number,
    required this.icon,
    required this.title,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceIvory,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderWarm),
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryCrimson.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 22, color: AppTheme.primaryCrimson),
              ),
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppTheme.secondaryGold,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    number,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.darkCharcoal,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10.5, color: AppTheme.mutedGray),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Start order + policy side
// ─────────────────────────────────────────────────────────────

class _StartPanel extends StatelessWidget {
  final VoidCallback onSignIn;
  final bool isSigningIn;

  const _StartPanel({
    required this.onSignIn,
    required this.isSigningIn,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: AppTheme.surfaceIvory,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppTheme.borderWarm),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 30,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppTheme.primaryCrimson.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.login_rounded,
                  size: 20,
                  color: AppTheme.primaryCrimson,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Sign in to start',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: AppTheme.darkCharcoal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Mag-sign in muna gamit ang Google account bago i-scan ang QR code '
            'ng mesa. Dito rin mapipili ang Dine In o Take Out sa checkout.',
            style: TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: AppTheme.mutedGray,
            ),
          ),
          const SizedBox(height: 22),
          if (kIsWeb)
            SizedBox(height: 54, child: buildGoogleWebSignInButton())
          else
            SizedBox(
              height: 54,
              child: OutlinedButton.icon(
                onPressed: isSigningIn ? null : onSignIn,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.darkCharcoal,
                  backgroundColor: Colors.white,
                  disabledForegroundColor: AppTheme.mutedGray,
                  side: const BorderSide(color: AppTheme.borderWarm),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: isSigningIn
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primaryCrimson,
                        ),
                      )
                    : const _GoogleGlyph(),
                label: Text(
                  isSigningIn ? 'Signing in…' : 'Continue with Google',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 10),
          const Center(
            child: Text(
              'Kakapag-scan ka lang ng table QR pagkatapos mag-sign in.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppTheme.mutedGray),
            ),
          ),
          const SizedBox(height: 22),
          const Divider(height: 1, color: AppTheme.borderWarm),
          const SizedBox(height: 18),
          const Text(
            'GOOD TO KNOW',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
              color: AppTheme.secondaryGold,
            ),
          ),
          const SizedBox(height: 12),
          const _PolicyItem(
            icon: Icons.storefront_rounded,
            text: 'I-scan ang QR sa mesa; piliin ang Dine In o Take Out sa checkout.',
          ),
          const _PolicyItem(
            icon: Icons.lock_outline_rounded,
            text: 'Huwag i-share ang QR code ng mesa para sa seguridad ng order.',
          ),
          const _PolicyItem(
            icon: Icons.notifications_none_rounded,
            text: 'Payagan ang notifications para ma-track ang status ng order.',
          ),
          const _PolicyItem(
            icon: Icons.receipt_long_rounded,
            text: 'Isang bill kada session — i-request sa staff kapag tapos na.',
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _PolicyItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isLast;

  const _PolicyItem({
    required this.icon,
    required this.text,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: AppTheme.secondaryGold),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: AppTheme.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Simpleng Google "G" mark para sa takeout button sa Android/iOS.
/// Sa web, ang tunay na Google-rendered na button ang ginagamit.
class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (Rect bounds) => const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF4285F4),
            Color(0xFFEA4335),
            Color(0xFFFBBC05),
            Color(0xFF34A853),
          ],
        ).createShader(bounds),
        child: const Text(
          'G',
          style: TextStyle(
            fontSize: 16,
            height: 1,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
