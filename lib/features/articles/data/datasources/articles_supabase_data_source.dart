import '../dto/article_block_dto.dart';
import '../dto/article_dto.dart';

abstract interface class ArticlesSupabaseDataSource {
  Future<List<ArticleDto>> getPublishedArticles({int limit = 10});
  Future<ArticleDto?> getArticleBySlug(String slug);
  Future<List<ArticleBlockDto>> getArticleBlocks(String articleId);
}
