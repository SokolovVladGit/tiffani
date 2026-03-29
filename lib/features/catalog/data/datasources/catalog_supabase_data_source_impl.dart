import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/logger_service.dart';
import '../../domain/entities/catalog_sort_option.dart';
import '../dto/catalog_item_dto.dart';
import '../dto/catalog_page_result_dto.dart';
import 'catalog_supabase_data_source.dart';

class CatalogSupabaseDataSourceImpl implements CatalogSupabaseDataSource {
  final SupabaseClient _client;
  final LoggerService _logger;

  static const _table = 'catalog_items';

  const CatalogSupabaseDataSourceImpl(this._client, this._logger);

  @override
  Future<CatalogPageResultDto> getCatalogPage({
    required int from,
    required int to,
    String? brand,
    String? category,
    String? mark,
    CatalogSortOption sortOption = CatalogSortOption.defaultOrder,
    Map<String, Set<String>>? attributeFilters,
  }) async {
    _logger.d('getCatalogPage from=$from to=$to');
    try {
      var query = _client.from(_table).select().eq('is_active', true);
      query = _applyFilters(query, brand: brand, category: category, mark: mark);
      query = _applyAttributeFilters(query, attributeFilters);
      final response = await _applySortAndRange(query, sortOption, from, to);
      final items = response.data.map(CatalogItemDto.fromMap).toList();
      _logger.d('getCatalogPage success: ${items.length} items, total: ${response.count}');
      return CatalogPageResultDto(items: items, totalCount: response.count);
    } catch (e) {
      _logger.e('getCatalogPage failed: $e');
      rethrow;
    }
  }

  @override
  Future<CatalogPageResultDto> searchCatalog({
    required String query,
    int from = 0,
    int to = 29,
    String? brand,
    String? category,
    String? mark,
    CatalogSortOption sortOption = CatalogSortOption.defaultOrder,
    Map<String, Set<String>>? attributeFilters,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return getCatalogPage(
        from: from,
        to: to,
        brand: brand,
        category: category,
        mark: mark,
        sortOption: sortOption,
        attributeFilters: attributeFilters,
      );
    }
    _logger.d('searchCatalog query="$trimmed" from=$from to=$to');
    try {
      var q = _client
          .from(_table)
          .select()
          .eq('is_active', true)
          .ilike('title', '%$trimmed%');
      q = _applyFilters(q, brand: brand, category: category, mark: mark);
      q = _applyAttributeFilters(q, attributeFilters);
      final response = await _applySortAndRange(q, sortOption, from, to);
      final items = response.data.map(CatalogItemDto.fromMap).toList();
      _logger.d('searchCatalog success: ${items.length} items, total: ${response.count}');
      return CatalogPageResultDto(items: items, totalCount: response.count);
    } catch (e) {
      _logger.e('searchCatalog failed: $e');
      rethrow;
    }
  }

  @override
  Future<CatalogItemDto?> getCatalogItemByVariantId(String variantId) async {
    _logger.d('getCatalogItemByVariantId id=$variantId');
    try {
      final response = await _client
          .from(_table)
          .select()
          .eq('is_active', true)
          .eq('variant_id', variantId)
          .maybeSingle();
      if (response == null) return null;
      return CatalogItemDto.fromMap(response);
    } catch (e) {
      _logger.e('getCatalogItemByVariantId failed: $e');
      rethrow;
    }
  }

  @override
  Future<List<CatalogItemDto>> getCatalogItemsByVariantIds(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return [];
    _logger.d('getCatalogItemsByVariantIds count=${ids.length}');
    try {
      final response = await _client
          .from(_table)
          .select()
          .eq('is_active', true)
          .inFilter('variant_id', ids);
      final items = response.map(CatalogItemDto.fromMap).toList();
      _logger.d('getCatalogItemsByVariantIds success: ${items.length}');
      return items;
    } catch (e) {
      _logger.e('getCatalogItemsByVariantIds failed: $e');
      rethrow;
    }
  }

