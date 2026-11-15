import 'dart:io';

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
import 'package:tiffani/features/cart/presentation/cubit/cart_state.dart';

void main() {
  test('checkout succeeds without a notification client', () async {
    final repo = _Repo();
    final cubit = CartCubit(
      GetCartItemsUseCase(repo),
      AddToCartUseCase(repo),
      UpdateCartItemQuantityUseCase(repo),
      RemoveFromCartUseCase(repo),
      ClearCartUseCase(repo),
      GetCartSummaryUseCase(repo),
      SubmitOrderRequestUseCase(repo),
      QuoteOrderUseCase(repo),
    );
    addTearDown(cubit.close);

    await cubit.loadCart();
    await cubit.submitOrderRequest(
      const RequestFormEntity(
        name: 'Анна',
        phone: '+373 00',
        fulfillment: FulfillmentOption.pickupStore,
        payment: PaymentOption.cash,
      ),
    );

    expect(cubit.state.submissionSuccess, isTrue);
    expect(cubit.state.status, CartStatus.success);
    expect(cubit.state.lastOrderId, 'order-1');
    expect(cubit.state.items, isEmpty);
    expect(repo.cleared, isTrue);
    expect(repo.submitted, 1);
  });

  test('the order client no longer invokes order-notify', () {
    final source = File(
      'lib/features/cart/data/datasources/cart_remote_data_source_impl.dart',
    ).readAsStringSync();
    expect(source.contains('functions'), isFalse);
    expect(source.contains('order-notify'), isFalse);
    expect(source.contains("_notifyOrder"), isFalse);
    expect(source.contains('submitOrderRequest'), isTrue);
  });
}

class _Repo implements CartRepository {
  bool cleared = false;
  int submitted = 0;

  final _item = const CartItemEntity(
    id: 'line-1',
    productId: 'product-1',
    title: 'Крем',
    quantity: 1,
    price: 90,
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
            totalPrice: 90,
          );
  }

  @override
  Future<void> clearCart() async {
    cleared = true;
  }

  @override
  Future<OrderResultEntity> submitOrderRequest({
    required RequestFormEntity form,
    required List<CartItemEntity> items,
  }) async {
    submitted++;
    return const OrderResultEntity(
      orderId: 'order-1',
      totalItems: 1,
      totalQuantity: 1,
      totalPrice: 90,
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
