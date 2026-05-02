import '../entities/cart_item_entity.dart';
import '../entities/order_quote_entity.dart';
import '../entities/request_form_entity.dart';
import '../repositories/cart_repository.dart';

class QuoteOrderUseCase {
  final CartRepository _repository;
  const QuoteOrderUseCase(this._repository);

  Future<OrderQuoteEntity> call({
    required RequestFormEntity form,
    required List<CartItemEntity> items,
  }) =>
      _repository.quoteOrder(form: form, items: items);
}
