import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/frosted_back_button.dart';
import '../../../../core/widgets/hero_curve_clipper.dart';
import '../../data/glossary_static_entries.dart';
import '../widgets/care_guide_about_panel.dart';
import '../widgets/glossary_expandable_card.dart';
import '../widgets/glossary_section_heading.dart';

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
            const Positioned.fill(child: ColoredBox(color: Color(0x38FFFFFF))),
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
                  padding: EdgeInsets.fromLTRB(0, AppSpacing.xxl, 0, 0),
                  sliver: SliverToBoxAdapter(child: CareGuideAboutPanel()),
                ),
                SliverToBoxAdapter(
                  child: GlossarySectionHeading(
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
                        child: GlossaryExpandableCard(
                          item: kGlossaryStaticItems[index],
                        ),
                      );
                    },
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height:
                        MediaQuery.paddingOf(context).bottom + AppSpacing.xxxl,
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
// REVEAL-ONCE — subtle fade + slide entrance, plays once per mount
// ============================================================

class _RevealOnce extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const _RevealOnce({required this.child, this.delay = Duration.zero});

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
