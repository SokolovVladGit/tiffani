import '../../domain/entities/cart_item_entity.dart';

enum CartStatus { initial, loading, success, failure }

class CartState {
  final CartStatus status;
  final List<CartItemEntity> items;
  final int totalItems;
  final int totalQuantity;
  final double totalPrice;
  final String? errorMessage;
  final bool isSubmitting;
  final bool submissionSuccess;
  final String? lastOrderId;

  const CartState({
    this.status = CartStatus.initial,
    this.items = const [],
    this.totalItems = 0,
    this.totalQuantity = 0,
    this.totalPrice = 0,
    this.errorMessage,
    this.isSubmitting = false,
    this.submissionSuccess = false,
    this.lastOrderId,
  });

  bool get isEmpty => items.isEmpty;

  int quantityOf(String itemId) {
    for (final item in items) {
      if (item.id == itemId) return item.quantity;
    }
    return 0;
  }

  CartState copyWith({
    CartStatus? status,
    List<CartItemEntity>? items,
    int? totalItems,
    int? totalQuantity,
    double? totalPrice,
    String? errorMessage,
    bool? isSubmitting,
    bool? submissionSuccess,
    String? lastOrderId,
  }) {
    return CartState(
      status: status ?? this.status,
      items: items ?? this.items,
      totalItems: totalItems ?? this.totalItems,
      totalQuantity: totalQuantity ?? this.totalQuantity,
      totalPrice: totalPrice ?? this.totalPrice,
      errorMessage: errorMessage ?? this.errorMessage,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submissionSuccess: submissionSuccess ?? this.submissionSuccess,
      lastOrderId: lastOrderId ?? this.lastOrderId,
    );
  }
}
