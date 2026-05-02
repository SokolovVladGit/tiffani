import 'package:flutter_bloc/flutter_bloc.dart';

import '../../config/discount_pricing_config.dart';
import '../../domain/entities/cart_item_entity.dart';
import '../../domain/entities/request_form_entity.dart';
import '../../domain/exceptions/order_submission_exception.dart';
import '../../domain/usecases/add_to_cart_use_case.dart';
import '../../domain/usecases/clear_cart_use_case.dart';
import '../../domain/usecases/get_cart_items_use_case.dart';
import '../../domain/usecases/get_cart_summary_use_case.dart';
import '../../domain/usecases/quote_order_use_case.dart';
import '../../domain/usecases/remove_from_cart_use_case.dart';
import '../../domain/usecases/submit_order_request_use_case.dart';
import '../../domain/usecases/update_cart_item_quantity_use_case.dart';
import 'cart_state.dart';

class CartCubit extends Cubit<CartState> {
  final GetCartItemsUseCase _getCartItems;
  final AddToCartUseCase _addToCart;
  final UpdateCartItemQuantityUseCase _updateQuantity;
  final RemoveFromCartUseCase _removeFromCart;
  final ClearCartUseCase _clearCart;
  final GetCartSummaryUseCase _getCartSummary;
  final SubmitOrderRequestUseCase _submitOrderRequest;
  final QuoteOrderUseCase _quoteOrder;

  CartCubit(
    this._getCartItems,
    this._addToCart,
    this._updateQuantity,
    this._removeFromCart,
    this._clearCart,
    this._getCartSummary,
    this._submitOrderRequest,
    this._quoteOrder,
  ) : super(const CartState());

  Future<void> loadCart() async {
    emit(state.copyWith(
      status: CartStatus.loading,
      submissionSuccess: false,
      clearQuote: true,
      clearQuoteError: true,
      quoteStale: false,
    ));
    try {
      await _reloadCartState();
    } catch (e) {
      emit(state.copyWith(status: CartStatus.failure, errorMessage: '$e'));
    }
  }

  Future<void> addItem(CartItemEntity item) async {
    try {
      await _addToCart(item);
      await _reloadCartState();
    } catch (e) {
      emit(state.copyWith(errorMessage: '$e'));
    }
  }

  Future<void> incrementQuantity(String itemId) async {
    try {
      final current = state.items.firstWhere((i) => i.id == itemId);
      await _updateQuantity(itemId: itemId, quantity: current.quantity + 1);
      await _reloadCartState();
    } catch (e) {
      emit(state.copyWith(errorMessage: '$e'));
    }
  }

  Future<void> decrementQuantity(String itemId) async {
    try {
      final current = state.items.firstWhere((i) => i.id == itemId);
      if (current.quantity <= 1) {
        await _removeFromCart(itemId);
      } else {
        await _updateQuantity(itemId: itemId, quantity: current.quantity - 1);
      }
      await _reloadCartState();
    } catch (e) {
      emit(state.copyWith(errorMessage: '$e'));
    }
  }

  Future<void> removeItem(String itemId) async {
    try {
      await _removeFromCart(itemId);
      await _reloadCartState();
    } catch (e) {
      emit(state.copyWith(errorMessage: '$e'));
    }
  }

  Future<void> clearAllItems() async {
    try {
      await _clearCart();
      await _reloadCartState();
    } catch (e) {
      emit(state.copyWith(errorMessage: '$e'));
    }
  }

  /// Marks the existing quote as stale (UI hint for "discount may need
  /// recalculation"). Cheap, no RPC. Called from the checkout page when
  /// the user changes a pricing input (promo, fulfillment option) and we
  /// haven't re-quoted yet.
  void markQuoteStale() {
    if (!DiscountPricingConfig.useDiscountPricingV1) return;
    if (state.quote == null) return;
    if (state.quoteStale) return;
    emit(state.copyWith(quoteStale: true));
  }

  /// Calls `quote_order_v1` with the current cart and the supplied form
  /// (promo + fulfillment fee). Always non-throwing for user-correctable
  /// failures: those land in `state.quote.errors`. Network/RPC errors
  /// land in `state.quoteErrorMessage`.
  Future<void> requestQuote(RequestFormEntity form) async {
    if (!DiscountPricingConfig.useDiscountPricingV1) return;
    if (state.items.isEmpty) {
      emit(state.copyWith(
        clearQuote: true,
        clearQuoteError: true,
        quoteStale: false,
      ));
      return;
    }

    emit(state.copyWith(
      isQuoting: true,
      clearQuoteError: true,
    ));

    try {
      final quote = await _quoteOrder(form: form, items: state.items);
      emit(state.copyWith(
        quote: quote,
        isQuoting: false,
        quoteStale: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        isQuoting: false,
        quoteErrorMessage:
            'Не удалось проверить скидку. Попробуйте ещё раз.',
      ));
    }
  }

  Future<void> submitOrderRequest(RequestFormEntity form) async {
    if (state.isEmpty) {
      emit(state.copyWith(errorMessage: 'Cart is empty'));
      return;
    }
    emit(state.copyWith(
      isSubmitting: true,
      submissionSuccess: false,
    ));
    try {
      final result =
          await _submitOrderRequest(form: form, items: state.items);
      await _clearCart();
      final items = await _getCartItems();
      final summary = await _getCartSummary();
      emit(
        CartState(
          status: CartStatus.success,
          items: items,
          totalItems: summary.totalItems,
          totalQuantity: summary.totalQuantity,
          totalPrice: summary.totalPrice,
          isSubmitting: false,
          submissionSuccess: true,
          lastOrderId: result.orderId,
        ),
      );
    } on OrderSubmissionException catch (e) {
      // Backend says the snapshot drifted — re-quote so the UI shows the
      // refreshed numbers immediately, then surface the error.
      if (e.requiresRequote && DiscountPricingConfig.useDiscountPricingV1) {
        try {
          final fresh = await _quoteOrder(form: form, items: state.items);
          emit(state.copyWith(quote: fresh, quoteStale: false));
        } catch (_) {
          // ignore: caller already gets the original error below
        }
      }
      emit(
        state.copyWith(
          isSubmitting: false,
          submissionSuccess: false,
          errorMessage: e.message,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isSubmitting: false,
          submissionSuccess: false,
          errorMessage: '$e',
        ),
      );
    }
  }

  Future<void> _reloadCartState() async {
    final items = await _getCartItems();
    final summary = await _getCartSummary();
    emit(
      CartState(
        status: CartStatus.success,
        items: items,
        totalItems: summary.totalItems,
        totalQuantity: summary.totalQuantity,
        totalPrice: summary.totalPrice,
      ),
    );
  }
}
