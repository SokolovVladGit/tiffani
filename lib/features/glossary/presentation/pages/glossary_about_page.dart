import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/frosted_back_button.dart';
import '../../../../core/widgets/hero_curve_clipper.dart';
import '../../data/glossary_about_body.dart';

class GlossaryAboutPage extends StatelessWidget {
  const GlossaryAboutPage({super.key});

  static const _maxContentWidth = 560.0;

  @override
  Widget build(BuildContext context) {
    final paragraphs = kGlossaryAboutBody
        .trim()
        .split('\n\n')
        .where((p) => p.trim().isNotEmpty)
        .map((p) => p.trim())
        .toList();

    final topPadding = MediaQuery.paddingOf(context).top;

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
              cacheExtent: 600,
              slivers: [
                const SliverToBoxAdapter(child: _AboutHeroHeader()),
                SliverToBoxAdapter(
                  child: _AboutEntrance(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.xxl + AppSpacing.xs,
                        AppSpacing.lg,
                        AppSpacing.xxxl,
                      ),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: _maxContentWidth,
                          ),
                          child: _AboutBody(paragraphs: paragraphs),
                        ),
                      ),
                    ),
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
              top: topPadding + AppSpacing.xs,
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

class _AboutHeroHeader extends StatelessWidget {
  const _AboutHeroHeader();

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final imageHeight = topPadding + 240;

    return ClipPath(
      clipper: const HeroCurveClipper(amplitude: 10),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: imageHeight,
        width: double.infinity,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/home/history.jpg',
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
              bottom: 32,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'О БРЕНДЕ',
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
                    'История TIFFANI',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.05,
                      letterSpacing: -0.4,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 1),
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
// BODY — lead paragraph + readable column
// ============================================================

class _AboutBody extends StatelessWidget {
  final List<String> paragraphs;

  const _AboutBody({required this.paragraphs});

  @override
  Widget build(BuildContext context) {
    if (paragraphs.isEmpty) return const SizedBox.shrink();

    final lead = paragraphs.first;
    final rest = paragraphs.sublist(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 1,
              color: AppColors.textPrimary.withValues(alpha: 0.32),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'ИСТОРИЯ БРЕНДА',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary.withValues(alpha: 0.85),
                letterSpacing: 1.8,
                height: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md + 2),
        Text(
          lead,
          style: const TextStyle(
            fontSize: 17.5,
            height: 1.6,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            letterSpacing: -0.15,
          ),
        ),
        for (final paragraph in rest) ...[
          const SizedBox(height: AppSpacing.xl),
          Text(
            paragraph,
            style: TextStyle(
              fontSize: 15,
              height: 1.72,
              color: AppColors.textPrimary.withValues(alpha: 0.82),
              fontWeight: FontWeight.w400,
              letterSpacing: 0.05,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xxl),
        Container(
          width: 28,
          height: 1,
          color: AppColors.textPrimary.withValues(alpha: 0.22),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'TIFFANI',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textTertiary.withValues(alpha: 0.85),
            letterSpacing: 2.2,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// ENTRANCE — subtle fade + slide
// ============================================================

class _AboutEntrance extends StatelessWidget {
  final Widget child;

  const _AboutEntrance({required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
