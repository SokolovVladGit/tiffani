import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/catalog_sort_option.dart';
import '../../domain/repositories/catalog_repository.dart';
import 'catalog_filter_state.dart';

class CatalogFilterCubit extends Cubit<CatalogFilterState> {
  final CatalogRepository _repository;

  CatalogFilterCubit(this._repository) : super(const CatalogFilterState());

  Future<void> loadFilterOptions() async {
    emit(state.copyWith(isLoadingOptions: true));
    try {
      final results = await Future.wait([
        _repository.getAvailableBrands(),
        _repository.getAvailableCategories(),
        _repository.getAvailableMarks(),
      ]);
      emit(state.copyWith(
        availableBrands: results[0],
        availableCategories: results[1],
        availableMarks: results[2],
        isLoadingOptions: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoadingOptions: false,
        errorMessage: '$e',
      ));
    }
  }

  void setBrand(String? brand) {
    emit(state.copyWith(selectedBrand: brand, clearBrand: brand == null));
  }

  void setCategory(String? category) {
    emit(state.copyWith(
      selectedCategory: category,
      clearCategory: category == null,
    ));
  }

  void setMark(String? mark) {
    emit(state.copyWith(selectedMark: mark, clearMark: mark == null));
  }

  void setSortOption(CatalogSortOption option) {
    emit(state.copyWith(sortOption: option));
  }

  void clearAll() {
    emit(state.copyWith(
      clearBrand: true,
      clearCategory: true,
      clearMark: true,
      sortOption: CatalogSortOption.defaultOrder,
    ));
  }
}
