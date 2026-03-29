import '../entities/delivery_rule_entity.dart';
import '../entities/store_entity.dart';

abstract interface class StoresDeliveryRepository {
  Future<List<StoreEntity>> getStores();
  Future<List<DeliveryRuleEntity>> getDeliveryRules();
}
