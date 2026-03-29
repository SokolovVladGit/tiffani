import '../dto/cart_item_dto.dart';

abstract interface class CartLocalDataSource {
  Future<List<CartItemDto>> getCartItems();
  Future<void> saveCartItems(List<CartItemDto> items);
  Future<void> clearCart();
}
