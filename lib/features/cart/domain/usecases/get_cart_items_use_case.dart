import '../entities/cart_item_entity.dart';
import '../repositories/cart_repository.dart';

class GetCartItemsUseCase {
  final CartRepository _repository;
  const GetCartItemsUseCase(this._repository);

  Future<List<CartItemEntity>> call() => _repository.getCartItems();
}
