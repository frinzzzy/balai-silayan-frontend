import 'package:flutter/material.dart';

import 'qr_scanner_screen.dart';
import 'theme/app_theme.dart';

/// Landing / welcome screen bago mag-QR scan.
/// Brand hero + "Start Ordering" CTA + ordering policy.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  void _openScanner(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
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
                                  onStart: () => _openScanner(context),
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
                                onStart: () => _openScanner(context),
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
  final VoidCallback onStart;
  const _StartPanel({required this.onStart});

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
                  Icons.table_restaurant_rounded,
                  size: 20,
                  color: AppTheme.primaryCrimson,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Ready to order?',
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
            'I-scan ang QR code na nakapaskil sa mesa para magsimula. '
            'Kung wala kang makitang QR, magtanong lang sa aming staff.',
            style: TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: AppTheme.mutedGray,
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: onStart,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryCrimson,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
              label: const Text(
                'Start Ordering',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Center(
            child: Text(
              'Kailangan ng camera permission para sa QR scan.',
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
            text: 'Dine-in orders lamang — isang session kada mesa.',
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