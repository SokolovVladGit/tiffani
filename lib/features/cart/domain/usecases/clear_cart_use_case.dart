import '../repositories/cart_repository.dart';

class ClearCartUseCase {
  final CartRepository _repository;
  const ClearCartUseCase(this._repository);

  Future<void> call() => _repository.clearCart();
}
