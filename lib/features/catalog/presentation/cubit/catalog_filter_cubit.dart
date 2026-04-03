import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/catalog_sort_option.dart';
import '../../domain/helpers/category_parser.dart';
import '../../domain/usecases/get_all_brands_use_case.dart';
import '../../domain/usecases/get_available_categories_use_case.dart';
import '../../domain/usecases/get_available_marks_use_case.dart';
import 'catalog_filter_state.dart';

class CatalogFilterCubit extends Cubit<CatalogFilterState> {
  final GetAllBrandsUseCase _getAllBrands;
  final GetAvailableCategoriesUseCase _getCategories;
  final GetAvailableMarksUseCase _getMarks;

  CatalogFilterCubit(
    this._getAllBrands,
    this._getCategories,
    this._getMarks,
  ) : super(const CatalogFilterState());

  Future<void> loadFilterOptions() async {
    emit(state.copyWith(isLoadingOptions: true));
    try {
      final results = await Future.wait([
        _getAllBrands(),
        _getCategories(),
        _getMarks(),
      ]);
      emit(state.copyWith(
        availableBrands: results[0],
        availableCategories: CategoryParser.extractTopLevel(results[1]),
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
