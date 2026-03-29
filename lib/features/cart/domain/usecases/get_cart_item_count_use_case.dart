import '../repositories/cart_repository.dart';

class GetCartItemCountUseCase {
  final CartRepository _repository;
  const GetCartItemCountUseCase(this._repository);

  Future<int> call() => _repository.getCartItemCount();
}
