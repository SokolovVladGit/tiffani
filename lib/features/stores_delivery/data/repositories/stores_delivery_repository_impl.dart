import '../../domain/entities/delivery_rule_entity.dart';
import '../../domain/entities/store_entity.dart';
import '../../domain/repositories/stores_delivery_repository.dart';
import '../datasources/stores_delivery_supabase_data_source.dart';
import '../dto/delivery_rule_dto.dart';
import '../dto/store_dto.dart';

class StoresDeliveryRepositoryImpl implements StoresDeliveryRepository {
  final StoresDeliverySupabaseDataSource _dataSource;

  const StoresDeliveryRepositoryImpl(this._dataSource);

  @override
  Future<List<StoreEntity>> getStores() async {
    final dtos = await _dataSource.getStores();
    return dtos.map(_mapStore).toList();
  }

  @override
  Future<List<DeliveryRuleEntity>> getDeliveryRules() async {
    final dtos = await _dataSource.getDeliveryRules();
    return dtos.map(_mapRule).toList();
  }

  StoreEntity _mapStore(StoreDto dto) {
    return StoreEntity(
      id: dto.id,
      title: dto.title,
      address: dto.address,
      phone: dto.phone,
      workingHours: dto.workingHours,
      latitude: dto.latitude,
      longitude: dto.longitude,
      isActive: dto.isActive,
      sortOrder: dto.sortOrder,
    );
  }

  DeliveryRuleEntity _mapRule(DeliveryRuleDto dto) {
    return DeliveryRuleEntity(
      id: dto.id,
      title: dto.title,
      description: dto.description,
      region: dto.region,
      isActive: dto.isActive,
      sortOrder: dto.sortOrder,
    );
  }
}
