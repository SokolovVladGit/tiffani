import '../../domain/entities/catalog_filters_entity.dart';
import '../../domain/entities/catalog_item_entity.dart';

enum CatalogStatus { initial, loading, success, failure }

class CatalogState {
  final CatalogStatus status;
  final List<CatalogItemEntity> items;
  final int totalCount;
  final bool hasReachedMax;
  final bool isLoadingMore;
  final String? errorMessage;
  final String searchQuery;
  final CatalogFiltersEntity filters;
  final Map<String, Set<String>> attributeFilters;

  const CatalogState({
    this.status = CatalogStatus.initial,
    this.items = const [],
    this.totalCount = 0,
    this.hasReachedMax = false,
    this.isLoadingMore = false,
    this.errorMessage,
    this.searchQuery = '',
    this.filters = const CatalogFiltersEntity(),
    this.attributeFilters = const {},
  });

  bool get isSearching => searchQuery.trim().isNotEmpty;
  bool get hasActiveFilters =>
      !filters.isEmpty || attributeFilters.isNotEmpty;

  CatalogState copyWith({
    CatalogStatus? status,
    List<CatalogItemEntity>? items,
    int? totalCount,
    bool? hasReachedMax,
    bool? isLoadingMore,
    String? errorMessage,
    String? searchQuery,
    CatalogFiltersEntity? filters,
    Map<String, Set<String>>? attributeFilters,
  }) {
    return CatalogState(
      status: status ?? this.status,
      items: items ?? this.items,
      totalCount: totalCount ?? this.totalCount,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: errorMessage ?? this.errorMessage,
      searchQuery: searchQuery ?? this.searchQuery,
      filters: filters ?? this.filters,
      attributeFilters: attributeFilters ?? this.attributeFilters,
    );
  }
}
