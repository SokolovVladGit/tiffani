import '../entities/cart_item_entity.dart';
import '../entities/cart_summary_entity.dart';
import '../entities/order_quote_entity.dart';
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

  /// Server-side pricing preview via `quote_order_v1`. Read-only — never
  /// writes orders or campaign redemptions. Always returns an entity (with
  /// `ok=false` and populated [OrderQuoteEntity.errors] on failure).
  ///
  /// May throw on network/RPC transport errors; callers should handle that
  /// distinctly from a successful `ok=false` response.
  Future<OrderQuoteEntity> quoteOrder({
    required RequestFormEntity form,
    required List<CartItemEntity> items,
  });

  /// Submits via `submit_order_v3` (or `submit_order_v2` when the discount
  /// pricing flag is off). Throws [OrderSubmissionException] for
  /// user-correctable backend failures.
  Future<OrderResultEntity> submitOrderRequest({
    required RequestFormEntity form,
    required List<CartItemEntity> items,
  });
}
