import 'article_block_entity.dart';

class ArticleDetailsEntity {
  final String id;
  final String title;
  final String? coverImageUrl;
  final List<ArticleBlockEntity> blocks;

  const ArticleDetailsEntity({
    required this.id,
    required this.title,
    this.coverImageUrl,
    this.blocks = const [],
  });
}
