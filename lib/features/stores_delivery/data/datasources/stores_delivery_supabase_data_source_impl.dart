import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/logger_service.dart';
import '../dto/delivery_rule_dto.dart';
import '../dto/store_dto.dart';
import 'stores_delivery_supabase_data_source.dart';

class StoresDeliverySupabaseDataSourceImpl
    implements StoresDeliverySupabaseDataSource {
  final SupabaseClient _client;
  final LoggerService _logger;

  const StoresDeliverySupabaseDataSourceImpl(this._client, this._logger);

  @override
  Future<List<StoreDto>> getStores() async {
    _logger.d('getStores');
    try {
      final response = await _client
          .from('stores')
          .select()
          .eq('is_active', true)
          .order('sort_order', ascending: true);
      final items = response.map(StoreDto.fromMap).toList();
      _logger.d('getStores success: ${items.length}');
      return items;
    } catch (e) {
      _logger.e('getStores failed: $e');
      rethrow;
    }
  }

  @override
  Future<List<DeliveryRuleDto>> getDeliveryRules() async {
    _logger.d('getDeliveryRules');
    try {
      final response = await _client
          .from('delivery_rules')
          .select()
          .eq('is_active', true)
          .order('sort_order', ascending: true);
      final items = response.map(DeliveryRuleDto.fromMap).toList();
      _logger.d('getDeliveryRules success: ${items.length}');
      return items;
    } catch (e) {
      _logger.e('getDeliveryRules failed: $e');
      rethrow;
    }
  }
}
