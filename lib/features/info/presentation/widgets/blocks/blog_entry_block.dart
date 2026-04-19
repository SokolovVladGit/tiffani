import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/router/route_names.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_radius.dart';
import '../../../../../core/theme/app_shadows.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../domain/entities/info_block_entity.dart';

/// Editorial entry card linking the Info tab to the Care Guide (`/glossary`).
///
/// Reads optional `kicker` and `cta_label` from `block.itemsJson` and an
/// optional `imageUrl`. All extras are backward compatible — when absent,
/// the card renders a refined tonal monogram variant.
class BlogEntryBlock extends StatefulWidget {
  final InfoBlockEntity block;

  const BlogEntryBlock({super.key, required this.block});

  static const _defaultKicker = 'ГИД ПО УХОДУ';
  static const _defaultTitle = 'Состав, текстура, ритуал';
  static const _defaultSubtitle =
      'Разбираем активы и помогаем собрать спокойную, рабочую рутину.';
  static const _defaultCtaLabel = 'Открыть гид';

  @override
  State<BlogEntryBlock> createState() => _BlogEntryBlockState();
}

class _BlogEntryBlockState extends State<BlogEntryBlock> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  void _onTap() {
    HapticFeedback.lightImpact();
    context.push(RouteNames.glossary);
  }

  @override
  Widget build(BuildContext context) {
    final block = widget.block;

    final kicker = block.itemsJson?['kicker']?.toString().trim();
    final ctaLabel = block.itemsJson?['cta_label']?.toString().trim();
    final imageUrl = block.imageUrl?.trim();

    final resolvedKicker = (kicker != null && kicker.isNotEmpty)
        ? kicker
        : BlogEntryBlock._defaultKicker;
    final resolvedTitle = block.title?.trim().isNotEmpty == true
        ? block.title!.trim()
        : BlogEntryBlock._defaultTitle;
    final resolvedSubtitle = block.subtitle?.trim().isNotEmpty == true
        ? block.subtitle!.trim()
        : BlogEntryBlock._defaultSubtitle;
    final resolvedCta = (ctaLabel != null && ctaLabel.isNotEmpty)
        ? ctaLabel
        : BlogEntryBlock._defaultCtaLabel;

    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    final pressedShadow = const [
      BoxShadow(
        color: Color(0x07000000),
        blurRadius: 14,
        spreadRadius: -3,
        offset: Offset(0, 4),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Listener(
        onPointerDown: (_) => _setPressed(true),
        onPointerUp: (_) => _setPressed(false),
        onPointerCancel: (_) => _setPressed(false),
        child: AnimatedScale(
          scale: _pressed ? 0.985 : 1.0,
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOut,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _onTap,
              borderRadius: BorderRadius.circular(AppRadius.xxl),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.xxl),
                  border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.55),
                    width: 0.5,
                  ),
                  boxShadow: _pressed ? pressedShadow : AppShadows.cardPremium,
                ),
                clipBehavior: Clip.antiAlias,
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _MediaSlab(imageUrl: hasImage ? imageUrl : null),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg,
                            AppSpacing.md + 2,
                            AppSpacing.lg,
                            AppSpacing.md + 2,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _KickerLabel(text: resolvedKicker),
                              const SizedBox(height: AppSpacing.sm + 2),
                              Text(
                                resolvedTitle,
                                style: AppTextStyles.sectionTitle.copyWith(
                                  fontSize: 17,
                                  height: 1.22,
                                  letterSpacing: -0.25,
                                  color: AppColors.textPrimary
                                      .withValues(alpha: 0.96),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                resolvedSubtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.5,
                                  color: AppColors.textSecondary
                                      .withValues(alpha: 0.85),
                                  letterSpacing: 0.05,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md + 2),
                              _InlineAction(label: resolvedCta),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// MEDIA SLAB — left tonal area; image when provided, monogram otherwise
// ============================================================

class _MediaSlab extends StatelessWidget {
  final String? imageUrl;

  const _MediaSlab({required this.imageUrl});

  static const _slabWidth = 96.0;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return SizedBox(
      width: _slabWidth,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasImage)
            CachedNetworkImage(
              imageUrl: imageUrl!,
              fit: BoxFit.cover,
              placeholder: (_, __) => const _MonogramTone(),
              errorWidget: (_, __, ___) => const _MonogramTone(),
            )
          else
            const _MonogramTone(),
          if (hasImage)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0x14000000), Color(0x00000000)],
                ),
              ),
            ),
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            child: Container(
              width: 0.5,
              color: AppColors.border.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonogramTone extends StatelessWidget {
  const _MonogramTone();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceWarm,
            AppColors.creamSubtle,
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: 8,
            right: 8,
            top: 8,
            bottom: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.textPrimary.withValues(alpha: 0.06),
                  width: 0.5,
                ),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          ),
          Center(
            child: Text(
              'T',
              style: TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w800,
                letterSpacing: -2,
                height: 1,
                color: AppColors.textPrimary.withValues(alpha: 0.18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Atoms
// ============================================================

class _KickerLabel extends StatelessWidget {
  final String text;

  const _KickerLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 1,
          color: AppColors.textPrimary.withValues(alpha: 0.35),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary.withValues(alpha: 0.85),
              letterSpacing: 1.6,
              height: 1.0,
            ),
          ),
        ),
      ],
    );
  }
}

class _InlineAction extends StatelessWidget {
  final String label;

  const _InlineAction({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary.withValues(alpha: 0.92),
            letterSpacing: 1.4,
            height: 1.0,
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          Icons.arrow_forward_rounded,
          size: 14,
          color: AppColors.textPrimary.withValues(alpha: 0.88),
        ),
      ],
    );
  }
}
