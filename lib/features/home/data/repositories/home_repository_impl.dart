import '../../../catalog/domain/entities/catalog_item_entity.dart';
import '../../domain/repositories/home_repository.dart';
import '../datasources/home_supabase_data_source.dart';

class HomeRepositoryImpl implements HomeRepository {
  final HomeSupabaseDataSource _dataSource;

  const HomeRepositoryImpl(this._dataSource);

  @override
  Future<List<CatalogItemEntity>> getNewItems({int limit = 10}) =>
      _dataSource.getNewItems(limit: limit);

  @override
  Future<List<CatalogItemEntity>> getSaleItems({int limit = 10}) =>
      _dataSource.getSaleItems(limit: limit);

  @override
  Future<List<CatalogItemEntity>> getHitItems({int limit = 10}) =>
      _dataSource.getHitItems(limit: limit);
}
