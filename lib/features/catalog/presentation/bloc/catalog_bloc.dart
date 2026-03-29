import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/catalog_page_result.dart';
import '../../domain/usecases/get_catalog_page_use_case.dart';
import '../../domain/usecases/search_catalog_use_case.dart';
import 'catalog_event.dart';
import 'catalog_state.dart';

class CatalogBloc extends Bloc<CatalogEvent, CatalogState> {
  final GetCatalogPageUseCase _getCatalogPage;
  final SearchCatalogUseCase _searchCatalog;

  static const _pageSize = AppConstants.catalogPageSize;

  CatalogBloc(this._getCatalogPage, this._searchCatalog)
      : super(const CatalogState()) {
    on<CatalogStarted>(_onStarted);
    on<CatalogRefreshed>(_onRefreshed);
    on<CatalogLoadMoreRequested>(_onLoadMore);
    on<CatalogSearchChanged>(_onSearchChanged);
    on<CatalogFiltersApplied>(_onFiltersApplied);
    on<CatalogAttributeFiltersApplied>(_onAttributeFiltersApplied);
  }

  Future<void> _onStarted(
    CatalogStarted event,
    Emitter<CatalogState> emit,
  ) async {
    await _loadFirstPage(emit);
  }

  Future<void> _onRefreshed(
    CatalogRefreshed event,
    Emitter<CatalogState> emit,
  ) async {
    await _loadFirstPage(emit);
  }

  Future<void> _onSearchChanged(
    CatalogSearchChanged event,
    Emitter<CatalogState> emit,
  ) async {
    emit(state.copyWith(searchQuery: event.query.trim()));
    await _loadFirstPage(emit);
  }

  Future<void> _onFiltersApplied(
    CatalogFiltersApplied event,
    Emitter<CatalogState> emit,
  ) async {
    emit(state.copyWith(filters: event.filters));
    await _loadFirstPage(emit);
  }

  Future<void> _onAttributeFiltersApplied(
    CatalogAttributeFiltersApplied event,
    Emitter<CatalogState> emit,
  ) async {
    emit(state.copyWith(attributeFilters: event.attributeFilters));
    await _loadFirstPage(emit);
  }

  Future<void> _onLoadMore(
    CatalogLoadMoreRequested event,
    Emitter<CatalogState> emit,
  ) async {
    if (state.status != CatalogStatus.success ||
        state.isLoadingMore ||
        state.hasReachedMax ||
        state.items.isEmpty) {
      return;
    }
    emit(state.copyWith(isLoadingMore: true));
    try {
      final from = state.items.length;
      final to = from + _pageSize - 1;
      final result = await _fetchPage(from, to);
      emit(state.copyWith(
        items: [...state.items, ...result.items],
        hasReachedMax: result.items.length < _pageSize,
        isLoadingMore: false,
      ));
    } catch (e) {
      emit(state.copyWith(isLoadingMore: false, errorMessage: '$e'));
    }
  }

  Future<void> _loadFirstPage(Emitter<CatalogState> emit) async {
    emit(state.copyWith(status: CatalogStatus.loading));
    try {
      final result = await _fetchPage(0, _pageSize - 1);
      emit(state.copyWith(
        status: CatalogStatus.success,
        items: result.items,
        totalCount: result.totalCount,
        hasReachedMax: result.items.length < _pageSize,
        isLoadingMore: false,
        errorMessage: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: CatalogStatus.failure,
        errorMessage: '$e',
        isLoadingMore: false,
      ));
    }
  }

  Future<CatalogPageResult> _fetchPage(int from, int to) {
    final f = state.filters;
    final query = state.searchQuery;
    final attrs = state.attributeFilters.isNotEmpty
        ? state.attributeFilters
        : null;
    if (query.trim().isEmpty) {
      return _getCatalogPage(
        from: from,
        to: to,
        brand: f.selectedBrand,
        category: f.selectedCategory,
        mark: f.selectedMark,
        sortOption: f.sortOption,
        attributeFilters: attrs,
      );
    }
    return _searchCatalog(
      query: query,
      from: from,
      to: to,
      brand: f.selectedBrand,
      category: f.selectedCategory,
      mark: f.selectedMark,
      sortOption: f.sortOption,
      attributeFilters: attrs,
    );
  }
}
