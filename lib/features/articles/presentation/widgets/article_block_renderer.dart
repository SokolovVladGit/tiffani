import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/article_block_entity.dart';

class ArticleBlockRenderer extends StatelessWidget {
  final ArticleBlockEntity block;
  final bool isLead;

  const ArticleBlockRenderer({
    super.key,
    required this.block,
    this.isLead = false,
  });

  @override
  Widget build(BuildContext context) {
    return switch (block.blockType) {
      ArticleBlockType.heading => _HeadingBlock(text: block.textContent),
      ArticleBlockType.paragraph => _ParagraphBlock(
          text: block.textContent,
          isLead: isLead,
        ),
      ArticleBlockType.image => _ImageBlock(
          imageUrl: block.imageUrl,
          caption: block.caption,
        ),
      ArticleBlockType.bulletList => _BulletListBlock(items: block.items),
      ArticleBlockType.quote => _QuoteBlock(text: block.textContent),
      ArticleBlockType.unknown => const SizedBox.shrink(),
    };
  }
}

// ---------------------------------------------------------------------------
// Heading — section opener with clear hierarchy below page title
// ---------------------------------------------------------------------------

class _HeadingBlock extends StatelessWidget {
  final String? text;

  const _HeadingBlock({this.text});

  @override
  Widget build(BuildContext context) {
    if (text == null || text!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 2,
            height: 20,
            margin: const EdgeInsets.only(top: 3, right: 10),
            decoration: BoxDecoration(
              color: AppColors.seed.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          Expanded(
            child: Text(
              text!,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 1.3,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Paragraph — with optional lead treatment for first paragraph
// ---------------------------------------------------------------------------

class _ParagraphBlock extends StatelessWidget {
  final String? text;
  final bool isLead;

  const _ParagraphBlock({this.text, this.isLead = false});

  @override
  Widget build(BuildContext context) {
    if (text == null || text!.isEmpty) return const SizedBox.shrink();
    return Text(
      text!,
      style: TextStyle(
        fontSize: isLead ? 18 : 16,
        color: AppColors.textPrimary,
        height: isLead ? 1.55 : 1.65,
        letterSpacing: isLead ? -0.1 : 0,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Image block — editorial photo treatment with italic caption
// ---------------------------------------------------------------------------

class _ImageBlock extends StatelessWidget {
  final String? imageUrl;
  final String? caption;

  const _ImageBlock({this.imageUrl, this.caption});

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: CachedNetworkImage(
            imageUrl: imageUrl!,
            width: double.infinity,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              height: 200,
              color: AppColors.skeleton,
            ),
            errorWidget: (_, __, ___) => Container(
              height: 200,
              color: AppColors.skeleton,
              child: const Center(
                child: Icon(Icons.broken_image_outlined,
                    color: AppColors.textTertiary),
              ),
            ),
          ),
        ),
        if (caption != null && caption!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              caption!,
              style: const TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: AppColors.textTertiary,
                height: 1.4,
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Bullet list — branded dot indicator, premium spacing
// ---------------------------------------------------------------------------

class _BulletListBlock extends StatelessWidget {
  final List<String> items;

  const _BulletListBlock({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 5,
                height: 5,
                margin: const EdgeInsets.only(top: 10, right: 12),
                decoration: BoxDecoration(
                  color: AppColors.seed.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Text(
                  items[i],
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textPrimary,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Quote — refined editorial treatment
// ---------------------------------------------------------------------------

class _QuoteBlock extends StatelessWidget {
  final String? text;

  const _QuoteBlock({this.text});

  @override
  Widget build(BuildContext context) {
    if (text == null || text!.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 20, 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWarm,
        border: Border(
          left: BorderSide(
            color: AppColors.seed.withValues(alpha: 0.35),
            width: 3,
          ),
        ),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(AppRadius.md),
          bottomRight: Radius.circular(AppRadius.md),
        ),
      ),
      child: Text(
        text!,
        style: const TextStyle(
          fontSize: 16,
          fontStyle: FontStyle.italic,
          color: AppColors.textSecondary,
          height: 1.6,
          letterSpacing: 0.15,
        ),
      ),
    );
  }
}
