import 'catalog_sort_option.dart';

class CatalogFiltersEntity {
  final String? selectedBrand;
  final String? selectedCategory;
  final String? selectedMark;
  final CatalogSortOption sortOption;
  final bool saleOnly;

  const CatalogFiltersEntity({
    this.selectedBrand,
    this.selectedCategory,
    this.selectedMark,
    this.sortOption = CatalogSortOption.defaultOrder,
    this.saleOnly = false,
  });

  bool get isEmpty =>
      selectedBrand == null &&
      selectedCategory == null &&
      selectedMark == null &&
      sortOption == CatalogSortOption.defaultOrder &&
      !saleOnly;

  CatalogFiltersEntity copyWith({
    String? selectedBrand,
    String? selectedCategory,
    String? selectedMark,
    CatalogSortOption? sortOption,
    bool? saleOnly,
    bool clearBrand = false,
    bool clearCategory = false,
    bool clearMark = false,
  }) {
    return CatalogFiltersEntity(
      selectedBrand:
          clearBrand ? null : (selectedBrand ?? this.selectedBrand),
      selectedCategory:
          clearCategory ? null : (selectedCategory ?? this.selectedCategory),
      selectedMark:
          clearMark ? null : (selectedMark ?? this.selectedMark),
      sortOption: sortOption ?? this.sortOption,
      saleOnly: saleOnly ?? this.saleOnly,
    );
  }
}
