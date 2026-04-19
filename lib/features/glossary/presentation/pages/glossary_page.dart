import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/frosted_back_button.dart';
import '../../../../core/widgets/hero_curve_clipper.dart';
import '../../data/glossary_static_entries.dart';
import '../../domain/entities/glossary_item.dart';
import '../widgets/care_guide_about_panel.dart';

/// "Уход и ингредиенты" — main editorial reference destination
/// covering brand context, ritual framing, ingredients, and terminology.
///
/// Composition (top → bottom):
///   - Hero ("Уход и ингредиенты")
///   - Editorial lead (kicker + body paragraph)
///   - About-brand inline editorial reveal panel
///   - Glossary section heading (rule + title + count + descriptor)
///   - Expandable glossary cards with monogram identity
class GlossaryPage extends StatefulWidget {
  const GlossaryPage({super.key});

  @override
  State<GlossaryPage> createState() => _GlossaryPageState();
}

class _GlossaryPageState extends State<GlossaryPage> {
  final _scrollController = ScrollController();
  final _heroOffset = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    _heroOffset.value = _scrollController.offset;
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _heroOffset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/home/bg.jpg',
                fit: BoxFit.cover,
              ),
            ),
            const Positioned.fill(
              child: ColoredBox(color: Color(0x38FFFFFF)),
            ),
            CustomScrollView(
              controller: _scrollController,
              cacheExtent: 600,
              slivers: [
                SliverToBoxAdapter(
                  child: ValueListenableBuilder<double>(
                    valueListenable: _heroOffset,
                    builder: (_, offset, __) =>
                        _GuideHeroHeader(scrollOffset: offset),
                  ),
                ),
                const SliverToBoxAdapter(child: _GuideLeadSection()),
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    0,
                    AppSpacing.xxl,
                    0,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(child: CareGuideAboutPanel()),
                ),
                SliverToBoxAdapter(
                  child: _GlossarySectionHeading(
                    count: kGlossaryStaticItems.length,
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.xxxl,
                  ),
                  sliver: SliverList.separated(
                    itemCount: kGlossaryStaticItems.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.md - 2),
                    itemBuilder: (context, index) {
                      return _RevealOnce(
                        delay: Duration(
                          milliseconds: (index * 26).clamp(0, 220),
                        ),
                        child: _GlossaryExpandableCard(
                          item: kGlossaryStaticItems[index],
                        ),
                      );
                    },
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: MediaQuery.paddingOf(context).bottom +
                        AppSpacing.xxxl,
                  ),
                ),
              ],
            ),
            Positioned(
              top: MediaQuery.paddingOf(context).top + AppSpacing.xs,
              left: AppSpacing.md,
              child: FrostedBackButton(onTap: () => context.pop()),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// HERO
// ============================================================

class _GuideHeroHeader extends StatelessWidget {
  final double scrollOffset;

  const _GuideHeroHeader({required this.scrollOffset});

  static const _parallaxExtra = 30.0;
  static const _parallaxRange = 200.0;
  static const _parallaxFactor = 0.15;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final imageHeight = topPadding + 280;
    final parallaxShift =
        scrollOffset.clamp(0.0, _parallaxRange) * _parallaxFactor;

    return ClipPath(
      clipper: const HeroCurveClipper(amplitude: 10),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: imageHeight,
        width: double.infinity,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              top: -_parallaxExtra + parallaxShift,
              left: 0,
              right: 0,
              height: imageHeight + _parallaxExtra * 2,
              child: Image.asset(
                'assets/images/home/guide.jpg',
                fit: BoxFit.cover,
                alignment: Alignment.center,
                errorBuilder: (_, _, _) => ColoredBox(
                  color: AppColors.skeleton,
                  child: Icon(
                    Icons.image_outlined,
                    size: 40,
                    color: AppColors.textTertiary.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.18),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.55),
                    ],
                    stops: const [0.0, 0.22, 0.48, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              left: AppSpacing.xxl,
              right: AppSpacing.xxl,
              bottom: 36,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'TIFFANI',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.82),
                      letterSpacing: 2.2,
                      height: 1.2,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm + 2),
                  Text(
                    'Уход и ингредиенты',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.08,
                      letterSpacing: -0.4,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.32),
                          blurRadius: 12,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm + 2),
                  Text(
                    'Ритуал, состав и термины ухода',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.88),
                      height: 1.4,
                      letterSpacing: 0.15,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.28),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// LEAD INTRO — short editorial paragraph (kicker + body)
