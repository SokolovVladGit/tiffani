import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/article_entity.dart';
import '../navigation/article_details_payload.dart';
import '../pages/article_details_page.dart';

/// Editorial recommendation card.
///
/// Magazine-style framing: full-bleed image, subtle hairline frame,
/// monochrome eyebrow + multi-stop dark scrim for legibility, restrained
/// downward shadow.
class RecommendationCard extends StatelessWidget {
  final ArticleEntity article;

  const RecommendationCard({super.key, required this.article});

  static const double cardWidth = 188;
  static const double cardHeight = 240;

  static const _eyebrow = 'ЖУРНАЛ';

  String get _heroTag => 'article_${article.id}';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ArticleDetailsPage(
            payload: ArticleDetailsPayload(
              slug: article.slug,
              title: article.title,
              coverImageUrl: article.coverImageUrl,
              heroTag: _heroTag,
            ),
          ),
        ),
      ),
      child: Container(
        width: cardWidth,
        height: cardHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 22,
              spreadRadius: -4,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Hero(tag: _heroTag, child: _buildImage()),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x33000000),
                      Color(0x00000000),
                      Color(0x80000000),
                      Color(0xCC000000),
                    ],
                    stops: [0.0, 0.32, 0.78, 1.0],
                  ),
                ),
              ),
              Positioned(
                left: AppSpacing.md + 2,
                right: AppSpacing.md + 2,
                bottom: AppSpacing.md + 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 12,
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _eyebrow,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.85),
                            letterSpacing: 2.2,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      article.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.28,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                        width: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    final url = article.coverImageUrl;
    if (url != null && url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (_, _) => Container(color: AppColors.skeleton),
        errorWidget: (_, _, _) => Container(
          color: AppColors.skeleton,
          child: const Center(
            child: Icon(Icons.image_outlined, color: AppColors.textTertiary),
          ),
        ),
      );
    }
    return Container(
      color: AppColors.surfaceDim,
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          size: 28,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }
}
