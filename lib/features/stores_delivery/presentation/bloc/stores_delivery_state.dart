import '../../domain/entities/delivery_rule_entity.dart';
import '../../domain/entities/store_entity.dart';

enum StoresDeliveryStatus { initial, loading, success, failure }

class StoresDeliveryState {
  final StoresDeliveryStatus status;
  final List<StoreEntity> stores;
  final List<DeliveryRuleEntity> deliveryRules;
  final String? errorMessage;

  const StoresDeliveryState({
    this.status = StoresDeliveryStatus.initial,
    this.stores = const [],
    this.deliveryRules = const [],
    this.errorMessage,
  });

  bool get hasContent => stores.isNotEmpty || deliveryRules.isNotEmpty;

  StoresDeliveryState copyWith({
    StoresDeliveryStatus? status,
    List<StoreEntity>? stores,
    List<DeliveryRuleEntity>? deliveryRules,
    String? errorMessage,
  }) {
    return StoresDeliveryState(
      status: status ?? this.status,
      stores: stores ?? this.stores,
      deliveryRules: deliveryRules ?? this.deliveryRules,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
