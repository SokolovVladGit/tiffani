import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/glossary_about_body.dart';

/// Inline expanding editorial panel introducing the TIFFANI brand
/// inside the Care Guide screen.
///
/// Collapsed: compact preview card with kicker, title, short teaser,
/// and a quiet "Читать" affordance.
///
/// Expanded: the same header remains visually anchored, and a tonal
/// inset reading panel reveals a curated 3-paragraph excerpt from
/// `kGlossaryAboutBody`, followed by an elegant footer with a
/// secondary "Открыть полностью" link to the full `/glossary/about`
/// destination and a clear "Свернуть" affordance.
class CareGuideAboutPanel extends StatefulWidget {
  const CareGuideAboutPanel({super.key});

  /// Maximum number of paragraphs surfaced inline (curated excerpt).
  /// The full text continues to live on `/glossary/about`.
  static const int _excerptParagraphs = 3;

  @override
  State<CareGuideAboutPanel> createState() => _CareGuideAboutPanelState();
}

class _CareGuideAboutPanelState extends State<CareGuideAboutPanel> {
  static const _animDuration = Duration(milliseconds: 320);
  static const _animCurve = Curves.easeOutCubic;

  bool _expanded = false;
  bool _pressed = false;

  void _toggle() {
    HapticFeedback.selectionClick();
    setState(() => _expanded = !_expanded);
  }

  void _openFullPage() {
    HapticFeedback.selectionClick();
    context.push(RouteNames.glossaryAbout);
  }

  @override
  Widget build(BuildContext context) {
    final shadows = _expanded
        ? const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 22,
              spreadRadius: -4,
              offset: Offset(0, 10),
            ),
          ]
        : const [
            BoxShadow(
              color: Color(0x07000000),
              blurRadius: 12,
              spreadRadius: -2,
              offset: Offset(0, 5),
            ),
          ];

    final borderColor = AppColors.border.withValues(
      alpha: _expanded ? 0.35 : 0.5,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.992 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: _animDuration,
            curve: _animCurve,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: borderColor, width: 0.5),
              boxShadow: shadows,
            ),
            clipBehavior: Clip.antiAlias,
            child: AnimatedSize(
              duration: _animDuration,
              curve: _animCurve,
              alignment: Alignment.topCenter,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PanelHeader(
                    expanded: _expanded,
                    onTap: _toggle,
                  ),
                  AnimatedSwitcher(
                    duration: _animDuration,
                    switchInCurve: _animCurve,
                    switchOutCurve: _animCurve,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SizeTransition(
                        sizeFactor: animation,
                        axisAlignment: -1,
                        child: child,
                      ),
                    ),
                    child: _expanded
                        ? _ExpandedReadingArea(
                            key: const ValueKey('expanded'),
                            onOpenFull: _openFullPage,
                            onCollapse: _toggle,
                          )
                        : const SizedBox.shrink(key: ValueKey('collapsed')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Header — kicker, title, preview teaser, directional affordance
// ============================================================

class _PanelHeader extends StatelessWidget {
  final bool expanded;
  final VoidCallback onTap;

  const _PanelHeader({required this.expanded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg - 2,
            AppSpacing.lg,
            AppSpacing.lg - 2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Expanded(child: _HeaderKicker()),
                  _HeaderAffordance(expanded: expanded),
                ],
              ),
              const SizedBox(height: AppSpacing.sm + 2),
              Text(
                'История TIFFANI',
                style: AppTextStyles.sectionTitle.copyWith(
                  fontSize: 17,
                  height: 1.2,
                  letterSpacing: -0.25,
                  color: AppColors.textPrimary.withValues(alpha: 0.96),
                ),
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 220),
                crossFadeState: expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Спокойная роскошь, честный состав, '
                    'уважение к ритму кожи.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: AppColors.textSecondary
                          .withValues(alpha: 0.85),
                      letterSpacing: 0.05,
                    ),
                  ),
                ),
                secondChild: const SizedBox(height: 4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderKicker extends StatelessWidget {
  const _HeaderKicker();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 1,
          color: AppColors.textPrimary.withValues(alpha: 0.32),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          'О БРЕНДЕ',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary.withValues(alpha: 0.85),
            letterSpacing: 1.8,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}

class _HeaderAffordance extends StatelessWidget {
  final bool expanded;

  const _HeaderAffordance({required this.expanded});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeOut,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: child,
      ),
      child: expanded
          ? const SizedBox.shrink(key: ValueKey('expanded-aff'))
          : Row(
              key: const ValueKey('read-aff'),
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ЧИТАТЬ',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary.withValues(alpha: 0.85),
                    letterSpacing: 1.6,
                    height: 1.0,
                  ),
                ),
                const SizedBox(width: 7),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 14,
                  color: AppColors.textPrimary.withValues(alpha: 0.85),
                ),
              ],
            ),
    );
  }
}

