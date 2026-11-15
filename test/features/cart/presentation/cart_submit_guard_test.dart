import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tiffani/features/cart/domain/entities/cart_item_entity.dart';
import 'package:tiffani/features/cart/domain/entities/cart_summary_entity.dart';
import 'package:tiffani/features/cart/domain/entities/fulfillment_option.dart';
import 'package:tiffani/features/cart/domain/entities/order_quote_entity.dart';
import 'package:tiffani/features/cart/domain/entities/order_result_entity.dart';
import 'package:tiffani/features/cart/domain/entities/payment_option.dart';
import 'package:tiffani/features/cart/domain/entities/request_form_entity.dart';
import 'package:tiffani/features/cart/domain/repositories/cart_repository.dart';
import 'package:tiffani/features/cart/domain/usecases/add_to_cart_use_case.dart';
import 'package:tiffani/features/cart/domain/usecases/clear_cart_use_case.dart';
import 'package:tiffani/features/cart/domain/usecases/get_cart_items_use_case.dart';
import 'package:tiffani/features/cart/domain/usecases/get_cart_summary_use_case.dart';
import 'package:tiffani/features/cart/domain/usecases/quote_order_use_case.dart';
import 'package:tiffani/features/cart/domain/usecases/remove_from_cart_use_case.dart';
import 'package:tiffani/features/cart/domain/usecases/submit_order_request_use_case.dart';
import 'package:tiffani/features/cart/domain/usecases/update_cart_item_quantity_use_case.dart';
import 'package:tiffani/features/cart/presentation/cubit/cart_cubit.dart';

void main() {
  const form = RequestFormEntity(
    name: 'Анна',
    phone: '+37312345678',
    fulfillment: FulfillmentOption.pickupStore,
    payment: PaymentOption.cash,
  );

  test('two overlapping submits call the RPC once', () async {
    final repo = _Repo();
    final cubit = _cubit(repo);
    addTearDown(cubit.close);
    await cubit.loadCart();
    final gate = Completer<void>();
    repo.gate = gate;

    final first = cubit.submitOrderRequest(form);
    await Future<void>.delayed(Duration.zero);
    final second = cubit.submitOrderRequest(form);
    expect(repo.submitted, 1);
    expect(cubit.state.isSubmitting, isTrue);
    gate.complete();
    await Future.wait([first, second]);

    expect(repo.submitted, 1);
    expect(cubit.state.submissionSuccess, isTrue);
  });

  test('a confirmed order ignores a stale submit callback', () async {
    final repo = _Repo();
    final cubit = _cubit(repo);
    addTearDown(cubit.close);
    await cubit.loadCart();
    await cubit.submitOrderRequest(form);
    await cubit.submitOrderRequest(form);
    expect(repo.submitted, 1);
    expect(cubit.state.errorMessage, isNull);
  });

  test(
    'a network failure can be retried and a cart-clear failure stays success',
    () async {
      final repo = _Repo()..failFirst = true;
      final cubit = _cubit(repo);
      addTearDown(cubit.close);
      await cubit.loadCart();
      await cubit.submitOrderRequest(form);
      expect(cubit.state.submissionSuccess, isFalse);
      expect(cubit.state.isSubmitting, isFalse);
      expect(repo.cleared, isFalse);

      repo.failClear = true;
      await cubit.submitOrderRequest(form);
      expect(repo.submitted, 2);
      expect(cubit.state.submissionSuccess, isTrue);
      expect(cubit.state.lastOrderId, 'b1f40755-1111-4111-8111-111111111111');
    },
  );
}

CartCubit _cubit(_Repo repo) {
  return CartCubit(
    GetCartItemsUseCase(repo),
    AddToCartUseCase(repo),
    UpdateCartItemQuantityUseCase(repo),
    RemoveFromCartUseCase(repo),
    ClearCartUseCase(repo),
    GetCartSummaryUseCase(repo),
    SubmitOrderRequestUseCase(repo),
    QuoteOrderUseCase(repo),
  );
}

class _Repo implements CartRepository {
  int submitted = 0;
  bool cleared = false;
  bool failFirst = false;
  bool failClear = false;
  Completer<void>? gate;

  final _item = const CartItemEntity(
    id: 'line-1',
    productId: 'product-1',
    title: 'Крем',
    quantity: 1,
    price: 335,
  );

  @override
  Future<List<CartItemEntity>> getCartItems() async => cleared ? [] : [_item];

  @override
  Future<CartSummaryEntity> getCartSummary() async {
    return cleared
        ? const CartSummaryEntity(
            totalItems: 0,
            totalQuantity: 0,
            totalPrice: 0,
          )
        : const CartSummaryEntity(
            totalItems: 1,
            totalQuantity: 1,
            totalPrice: 335,
          );
  }

  @override
  Future<void> clearCart() async {
    if (failClear) throw Exception('disk');
    cleared = true;
  }

  @override
  Future<OrderResultEntity> submitOrderRequest({
    required RequestFormEntity form,
    required List<CartItemEntity> items,
  }) async {
    submitted++;
    final gate = this.gate;
    if (gate != null) await gate.future;
    if (failFirst) {
      failFirst = false;
      throw Exception('timeout');
    }
    return const OrderResultEntity(
      orderId: 'b1f40755-1111-4111-8111-111111111111',
      totalItems: 1,
      totalQuantity: 1,
      totalPrice: 335,
    );
  }

  @override
  Future<void> addToCart(CartItemEntity item) => throw UnimplementedError();

  @override
  Future<int> getCartItemCount() => throw UnimplementedError();

  @override
  Future<OrderQuoteEntity> quoteOrder({
    required RequestFormEntity form,
    required List<CartItemEntity> items,
  }) => throw UnimplementedError();

  @override
  Future<void> removeFromCart(String itemId) => throw UnimplementedError();

  @override
  Future<void> updateQuantity({
    required String itemId,
    required int quantity,
  }) => throw UnimplementedError();

  @override
  Future<OrderResultEntity> retryPendingOrder() => throw UnimplementedError();

  @override
  Future<void> discardPendingOrder() async {}

  @override
  Future<bool> hasPendingOrder() async => false;
}
