import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../home_metrics.dart';
import '../home_strings.dart';

const _telegramUrl = 'https://t.me/tiffani_beauty';
const _instagramUrl = 'https://instagram.com/tiffani_beauty';
const _privacyUrl = 'https://tiffani.md/privacy';
const _termsUrl = 'https://tiffani.md/terms';

const _primaryPhone = '+373 779 76 364';
const _primaryStore = 'Тирасполь, ул. 25 Октября 94';
const _email = 'tiffani.service@gmail.com';

/// Compact, monochrome contacts teaser.
///
/// Light-surface premium block — replaces the previous near-black "wall".
/// Shows only the essentials: label, primary phone, primary store,
/// compact social row, legal links, watermark.
class HomeContactsSection extends StatelessWidget {
  const HomeContactsSection({super.key});

  /// Clearance reserved at the bottom so the watermark sits comfortably
  /// above the floating bottom navigation capsule.
  ///
  /// Nav layout: capsule height 64 + bottom offset (`AppSpacing.sm = 8`) =
  /// 72 from the screen bottom. We add ~32 of breathing space on top of
  /// that, then `MediaQuery` safe-area inset on top.
  static const double _navClearance = 104;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        HomeMetrics.pageEdge + 4,
        0,
        HomeMetrics.pageEdge + 4,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: double.infinity,
            height: 0.5,
            color: AppColors.textPrimary.withValues(alpha: 0.10),
          ),
          const SizedBox(height: AppSpacing.xxl + 2),
          const _Eyebrow(),
          const SizedBox(height: AppSpacing.lg + 2),
          _PrimaryPhone(
            phone: _primaryPhone,
            onTap: () => _launch('tel:${_primaryPhone.replaceAll(' ', '')}'),
          ),
          const SizedBox(height: AppSpacing.sm + 4),
          const _StoreLine(text: _primaryStore),
          const SizedBox(height: AppSpacing.xl + 4),
          const _SocialRow(),
          const SizedBox(height: AppSpacing.xl),
          const _LegalLinks(),
          const SizedBox(height: AppSpacing.lg + 2),
          const Center(
            child: Text(
              'TIFFANI',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 3.6,
                color: Color(0xFFBDBDBD),
              ),
            ),
          ),
          SizedBox(height: _navClearance + bottomPadding),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Eyebrow — dotted line + KONTAKTY label
// ---------------------------------------------------------------------------

class _Eyebrow extends StatelessWidget {
  const _Eyebrow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 1,
          color: AppColors.textPrimary.withValues(alpha: 0.36),
        ),
        const SizedBox(width: AppSpacing.sm + 2),
        Text(
          HomeStrings.contactsSection.toUpperCase(),
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.6,
            height: 1.0,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm + 2),
        Container(
          width: 16,
          height: 1,
          color: AppColors.textPrimary.withValues(alpha: 0.36),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Primary phone — single tappable, slightly emphasized line
// ---------------------------------------------------------------------------

class _PrimaryPhone extends StatelessWidget {
  final String phone;
  final VoidCallback onTap;

  const _PrimaryPhone({required this.phone, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          phone,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            letterSpacing: 0.4,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Store line — single primary address
// ---------------------------------------------------------------------------

class _StoreLine extends StatelessWidget {
  final String text;

  const _StoreLine({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary.withValues(alpha: 0.85),
        height: 1.5,
        letterSpacing: 0.2,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Social row — Telegram, email, Instagram
// ---------------------------------------------------------------------------

class _SocialRow extends StatelessWidget {
  const _SocialRow();

  static const _iconSize = 17.0;

  static final _iconColor = ColorFilter.mode(
    AppColors.textSecondary.withValues(alpha: 0.78),
    BlendMode.srcIn,
  );

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SocialIcon(
          onTap: () => _launch(_telegramUrl),
          child: SvgPicture.asset(
            'assets/icons/telegram.svg',
            width: _iconSize,
            height: _iconSize,
            colorFilter: _iconColor,
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        _SocialIcon(
          onTap: () => _launch('mailto:$_email'),
          child: Icon(
            Icons.alternate_email_rounded,
            size: _iconSize,
            color: AppColors.textSecondary.withValues(alpha: 0.78),
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        _SocialIcon(
          onTap: () => _launch(_instagramUrl),
          child: SvgPicture.asset(
            'assets/icons/instagram.svg',
            width: _iconSize,
            height: _iconSize,
            colorFilter: _iconColor,
          ),
        ),
      ],
    );
  }
}

class _SocialIcon extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _SocialIcon({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.textPrimary.withValues(alpha: 0.10),
            width: 0.5,
          ),
        ),
        child: Center(child: child),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Legal links
// ---------------------------------------------------------------------------

class _LegalLinks extends StatelessWidget {
  const _LegalLinks();

  static const _style = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w400,
    color: Color(0xFF9A9A9A),
    height: 1.4,
    letterSpacing: 0.2,
  );

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () => _launch(_privacyUrl),
          behavior: HitTestBehavior.opaque,
          child: const Padding(
            padding: EdgeInsets.symmetric(
              vertical: AppSpacing.xs,
              horizontal: AppSpacing.xs,
            ),
            child: Text(HomeStrings.privacyPolicy, style: _style),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Text('·', style: _style),
        ),
        GestureDetector(
          onTap: () => _launch(_termsUrl),
          behavior: HitTestBehavior.opaque,
          child: const Padding(
            padding: EdgeInsets.symmetric(
              vertical: AppSpacing.xs,
              horizontal: AppSpacing.xs,
            ),
            child: Text(HomeStrings.termsOfUse, style: _style),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

Future<void> _launch(String url) async {
  try {
    await launchUrl(Uri.parse(url));
  } catch (e) {
    debugPrint('Could not launch $url: $e');
  }
}
