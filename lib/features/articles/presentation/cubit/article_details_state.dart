import '../../domain/entities/article_details_entity.dart';

enum ArticleDetailsStatus { loading, loaded, error }

class ArticleDetailsState {
  final ArticleDetailsStatus status;
  final ArticleDetailsEntity? article;

  const ArticleDetailsState({
    this.status = ArticleDetailsStatus.loading,
    this.article,
  });

  ArticleDetailsState copyWith({
    ArticleDetailsStatus? status,
    ArticleDetailsEntity? article,
  }) {
    return ArticleDetailsState(
      status: status ?? this.status,
      article: article ?? this.article,
    );
  }
}
