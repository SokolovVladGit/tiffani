import '../../domain/entities/catalog_sort_option.dart';

class CatalogFilterState {
  final List<String> availableBrands;
  final List<String> availableCategories;
  final List<String> availableMarks;
  final String? selectedBrand;
  final String? selectedCategory;
  final String? selectedMark;
  final CatalogSortOption sortOption;
  final bool isLoadingOptions;
  final String? errorMessage;

  const CatalogFilterState({
    this.availableBrands = const [],
    this.availableCategories = const [],
    this.availableMarks = const [],
    this.selectedBrand,
    this.selectedCategory,
    this.selectedMark,
    this.sortOption = CatalogSortOption.defaultOrder,
    this.isLoadingOptions = false,
    this.errorMessage,
  });

  bool get hasActiveFilters =>
      selectedBrand != null ||
      selectedCategory != null ||
      selectedMark != null ||
      sortOption != CatalogSortOption.defaultOrder;

  CatalogFilterState copyWith({
    List<String>? availableBrands,
    List<String>? availableCategories,
    List<String>? availableMarks,
    String? selectedBrand,
    String? selectedCategory,
    String? selectedMark,
    CatalogSortOption? sortOption,
    bool? isLoadingOptions,
    String? errorMessage,
    bool clearBrand = false,
    bool clearCategory = false,
    bool clearMark = false,
  }) {
    return CatalogFilterState(
      availableBrands: availableBrands ?? this.availableBrands,
      availableCategories: availableCategories ?? this.availableCategories,
      availableMarks: availableMarks ?? this.availableMarks,
      selectedBrand:
          clearBrand ? null : (selectedBrand ?? this.selectedBrand),
      selectedCategory:
          clearCategory ? null : (selectedCategory ?? this.selectedCategory),
      selectedMark:
          clearMark ? null : (selectedMark ?? this.selectedMark),
      sortOption: sortOption ?? this.sortOption,
      isLoadingOptions: isLoadingOptions ?? this.isLoadingOptions,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
