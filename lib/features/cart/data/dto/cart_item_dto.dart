class CartItemDto {
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

  const CartItemDto({
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

  factory CartItemDto.fromMap(Map<String, dynamic> map) {
    return CartItemDto(
      id: map['id'] as String,
      productId: map['product_id'] as String,
      title: map['title'] as String,
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      brand: map['brand'] as String?,
      imageUrl: map['image_url'] as String?,
      price: _toDouble(map['price']),
      oldPrice: _toDouble(map['old_price']),
      edition: map['edition'] as String?,
      modification: map['modification'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'title': title,
      'quantity': quantity,
      'brand': brand,
      'image_url': imageUrl,
      'price': price,
      'old_price': oldPrice,
      'edition': edition,
      'modification': modification,
    };
  }
}

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
