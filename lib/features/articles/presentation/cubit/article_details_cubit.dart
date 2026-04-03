import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/articles_repository.dart';
import 'article_details_state.dart';

class ArticleDetailsCubit extends Cubit<ArticleDetailsState> {
  final ArticlesRepository _repository;

  ArticleDetailsCubit(this._repository)
      : super(const ArticleDetailsState());

  Future<void> load(String slug) async {
    emit(state.copyWith(status: ArticleDetailsStatus.loading));
    try {
      final article = await _repository.getArticleDetails(slug);
      if (article == null) {
        emit(state.copyWith(status: ArticleDetailsStatus.error));
        return;
      }
      emit(state.copyWith(
        status: ArticleDetailsStatus.loaded,
        article: article,
      ));
    } catch (_) {
      emit(state.copyWith(status: ArticleDetailsStatus.error));
    }
  }
}
