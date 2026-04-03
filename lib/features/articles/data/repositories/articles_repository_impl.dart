import '../../../../core/services/logger_service.dart';
import '../../domain/entities/article_details_entity.dart';
import '../../domain/entities/article_entity.dart';
import '../../domain/repositories/articles_repository.dart';
import '../datasources/articles_supabase_data_source.dart';
import '../mappers/article_block_mapper.dart';
import '../mappers/article_mapper.dart';

class ArticlesRepositoryImpl implements ArticlesRepository {
  final ArticlesSupabaseDataSource _dataSource;
  final LoggerService _logger;

  const ArticlesRepositoryImpl(this._dataSource, this._logger);

  @override
  Future<List<ArticleEntity>> getPublishedArticles() async {
    _logger.d('ArticlesRepositoryImpl.getPublishedArticles');
    final dtos = await _dataSource.getPublishedArticles();
    return dtos.map((d) => d.toEntity()).toList();
  }

  @override
  Future<ArticleDetailsEntity?> getArticleDetails(String slug) async {
    _logger.d('ArticlesRepositoryImpl.getArticleDetails slug=$slug');
    final articleDto = await _dataSource.getArticleBySlug(slug);
    if (articleDto == null) return null;

    final blockDtos = await _dataSource.getArticleBlocks(articleDto.id);
    return ArticleDetailsEntity(
      id: articleDto.id,
      title: articleDto.title,
      coverImageUrl: articleDto.coverImageUrl,
      blocks: blockDtos.map((d) => d.toEntity()).toList(),
    );
  }
}
