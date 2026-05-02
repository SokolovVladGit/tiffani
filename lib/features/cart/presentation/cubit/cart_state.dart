import '../../domain/entities/cart_item_entity.dart';
import '../../domain/entities/order_quote_entity.dart';

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

  // Phase 4: discount-aware quote.
  final OrderQuoteEntity? quote;
  final bool isQuoting;
  final String? quoteErrorMessage;

  /// True when the user has changed an input that affects pricing
  /// (promo code, fulfillment option) since the last successful quote.
  /// Display layer can use this to show "Пересчитать" hints.
  final bool quoteStale;

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
    this.quote,
    this.isQuoting = false,
    this.quoteErrorMessage,
    this.quoteStale = false,
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
    OrderQuoteEntity? quote,
    bool clearQuote = false,
    bool? isQuoting,
    String? quoteErrorMessage,
    bool clearQuoteError = false,
    bool? quoteStale,
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
      quote: clearQuote ? null : (quote ?? this.quote),
      isQuoting: isQuoting ?? this.isQuoting,
      quoteErrorMessage:
          clearQuoteError ? null : (quoteErrorMessage ?? this.quoteErrorMessage),
      quoteStale: quoteStale ?? this.quoteStale,
    );
  }
}
