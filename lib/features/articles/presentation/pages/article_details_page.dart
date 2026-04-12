import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_decorations.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/hero_curve_clipper.dart';
import '../../domain/entities/article_block_entity.dart';
import '../cubit/article_details_cubit.dart';
import '../cubit/article_details_state.dart';
import '../navigation/article_details_payload.dart';
import '../widgets/article_block_renderer.dart';

class ArticleDetailsPage extends StatefulWidget {
  final ArticleDetailsPayload payload;

  const ArticleDetailsPage({super.key, required this.payload});

  @override
  State<ArticleDetailsPage> createState() => _ArticleDetailsPageState();
}

class _ArticleDetailsPageState extends State<ArticleDetailsPage> {
  late final ArticleDetailsCubit _cubit;

  bool get _hasImage =>
      widget.payload.coverImageUrl != null &&
      widget.payload.coverImageUrl!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _cubit = sl<ArticleDetailsCubit>()..load(widget.payload.slug);
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: _hasImage
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
          child: Stack(
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
                slivers: [
                  SliverToBoxAdapter(
                    child: _HeroCover(
                      imageUrl: widget.payload.coverImageUrl,
                      heroTag: widget.payload.heroTag,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.xl,
                        _hasImage ? AppSpacing.md : topPadding + 56,
                        AppSpacing.xl,
                        AppSpacing.xxl,
                      ),
                      child: Text(
                        widget.payload.title,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          height: 1.2,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: BlocBuilder<ArticleDetailsCubit,
                        ArticleDetailsState>(
                      builder: (context, state) {
                        return switch (state.status) {
                          ArticleDetailsStatus.loading =>
                            const _BlocksSkeleton(),
                          ArticleDetailsStatus.error => const _ErrorView(),
                          ArticleDetailsStatus.loaded
                              when state.article != null =>
                            _AnimatedEntrance(
                              child: _BlocksList(
                                blocks: state.article!.blocks,
                                skipTitle: widget.payload.title,
                              ),
                            ),
                          _ => const _ErrorView(),
                        };
                      },
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppSpacing.xxxl * 2),
                  ),
                ],
              ),
              Positioned(
                top: topPadding + AppSpacing.sm,
                left: AppSpacing.lg,
                child: const _BackButton(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero cover — image + gradient composed together inside Hero
// ---------------------------------------------------------------------------

class _HeroCover extends StatelessWidget {
  final String? imageUrl;
  final String? heroTag;

  const _HeroCover({this.imageUrl, this.heroTag});

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    if (!hasImage) return const SizedBox.shrink();

    final topPadding = MediaQuery.of(context).padding.top;
    final imageHeight = topPadding + 260;

    Widget content = ClipPath(
      clipper: const HeroCurveClipper(amplitude: 10),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: imageHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: imageUrl!,
              width: double.infinity,
              height: imageHeight,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                height: imageHeight,
                color: AppColors.skeleton,
              ),
              errorWidget: (_, __, ___) => Container(
                height: imageHeight,
                color: AppColors.skeleton,
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.08),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.25),
                    ],
                    stops: const [0.0, 0.2, 0.5, 1.0],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (heroTag != null) {
      content = Hero(
        tag: heroTag!,
        child: Material(
          type: MaterialType.transparency,
          child: content,
        ),
      );
    }

    return content;
  }
}

// ---------------------------------------------------------------------------
// Frosted back button
// ---------------------------------------------------------------------------

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.maybePop(context),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                color: Colors.white.withValues(alpha: 0.5),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 16,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Subtle content entrance animation
// ---------------------------------------------------------------------------

class _AnimatedEntrance extends StatelessWidget {
  final Widget child;

  const _AnimatedEntrance({required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
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

// ---------------------------------------------------------------------------
// Blocks list — dedup + lead paragraph detection
// ---------------------------------------------------------------------------

class _BlocksList extends StatelessWidget {
  final List<ArticleBlockEntity> blocks;
  final String? skipTitle;

  const _BlocksList({required this.blocks, this.skipTitle});

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredBlocks;
    if (filtered.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _buildChildren(filtered),
      ),
    );
  }

  List<Widget> _buildChildren(List<ArticleBlockEntity> blocks) {
    final widgets = <Widget>[];
    bool leadUsed = false;

    for (int i = 0; i < blocks.length; i++) {
      if (i > 0) {
        final gap = _spacingBetween(
          blocks[i - 1].blockType,
          blocks[i].blockType,
        );
        widgets.add(SizedBox(height: gap));
      }

      final block = blocks[i];
      final isLead = !leadUsed &&
          block.blockType == ArticleBlockType.paragraph &&
          block.textContent != null &&
          block.textContent!.trim().isNotEmpty;
      if (isLead) leadUsed = true;

      widgets.add(ArticleBlockRenderer(block: block, isLead: isLead));
    }

    return widgets;
  }

  static double _spacingBetween(
    ArticleBlockType prev,
    ArticleBlockType curr,
  ) {
    if (prev == ArticleBlockType.heading) return AppSpacing.md;
    if (prev == ArticleBlockType.paragraph &&
        curr == ArticleBlockType.paragraph) {
      return 18;
    }
    if (prev == ArticleBlockType.image || curr == ArticleBlockType.image) {
      return 28;
    }
    if (_isVisualBlock(prev) || _isVisualBlock(curr)) {
      return AppSpacing.xxl;
    }
    return AppSpacing.xl;
  }

  static bool _isVisualBlock(ArticleBlockType type) {
    return type == ArticleBlockType.image ||
        type == ArticleBlockType.quote ||
        type == ArticleBlockType.bulletList;
  }

  List<ArticleBlockEntity> get _filteredBlocks {
    if (skipTitle == null || blocks.isEmpty) return blocks;
    final first = blocks.first;
    if (first.blockType == ArticleBlockType.heading &&
        _isTitleDuplicate(first.textContent, skipTitle!)) {
      return blocks.sublist(1);
    }
    return blocks;
  }

  static bool _isTitleDuplicate(String? blockText, String pageTitle) {
    if (blockText == null || blockText.isEmpty) return false;
    return _normalize(blockText) == _normalize(pageTitle);
  }

  static String _normalize(String s) {
    return s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

// ---------------------------------------------------------------------------
// Blocks skeleton
// ---------------------------------------------------------------------------

class _BlocksSkeleton extends StatelessWidget {
  const _BlocksSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.md),
          _bar(height: 14),
          const SizedBox(height: AppSpacing.sm),
          _bar(height: 14),
          const SizedBox(height: AppSpacing.sm),
          _bar(width: 240, height: 14),
          const SizedBox(height: AppSpacing.xxl),
          _bar(height: 14),
          const SizedBox(height: AppSpacing.sm),
          _bar(height: 14),
          const SizedBox(height: AppSpacing.sm),
          _bar(width: 200, height: 14),
        ],
      ),
    );
  }

  static Widget _bar({double? width, required double height}) {
    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: AppDecorations.skeleton(radius: AppRadius.sm),
    );
  }
}

// ---------------------------------------------------------------------------
// Error view
// ---------------------------------------------------------------------------

class _ErrorView extends StatelessWidget {
  const _ErrorView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Ошибка загрузки',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
