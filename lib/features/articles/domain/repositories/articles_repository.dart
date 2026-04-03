import '../entities/article_details_entity.dart';
import '../entities/article_entity.dart';

abstract interface class ArticlesRepository {
  Future<List<ArticleEntity>> getPublishedArticles();
  Future<ArticleDetailsEntity?> getArticleDetails(String slug);
}
