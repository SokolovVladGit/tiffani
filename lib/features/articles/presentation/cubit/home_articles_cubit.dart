import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/articles_repository.dart';
import 'home_articles_state.dart';

class HomeArticlesCubit extends Cubit<HomeArticlesState> {
  final ArticlesRepository _repository;

  HomeArticlesCubit(this._repository) : super(const HomeArticlesState());

  Future<void> load() async {
    if (state.status == HomeArticlesStatus.loaded) return;
    emit(state.copyWith(status: HomeArticlesStatus.loading));
    try {
      final articles = await _repository.getPublishedArticles();
      emit(state.copyWith(
        status: HomeArticlesStatus.loaded,
        articles: articles,
      ));
    } catch (_) {
      emit(state.copyWith(status: HomeArticlesStatus.error));
    }
  }
}
