import '../entities/cart_item_entity.dart';
import '../repositories/cart_repository.dart';

class AddToCartUseCase {
  final CartRepository _repository;
  const AddToCartUseCase(this._repository);

  Future<void> call(CartItemEntity item) => _repository.addToCart(item);
}
