import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/cart_item_entity.dart';
import '../../domain/entities/request_form_entity.dart';
import '../../domain/usecases/add_to_cart_use_case.dart';
import '../../domain/usecases/clear_cart_use_case.dart';
import '../../domain/usecases/get_cart_items_use_case.dart';
import '../../domain/usecases/get_cart_summary_use_case.dart';
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

  CartCubit(
    this._getCartItems,
    this._addToCart,
    this._updateQuantity,
    this._removeFromCart,
    this._clearCart,
    this._getCartSummary,
    this._submitOrderRequest,
  ) : super(const CartState());

  Future<void> loadCart() async {
    emit(state.copyWith(status: CartStatus.loading, submissionSuccess: false));
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

  Future<void> submitOrderRequest(RequestFormEntity form) async {
    if (state.isEmpty) {
      emit(state.copyWith(errorMessage: 'Cart is empty'));
      return;
    }
    emit(state.copyWith(isSubmitting: true, submissionSuccess: false));
    try {
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
