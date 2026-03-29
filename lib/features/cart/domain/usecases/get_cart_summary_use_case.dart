import '../entities/cart_summary_entity.dart';
import '../repositories/cart_repository.dart';

class GetCartSummaryUseCase {
  final CartRepository _repository;
  const GetCartSummaryUseCase(this._repository);

  Future<CartSummaryEntity> call() => _repository.getCartSummary();
}
