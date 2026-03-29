import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/logger_service.dart';
import '../../../catalog/data/dto/catalog_item_dto.dart';
import '../../../catalog/data/mappers/catalog_item_mapper.dart';
import '../../../catalog/domain/entities/catalog_item_entity.dart';
import 'home_supabase_data_source.dart';

class HomeSupabaseDataSourceImpl implements HomeSupabaseDataSource {
  final SupabaseClient _client;
  final LoggerService _logger;

  static const _table = 'catalog_items';

  const HomeSupabaseDataSourceImpl(this._client, this._logger);

  @override
  Future<List<CatalogItemEntity>> getNewItems({int limit = 10}) async {
    _logger.d('getNewItems limit=$limit');
    try {
      final response = await _client
          .from(_table)
          .select()
          .eq('is_active', true)
          .eq('mark', 'NEW')
          .limit(limit);
      final items = _mapRows(response);
      _logger.d('getNewItems success: ${items.length}');
      return items;
    } catch (e) {
      _logger.e('getNewItems failed: $e');
      rethrow;
    }
  }

  @override
  Future<List<CatalogItemEntity>> getSaleItems({int limit = 10}) async {
    _logger.d('getSaleItems limit=$limit');
    try {
      final response = await _client
          .from(_table)
          .select()
          .eq('is_active', true)
          .not('old_price', 'is', null)
          .limit(limit);
      final items = _mapRows(response);
      _logger.d('getSaleItems success: ${items.length}');
      return items;
    } catch (e) {
      _logger.e('getSaleItems failed: $e');
      rethrow;
    }
  }

  @override
  Future<List<CatalogItemEntity>> getHitItems({int limit = 10}) async {
    _logger.d('getHitItems limit=$limit');
    try {
      final response = await _client
          .from(_table)
          .select()
          .eq('is_active', true)
          .eq('mark', 'ХИТ')
          .limit(limit);
      final items = _mapRows(response);
      _logger.d('getHitItems success: ${items.length}');
      return items;
    } catch (e) {
      _logger.e('getHitItems failed: $e');
      rethrow;
    }
  }

  List<CatalogItemEntity> _mapRows(List<Map<String, dynamic>> rows) {
    return rows.map((r) => CatalogItemDto.fromMap(r).toEntity()).toList();
  }
}
