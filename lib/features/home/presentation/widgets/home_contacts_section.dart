import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/section_header.dart';
import '../home_strings.dart';

const _actionColor = Color(0xFFA87080);

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: HomeStrings.contactsSection,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xxxl,
            AppSpacing.lg,
            AppSpacing.md,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFEFBFC), Color(0xFFFCF6F8)],
              ),
              borderRadius: BorderRadius.circular(AppRadius.xxl),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                _ContactGroup(
                  label: HomeStrings.contactsStores,
                  isLast: true,
                  children: [
                    for (final address in _stores)
                      _StaticRow(text: address),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        const _SocialRow(),
        const SizedBox(height: AppSpacing.lg),
        const _LegalLinks(),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: Text(
            'TIFFANI',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 3,
              color: AppColors.seed.withValues(alpha: 0.35),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxxl + AppSpacing.xl),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Contact group — editorial label + content rows
// ---------------------------------------------------------------------------

class _ContactGroup extends StatelessWidget {
  final String label;
  final List<Widget> children;
  final bool isLast;

  const _ContactGroup({
    required this.label,
    required this.children,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.xl,
        AppSpacing.xxl,
        isLast ? AppSpacing.xxl : AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textTertiary,
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
              color: _actionColor,
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
        color: AppColors.textSecondary,
        height: 1.6,
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
    AppColors.textTertiary,
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
        const SizedBox(width: AppSpacing.xl),
        _SocialIcon(
          onTap: () =>
              _launch('mailto:${HomeContactsSection._email}'),
          child: Icon(
            Icons.alternate_email_rounded,
            size: _iconSize,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(width: AppSpacing.xl),
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
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: child,
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
    color: AppColors.textTertiary,
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
