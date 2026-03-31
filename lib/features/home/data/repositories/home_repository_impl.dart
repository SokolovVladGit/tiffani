import '../../../catalog/data/mappers/catalog_item_mapper.dart';
import '../../../catalog/domain/entities/catalog_item_entity.dart';
import '../../domain/repositories/home_repository.dart';
import '../datasources/home_supabase_data_source.dart';

class HomeRepositoryImpl implements HomeRepository {
  final HomeSupabaseDataSource _dataSource;

  const HomeRepositoryImpl(this._dataSource);

  @override
  Future<List<CatalogItemEntity>> getNewItems({int limit = 10}) async {
    final dtos = await _dataSource.getNewItems(limit: limit);
    return dtos.map((d) => d.toEntity()).toList();
  }

  @override
  Future<List<CatalogItemEntity>> getSaleItems({int limit = 10}) async {
    final dtos = await _dataSource.getSaleItems(limit: limit);
    return dtos.map((d) => d.toEntity()).toList();
  }

  @override
  Future<List<CatalogItemEntity>> getHitItems({int limit = 10}) async {
    final dtos = await _dataSource.getHitItems(limit: limit);
    return dtos.map((d) => d.toEntity()).toList();
  }
}
