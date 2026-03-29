import '../entities/cart_item_entity.dart';
import '../entities/request_form_entity.dart';
import '../repositories/cart_repository.dart';

class SubmitOrderRequestUseCase {
  final CartRepository _repository;
  const SubmitOrderRequestUseCase(this._repository);

  Future<void> call({
    required RequestFormEntity form,
    required List<CartItemEntity> items,
  }) => _repository.submitOrderRequest(form: form, items: items);
}