// ============================================================

class _GuideLeadSection extends StatelessWidget {
  const _GuideLeadSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xxl + AppSpacing.xs,
        AppSpacing.lg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _EditorialKicker(text: 'ОТ TIFFANI'),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Коротко и по делу о компонентах ухода: что они делают, '
            'когда уместны и как складываются в спокойную, рабочую рутину — '
            'без громких обещаний и шумных активов.',
            style: TextStyle(
              fontSize: 15,
              height: 1.65,
              letterSpacing: 0.08,
              color: AppColors.textPrimary.withValues(alpha: 0.85),
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SECTION HEADING — Glossary
// ============================================================

class _GlossarySectionHeading extends StatelessWidget {
  final int count;

  const _GlossarySectionHeading({required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xxxl,
        AppSpacing.lg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 1.5,
            decoration: BoxDecoration(
              color: AppColors.textPrimary.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(height: AppSpacing.md + 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  'Глоссарий',
                  style: AppTextStyles.pageTitle.copyWith(
                    fontSize: 23,
                    letterSpacing: -0.35,
                    height: 1.05,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  '$count терминов',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textTertiary.withValues(alpha: 0.85),
                    letterSpacing: 0.15,
                    height: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          Text(
            'Ингредиенты и термины',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary.withValues(alpha: 0.72),
              height: 1.3,
              letterSpacing: 0.15,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// EDITORIAL KICKER — small rule + uppercase label
// ============================================================

class _EditorialKicker extends StatelessWidget {
  final String text;

  const _EditorialKicker({required this.text});

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
          text,
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

// ============================================================
// EXPANDABLE GLOSSARY CARD — composed header + monogram identity
// ============================================================

class _GlossaryExpandableCard extends StatefulWidget {
  final GlossaryItem item;

  const _GlossaryExpandableCard({required this.item});

  @override
  State<_GlossaryExpandableCard> createState() =>
      _GlossaryExpandableCardState();
}

class _GlossaryExpandableCardState extends State<_GlossaryExpandableCard>
    with SingleTickerProviderStateMixin {
  static const _animDuration = Duration(milliseconds: 280);
  static const _animCurve = Curves.easeOutCubic;

  bool _expanded = false;
  bool _pressed = false;

  void _toggle() {
    HapticFeedback.selectionClick();
    setState(() => _expanded = !_expanded);
  }

  String get _monogram {
    final raw = widget.item.title.trim();
    if (raw.isEmpty) return '·';
    return raw.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final shadows = _expanded
        ? AppShadows.cardPremium
        : const [
            BoxShadow(
              color: Color(0x07000000),
              blurRadius: 12,
              spreadRadius: -2,
              offset: Offset(0, 5),
            ),
          ];

    final borderColor = AppColors.border.withValues(
      alpha: _expanded ? 0.0 : 0.5,
    );

    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.987 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: AnimatedContainer(
          duration: _animDuration,
          curve: _animCurve,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: shadows,
            border: Border.all(color: borderColor, width: 0.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _toggle,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md + 2,
                  AppSpacing.md + 2,
                  AppSpacing.md,
                  AppSpacing.md + 2,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CardHeaderRow(
                      monogram: _monogram,
                      title: widget.item.title,
                      expanded: _expanded,
                      animDuration: _animDuration,
                      animCurve: _animCurve,
                    ),
                    AnimatedSize(
                      duration: _animDuration,
                      curve: _animCurve,
                      alignment: Alignment.topLeft,
                      child: _expanded
                          ? _ExpandedBody(
                              key: const ValueKey('expanded'),
                              text: widget.item.description,
                            )
                          : _CollapsedPreview(
                              key: const ValueKey('collapsed'),
                              text: widget.item.description,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// Card header
// ----------------------------------------------------------------------

class _CardHeaderRow extends StatelessWidget {
  final String monogram;
  final String title;
  final bool expanded;
  final Duration animDuration;
  final Curve animCurve;

  const _CardHeaderRow({
    required this.monogram,
    required this.title,
    required this.expanded,
    required this.animDuration,
    required this.animCurve,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _MonogramChip(letter: monogram, expanded: expanded),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary.withValues(alpha: 0.94),
              height: 1.2,
              letterSpacing: -0.25,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _ExpandIndicator(
          expanded: expanded,
          animDuration: animDuration,
          animCurve: animCurve,
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------------
// Monogram chip — leading identity element
// ----------------------------------------------------------------------

class _MonogramChip extends StatelessWidget {
  final String letter;
  final bool expanded;

  const _MonogramChip({required this.letter, required this.expanded});

  static const _size = 36.0;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surfaceWarm, AppColors.creamSubtle],
        ),
        borderRadius: BorderRadius.circular(AppRadius.md - 2),
        border: Border.all(
          color: AppColors.textPrimary.withValues(
            alpha: expanded ? 0.14 : 0.08,
          ),
          width: 0.5,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary.withValues(alpha: 0.78),
          height: 1.0,
          letterSpacing: -0.4,
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// Expand indicator — circular tinted background, rotating chevron
// ----------------------------------------------------------------------

class _ExpandIndicator extends StatelessWidget {
  final bool expanded;
  final Duration animDuration;
  final Curve animCurve;

  const _ExpandIndicator({
    required this.expanded,
    required this.animDuration,
    required this.animCurve,
  });

  static const _size = 28.0;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: animDuration,
      curve: animCurve,
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.textPrimary.withValues(
          alpha: expanded ? 0.06 : 0.0,
        ),
      ),
      alignment: Alignment.center,
      child: AnimatedRotation(
        turns: expanded ? 0.5 : 0.0,
        duration: animDuration,
        curve: animCurve,
        child: Icon(
          Icons.keyboard_arrow_down_rounded,
          size: 20,
          color: AppColors.textSecondary.withValues(
            alpha: expanded ? 0.92 : 0.7,
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// Collapsed preview — single line summary aligned with title column
// ----------------------------------------------------------------------

class _CollapsedPreview extends StatelessWidget {
  final String text;

  const _CollapsedPreview({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.sm,
        left: 36 + AppSpacing.md,
        right: AppSpacing.sm,
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          height: 1.4,
          color: AppColors.textSecondary.withValues(alpha: 0.85),
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// Expanded body — inset tonal panel + breathable paragraph
// ----------------------------------------------------------------------

class _ExpandedBody extends StatelessWidget {
  final String text;

  const _ExpandedBody({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.md,
        bottom: 2,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg - 2,
          AppSpacing.md + 2,
          AppSpacing.lg - 2,
          AppSpacing.md + 4,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceWarm,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: AppColors.textPrimary.withValues(alpha: 0.05),
            width: 0.5,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14.5,
            height: 1.68,
            color: AppColors.textPrimary.withValues(alpha: 0.82),
            fontWeight: FontWeight.w400,
            letterSpacing: 0.08,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// REVEAL-ONCE — subtle fade + slide entrance, plays once per mount
// ============================================================

class _RevealOnce extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const _RevealOnce({
    required this.child,
    this.delay = Duration.zero,
  });

  @override
  State<_RevealOnce> createState() => _RevealOnceState();
}

class _RevealOnceState extends State<_RevealOnce>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    final curve = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _opacity = Tween<double>(begin: 0, end: 1).animate(curve);
    _slide = Tween<Offset>(
      begin: const Offset(0, 10),
      end: Offset.zero,
    ).animate(curve);

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) => Opacity(
        opacity: _opacity.value,
        child: Transform.translate(offset: _slide.value, child: child),
      ),
      child: widget.child,
    );
  }
}
