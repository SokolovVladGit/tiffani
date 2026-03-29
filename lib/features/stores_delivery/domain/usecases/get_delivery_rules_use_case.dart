import '../entities/delivery_rule_entity.dart';
import '../repositories/stores_delivery_repository.dart';

class GetDeliveryRulesUseCase {
  final StoresDeliveryRepository _repository;

  const GetDeliveryRulesUseCase(this._repository);

  Future<List<DeliveryRuleEntity>> call() => _repository.getDeliveryRules();
}