// ============================================================
// Expanded reading area — tonal inset panel + curated excerpt
// ============================================================

class _ExpandedReadingArea extends StatelessWidget {
  final VoidCallback onOpenFull;
  final VoidCallback onCollapse;

  const _ExpandedReadingArea({
    super.key,
    required this.onOpenFull,
    required this.onCollapse,
  });

  @override
  Widget build(BuildContext context) {
    final paragraphs = glossaryAboutParagraphs()
        .take(CareGuideAboutPanel._excerptParagraphs)
        .toList(growable: false);

    if (paragraphs.isEmpty) return const SizedBox.shrink();

    final lead = paragraphs.first;
    final rest = paragraphs.skip(1).toList(growable: false);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg - 2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 360),
            curve: Curves.easeOut,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 6 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg + 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceWarm,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: AppColors.textPrimary.withValues(alpha: 0.05),
                  width: 0.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    lead,
                    style: TextStyle(
                      fontSize: 15.5,
                      height: 1.6,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary.withValues(alpha: 0.95),
                      letterSpacing: -0.1,
                    ),
                  ),
                  if (rest.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md + 2),
                    Container(
                      width: 28,
                      height: 0.5,
                      color: AppColors.textPrimary.withValues(alpha: 0.18),
                    ),
                    const SizedBox(height: AppSpacing.md + 2),
                    for (var i = 0; i < rest.length; i++) ...[
                      if (i > 0) const SizedBox(height: AppSpacing.md + 2),
                      Text(
                        rest[i],
                        style: TextStyle(
                          fontSize: 14.5,
                          height: 1.7,
                          color: AppColors.textPrimary.withValues(
                            alpha: 0.82,
                          ),
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.05,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md + 2),
          _ExpandedFooter(
            onOpenFull: onOpenFull,
            onCollapse: onCollapse,
          ),
        ],
      ),
    );
  }
}

class _ExpandedFooter extends StatelessWidget {
  final VoidCallback onOpenFull;
  final VoidCallback onCollapse;

  const _ExpandedFooter({
    required this.onOpenFull,
    required this.onCollapse,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _FooterAction(
          label: 'ОТКРЫТЬ ПОЛНОСТЬЮ',
          trailingIcon: Icons.arrow_forward_rounded,
          alpha: 0.62,
          onTap: onOpenFull,
        ),
        const Spacer(),
        _FooterAction(
          label: 'СВЕРНУТЬ',
          leadingIcon: Icons.keyboard_arrow_up_rounded,
          alpha: 0.92,
          onTap: onCollapse,
        ),
      ],
    );
  }
}

class _FooterAction extends StatelessWidget {
  final String label;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final double alpha;
  final VoidCallback onTap;

  const _FooterAction({
    required this.label,
    this.leadingIcon,
    this.trailingIcon,
    required this.alpha,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.textPrimary.withValues(alpha: alpha);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 4,
          vertical: 6,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leadingIcon != null) ...[
              Icon(leadingIcon, size: 14, color: color),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
                letterSpacing: 1.4,
                height: 1.0,
              ),
            ),
            if (trailingIcon != null) ...[
              const SizedBox(width: 7),
              Icon(trailingIcon, size: 14, color: color),
            ],
          ],
        ),
      ),
    );
  }
}
