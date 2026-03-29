import '../dto/delivery_rule_dto.dart';
import '../dto/store_dto.dart';

abstract interface class StoresDeliverySupabaseDataSource {
  Future<List<StoreDto>> getStores();
  Future<List<DeliveryRuleDto>> getDeliveryRules();
}
