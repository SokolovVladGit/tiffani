import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/logger_service.dart';
import '../dto/article_block_dto.dart';
import '../dto/article_dto.dart';
import 'articles_supabase_data_source.dart';

class ArticlesSupabaseDataSourceImpl implements ArticlesSupabaseDataSource {
  final SupabaseClient _client;
  final LoggerService _logger;

  static const _articlesTable = 'articles';
  static const _blocksTable = 'article_blocks';

  const ArticlesSupabaseDataSourceImpl(this._client, this._logger);

  @override
  Future<List<ArticleDto>> getPublishedArticles({int limit = 10}) async {
    _logger.d('getPublishedArticles limit=$limit');
    try {
      final response = await _client
          .from(_articlesTable)
          .select('id, slug, title, excerpt, cover_image_url')
          .eq('is_published', true)
          .order('published_at', ascending: false)
          .limit(limit);
      final articles = response.map(ArticleDto.fromMap).toList();
      _logger.d('getPublishedArticles success: ${articles.length} articles');
      return articles;
    } catch (e) {
      _logger.e('getPublishedArticles failed: $e');
      rethrow;
    }
  }

  @override
  Future<ArticleDto?> getArticleBySlug(String slug) async {
    _logger.d('getArticleBySlug slug=$slug');
    try {
      final response = await _client
          .from(_articlesTable)
          .select()
          .eq('slug', slug)
          .eq('is_published', true)
          .maybeSingle();
      if (response == null) return null;
      return ArticleDto.fromMap(response);
    } catch (e) {
      _logger.e('getArticleBySlug failed: $e');
      rethrow;
    }
  }

  @override
  Future<List<ArticleBlockDto>> getArticleBlocks(String articleId) async {
    _logger.d('getArticleBlocks articleId=$articleId');
    try {
      final response = await _client
          .from(_blocksTable)
          .select()
          .eq('article_id', articleId)
          .order('sort_order', ascending: true);
      final blocks = response.map(ArticleBlockDto.fromMap).toList();
      _logger.d('getArticleBlocks success: ${blocks.length} blocks');
      return blocks;
    } catch (e) {
      _logger.e('getArticleBlocks failed: $e');
      rethrow;
    }
  }
}
