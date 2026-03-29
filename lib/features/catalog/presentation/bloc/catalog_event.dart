import '../../domain/entities/catalog_filters_entity.dart';

sealed class CatalogEvent {
  const CatalogEvent();
}

final class CatalogStarted extends CatalogEvent {
  const CatalogStarted();
}

final class CatalogLoadMoreRequested extends CatalogEvent {
  const CatalogLoadMoreRequested();
}

final class CatalogRefreshed extends CatalogEvent {
  const CatalogRefreshed();
}

final class CatalogSearchChanged extends CatalogEvent {
  final String query;
  const CatalogSearchChanged(this.query);
}

final class CatalogFiltersApplied extends CatalogEvent {
  final CatalogFiltersEntity filters;
  const CatalogFiltersApplied(this.filters);
}

final class CatalogAttributeFiltersApplied extends CatalogEvent {
  final Map<String, Set<String>> attributeFilters;
  const CatalogAttributeFiltersApplied(this.attributeFilters);
}
