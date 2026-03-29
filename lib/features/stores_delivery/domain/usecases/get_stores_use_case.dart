import '../entities/store_entity.dart';
import '../repositories/stores_delivery_repository.dart';

class GetStoresUseCase {
  final StoresDeliveryRepository _repository;

  const GetStoresUseCase(this._repository);

  Future<List<StoreEntity>> call() => _repository.getStores();
}
