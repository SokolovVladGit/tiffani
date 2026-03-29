import '../repositories/cart_repository.dart';

class UpdateCartItemQuantityUseCase {
  final CartRepository _repository;
  const UpdateCartItemQuantityUseCase(this._repository);

  Future<void> call({required String itemId, required int quantity}) =>
      _repository.updateQuantity(itemId: itemId, quantity: quantity);
}
