import '../entities/cart_item_entity.dart';
import '../entities/order_result_entity.dart';
import '../entities/request_form_entity.dart';
import '../repositories/cart_repository.dart';

class SubmitOrderRequestUseCase {
  final CartRepository _repository;
  const SubmitOrderRequestUseCase(this._repository);

  Future<OrderResultEntity> call({
    required RequestFormEntity form,
    required List<CartItemEntity> items,
  }) => _repository.submitOrderRequest(form: form, items: items);
}
