import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/get_favorites.dart';
import '../../domain/usecases/toggle_favorite.dart';
import 'favorites_state.dart';

class FavoritesCubit extends Cubit<FavoritesState> {
  final GetFavorites _getFavorites;
  final ToggleFavorite _toggleFavorite;

  FavoritesCubit(this._getFavorites, this._toggleFavorite)
      : super(const FavoritesState()) {
    loadFavorites();
  }

  Future<void> loadFavorites() async {
    emit(state.copyWith(isLoading: true));
    final ids = await _getFavorites();
    emit(state.copyWith(ids: ids, isLoading: false));
  }

  Future<void> toggle(String id) async {
    final updatedIds = Set<String>.from(state.ids);
    if (updatedIds.contains(id)) {
      updatedIds.remove(id);
    } else {
      updatedIds.add(id);
    }
    emit(state.copyWith(ids: updatedIds));
    await _toggleFavorite(id);
  }

  bool isFavorite(String id) => state.ids.contains(id);
}
