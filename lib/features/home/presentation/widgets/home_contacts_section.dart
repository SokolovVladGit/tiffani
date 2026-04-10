import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../home_strings.dart';

const _telegramUrl = 'https://t.me/tiffani_beauty';
const _instagramUrl = 'https://instagram.com/tiffani_beauty';
const _privacyUrl = 'https://tiffani.md/privacy';
const _termsUrl = 'https://tiffani.md/terms';

class HomeContactsSection extends StatelessWidget {
  const HomeContactsSection({super.key});

  static const _phones = [
    '+373 779 76 364',
    '+373 778 76 364',
    '+373 778 53 234',
  ];

  static const _email = 'tiffani.service@gmail.com';

  static const _stores = [
    'Тирасполь, ул. 25 Октября 94',
    'Тирасполь, ул. Юности 18/1',
    'Бендеры, ул. Ленина 15, ТЦ «Пассаж» бутик №14',
  ];

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 40),
      decoration: const BoxDecoration(
        color: AppColors.footerSurface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xxl,
              36,
              AppSpacing.xxl,
              0,
            ),
            child: Text(
              HomeStrings.contactsSection.toUpperCase(),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.footerTextPrimary,
                letterSpacing: 2.5,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          _ContactGroup(
            label: HomeStrings.contactsPhones,
            children: [
              for (final phone in _phones)
                _TappableRow(
                  text: phone,
                  onTap: () =>
                      _launch('tel:${phone.replaceAll(' ', '')}'),
                ),
            ],
          ),
          const _GroupDivider(),
          _ContactGroup(
            label: HomeStrings.contactsEmail,
            children: [
              _TappableRow(
                text: _email,
                secondary: true,
                onTap: () => _launch('mailto:$_email'),
              ),
            ],
          ),
          const _GroupDivider(),
          _ContactGroup(
            label: HomeStrings.contactsStores,
            children: [
              for (final address in _stores)
                _StaticRow(text: address),
            ],
          ),
          const SizedBox(height: AppSpacing.xxxl),
          const _SocialRow(),
          const SizedBox(height: AppSpacing.xl),
          const _LegalLinks(),
          const SizedBox(height: AppSpacing.lg),
          const Center(
            child: Text(
              'TIFFANI',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 3,
                color: AppColors.footerWatermark,
              ),
            ),
          ),
          SizedBox(height: AppSpacing.xxxl + AppSpacing.xxl + bottomPadding),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Thin divider between contact groups
// ---------------------------------------------------------------------------

class _GroupDivider extends StatelessWidget {
  const _GroupDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Container(
        height: 0.5,
        color: AppColors.footerDivider,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Contact group — editorial label + content rows
// ---------------------------------------------------------------------------

class _ContactGroup extends StatelessWidget {
  final String label;
  final List<Widget> children;

  const _ContactGroup({
    required this.label,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.xl,
        AppSpacing.xxl,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.footerLabel,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.sm),
            children[i],
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tappable row — phone / email
// ---------------------------------------------------------------------------

class _TappableRow extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final bool secondary;

  const _TappableRow({
    required this.text,
    required this.onTap,
    this.secondary = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Text(
            text,
            style: TextStyle(
              fontSize: secondary ? 14 : 15,
              fontWeight: secondary ? FontWeight.w400 : FontWeight.w500,
              color: AppColors.footerAction,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Static row — addresses (display only)
// ---------------------------------------------------------------------------

class _StaticRow extends StatelessWidget {
  final String text;

  const _StaticRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.footerTextSecondary,
        height: 1.65,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Social icons row
// ---------------------------------------------------------------------------

class _SocialRow extends StatelessWidget {
  const _SocialRow();

  static const _iconSize = 20.0;
  static final _iconColor = ColorFilter.mode(
    AppColors.footerIcon,
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
        const SizedBox(width: AppSpacing.xxl),
        _SocialIcon(
          onTap: () =>
              _launch('mailto:${HomeContactsSection._email}'),
          child: Icon(
            Icons.alternate_email_rounded,
            size: _iconSize,
            color: AppColors.footerIcon,
          ),
        ),
        const SizedBox(width: AppSpacing.xxl),
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
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.footerDivider,
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
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.footerLabel,
    height: 1.4,
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
