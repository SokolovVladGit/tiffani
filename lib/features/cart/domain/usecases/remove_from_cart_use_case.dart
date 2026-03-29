import '../repositories/cart_repository.dart';

class RemoveFromCartUseCase {
  final CartRepository _repository;
  const RemoveFromCartUseCase(this._repository);

  Future<void> call(String itemId) => _repository.removeFromCart(itemId);
}