  @override
  Future<List<String>> getAvailableBrands() async {
    _logger.d('getAvailableBrands');
    try {
      final response = await _client
          .from(_table)
          .select('brand')
          .eq('is_active', true);
      return _extractDistinct(response, 'brand');
    } catch (e) {
      _logger.e('getAvailableBrands failed: $e');
      rethrow;
    }
  }

  @override
  Future<List<String>> getAvailableCategories() async {
    _logger.d('getAvailableCategories');
    try {
      final response = await _client
          .from(_table)
          .select('category')
          .eq('is_active', true);
      return _extractDistinct(response, 'category');
    } catch (e) {
      _logger.e('getAvailableCategories failed: $e');
      rethrow;
    }
  }

  @override
  Future<List<String>> getAvailableMarks() async {
    _logger.d('getAvailableMarks');
    try {
      final response = await _client
          .from(_table)
          .select('mark')
          .eq('is_active', true);
      return _extractDistinct(response, 'mark');
    } catch (e) {
      _logger.e('getAvailableMarks failed: $e');
      rethrow;
    }
  }

  PostgrestFilterBuilder<List<Map<String, dynamic>>> _applyFilters(
    PostgrestFilterBuilder<List<Map<String, dynamic>>> query, {
    String? brand,
    String? category,
    String? mark,
  }) {
    var q = query;
    if (brand != null && brand.isNotEmpty) q = q.eq('brand', brand);
    if (category != null && category.isNotEmpty) q = q.eq('category', category);
    if (mark != null && mark.isNotEmpty) q = q.eq('mark', mark);
    return q;
  }

  static const _arrayAttributes = {'skin_type', 'effect'};

  /// Applies JSONB attribute filters using a single `.or()` call to avoid
  /// duplicate `or` query-parameter keys that some postgrest-dart versions
  /// silently overwrite.
  ///
  /// Within the same attribute  → OR  (any match)
  /// Between different attributes → AND (all must match)
  PostgrestFilterBuilder<List<Map<String, dynamic>>> _applyAttributeFilters(
    PostgrestFilterBuilder<List<Map<String, dynamic>>> query,
    Map<String, Set<String>>? filters,
  ) {
    if (filters == null || filters.isEmpty) return query;

    final groups = <String>[];
    for (final entry in filters.entries) {
      if (entry.value.isEmpty) continue;
      if (_arrayAttributes.contains(entry.key)) {
        groups.add(
          entry.value
              .map((v) => 'attributes->${entry.key}.cs.${json.encode([v])}')
              .join(','),
        );
      } else {
        groups.add(
          'attributes->>${entry.key}.in.(${entry.value.join(',')})',
        );
      }
    }

    if (groups.isEmpty) return query;
    if (groups.length == 1) return query.or(groups.first);
    return query.or('and(${groups.map((g) => 'or($g)').join(',')})');
  }

  Future<PostgrestResponse<List<Map<String, dynamic>>>> _applySortAndRange(
    PostgrestFilterBuilder<List<Map<String, dynamic>>> query,
    CatalogSortOption sort,
    int from,
    int to,
  ) {
    return switch (sort) {
      CatalogSortOption.defaultOrder =>
        query.range(from, to).count(CountOption.exact),
      CatalogSortOption.priceLowToHigh =>
        query.order('price', ascending: true).range(from, to).count(CountOption.exact),
      CatalogSortOption.priceHighToLow =>
        query.order('price', ascending: false).range(from, to).count(CountOption.exact),
      CatalogSortOption.titleAZ =>
        query.order('title', ascending: true).range(from, to).count(CountOption.exact),
    };
  }

  List<String> _extractDistinct(
    List<Map<String, dynamic>> rows,
    String key,
  ) {
    final values = rows
        .map((r) => (r[key] as String?)?.trim())
        .where((v) => v != null && v.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList()
      ..sort();
    return values;
  }
}
