import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/article_entity.dart';
import '../navigation/article_details_payload.dart';
import '../pages/article_details_page.dart';

class RecommendationCard extends StatelessWidget {
  final ArticleEntity article;

  const RecommendationCard({super.key, required this.article});

  static const double cardWidth = 168;

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
      child: SizedBox(
        width: cardWidth,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Hero(
                tag: _heroTag,
                child: _buildImage(),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.6),
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),
              Positioned(
                left: AppSpacing.md,
                right: AppSpacing.md,
                bottom: AppSpacing.md,
                child: Text(
                  article.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    height: 1.3,
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
        placeholder: (_, __) => Container(color: AppColors.skeleton),
        errorWidget: (_, __, ___) => Container(
          color: AppColors.skeleton,
          child: const Center(
            child: Icon(
              Icons.image_outlined,
              color: AppColors.textTertiary,
            ),
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
