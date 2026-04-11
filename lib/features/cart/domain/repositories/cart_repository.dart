import '../entities/cart_item_entity.dart';
import '../entities/cart_summary_entity.dart';
import '../entities/order_result_entity.dart';
import '../entities/request_form_entity.dart';

abstract interface class CartRepository {
  Future<List<CartItemEntity>> getCartItems();
  Future<void> addToCart(CartItemEntity item);
  Future<void> updateQuantity({required String itemId, required int quantity});
  Future<void> removeFromCart(String itemId);
  Future<void> clearCart();
  Future<CartSummaryEntity> getCartSummary();
  Future<int> getCartItemCount();

  Future<OrderResultEntity> submitOrderRequest({
    required RequestFormEntity form,
    required List<CartItemEntity> items,
  });
}
