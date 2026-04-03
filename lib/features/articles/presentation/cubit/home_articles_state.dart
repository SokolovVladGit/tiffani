import '../../domain/entities/article_entity.dart';

enum HomeArticlesStatus { initial, loading, loaded, error }

class HomeArticlesState {
  final HomeArticlesStatus status;
  final List<ArticleEntity> articles;

  const HomeArticlesState({
    this.status = HomeArticlesStatus.initial,
    this.articles = const [],
  });

  HomeArticlesState copyWith({
    HomeArticlesStatus? status,
    List<ArticleEntity>? articles,
  }) {
    return HomeArticlesState(
      status: status ?? this.status,
      articles: articles ?? this.articles,
    );
  }
}
