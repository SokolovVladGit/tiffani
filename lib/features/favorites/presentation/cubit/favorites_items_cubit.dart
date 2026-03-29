import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../catalog/domain/repositories/catalog_repository.dart';
import 'favorites_items_state.dart';

class FavoritesItemsCubit extends Cubit<FavoritesItemsState> {
  final CatalogRepository _repository;

  FavoritesItemsCubit(this._repository)
      : super(const FavoritesItemsState());

  void removeLocally(String id) {
    final updated = state.items.where((item) => item.id != id).toList();
    emit(state.copyWith(items: updated));
  }

  Future<void> load(List<String> ids) async {
    if (ids.isEmpty) {
      emit(const FavoritesItemsState());
      return;
    }
    emit(state.copyWith(isLoading: true));
    try {
      final items = await _repository.getCatalogItemsByVariantIds(ids);
      emit(FavoritesItemsState(items: items));
    } catch (_) {
      emit(const FavoritesItemsState());
    }
  }
}
