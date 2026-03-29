class CartItemEntity {
  final String id;
  final String productId;
  final String title;
  final int quantity;
  final String? brand;
  final String? imageUrl;
  final double? price;
  final double? oldPrice;
  final String? edition;
  final String? modification;

  const CartItemEntity({
    required this.id,
    required this.productId,
    required this.title,
    required this.quantity,
    this.brand,
    this.imageUrl,
    this.price,
    this.oldPrice,
    this.edition,
    this.modification,
  });

  CartItemEntity copyWith({int? quantity}) {
    return CartItemEntity(
      id: id,
      productId: productId,
      title: title,
      quantity: quantity ?? this.quantity,
      brand: brand,
      imageUrl: imageUrl,
      price: price,
      oldPrice: oldPrice,
      edition: edition,
      modification: modification,
    );
  }
}
