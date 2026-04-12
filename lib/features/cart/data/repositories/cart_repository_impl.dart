import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/cart_item_entity.dart';
import '../../domain/entities/cart_summary_entity.dart';
import '../../domain/entities/order_result_entity.dart';
import '../../domain/entities/request_form_entity.dart';
import '../../domain/repositories/cart_repository.dart';
import '../datasources/cart_local_data_source.dart';
import '../datasources/cart_remote_data_source.dart';
import '../dto/cart_item_dto.dart';
import '../dto/request_item_payload_dto.dart';
import '../dto/request_submission_payload_dto.dart';

class CartRepositoryImpl implements CartRepository {
  final CartLocalDataSource _localDataSource;
  final CartRemoteDataSource _remoteDataSource;
  final SupabaseClient _supabaseClient;

  const CartRepositoryImpl(
    this._localDataSource,
    this._remoteDataSource,
    this._supabaseClient,
  );

  @override
  Future<List<CartItemEntity>> getCartItems() async {
    final dtos = await _localDataSource.getCartItems();
    return dtos.map(_toEntity).toList();
  }

  @override
  Future<void> addToCart(CartItemEntity item) async {
    final dtos = await _localDataSource.getCartItems();
    final index = dtos.indexWhere((d) => d.id == item.id);
    if (index >= 0) {
      final existing = dtos[index];
      dtos[index] = CartItemDto(
        id: existing.id,
        productId: existing.productId,
        title: existing.title,
        quantity: existing.quantity + 1,
        brand: existing.brand,
        imageUrl: existing.imageUrl,
        price: existing.price,
        oldPrice: existing.oldPrice,
        edition: existing.edition,
        modification: existing.modification,
      );
    } else {
      dtos.add(_toDto(item));
    }
    await _localDataSource.saveCartItems(dtos);
  }

  @override
  Future<void> updateQuantity({
    required String itemId,
    required int quantity,
  }) async {
    final dtos = await _localDataSource.getCartItems();
    final index = dtos.indexWhere((d) => d.id == itemId);
    if (index < 0) return;
    if (quantity < 1) {
      dtos.removeAt(index);
    } else {
      final existing = dtos[index];
      dtos[index] = CartItemDto(
        id: existing.id,
        productId: existing.productId,
        title: existing.title,
        quantity: quantity,
        brand: existing.brand,
        imageUrl: existing.imageUrl,
        price: existing.price,
        oldPrice: existing.oldPrice,
        edition: existing.edition,
        modification: existing.modification,
      );
    }
    await _localDataSource.saveCartItems(dtos);
  }

  @override
  Future<void> removeFromCart(String itemId) async {
    final dtos = await _localDataSource.getCartItems();
    dtos.removeWhere((d) => d.id == itemId);
    await _localDataSource.saveCartItems(dtos);
  }

  @override
  Future<void> clearCart() async {
    await _localDataSource.clearCart();
  }

  @override
  Future<CartSummaryEntity> getCartSummary() async {
    final dtos = await _localDataSource.getCartItems();
    final totalItems = dtos.length;
    final totalQuantity = dtos.fold<int>(0, (sum, d) => sum + d.quantity);
    final totalPrice = dtos.fold<double>(
      0,
      (sum, d) => sum + (d.price ?? 0) * d.quantity,
    );
    return CartSummaryEntity(
      totalItems: totalItems,
      totalQuantity: totalQuantity,
      totalPrice: totalPrice,
    );
  }

  @override
  Future<int> getCartItemCount() async {
    final dtos = await _localDataSource.getCartItems();
    return dtos.length;
  }

  @override
  Future<OrderResultEntity> submitOrderRequest({
    required RequestFormEntity form,
    required List<CartItemEntity> items,
  }) async {
    if (form.name.trim().isEmpty) {
      throw Exception('Name is required');
    }
    if (form.phone.trim().isEmpty) {
      throw Exception('Phone is required');
    }
    if (items.isEmpty) {
      throw Exception('Cart is empty');
    }

    final f = form.fulfillment;

    final legacyAddress = f.isPickup
        ? null
        : _nullIfEmpty(form.deliveryAddress);

    final customer = RequestSubmissionPayloadDto(
      name: form.name.trim(),
      phone: form.phone.trim(),
      email: _nullIfEmpty(form.email),
      promoCode: _nullIfEmpty(form.promoCode),
      loyaltyCard: _nullIfEmpty(form.loyaltyCard),
      comment: _nullIfEmpty(form.comment),
      consentGiven: form.consentGiven,
      userId: _supabaseClient.auth.currentUser?.id,
      deliveryMethod: f.legacyDeliveryMethod,
      deliveryAddress: legacyAddress,
      paymentMethod: form.payment.legacyPaymentMethod,
      fulfillmentType: f.fulfillmentType,
      fulfillmentMethodCode: f.methodCode,
      fulfillmentFee: f.fee,
      pickupStoreId: f.isPickup ? form.pickupStore?.id : null,
      deliveryZoneCode: f.isDelivery ? f.zoneCode : null,
      paymentMethodCode: form.payment.code,
    );

    final itemPayloads = items
        .map((i) => RequestItemPayloadDto(
              variantId: i.id,
              quantity: i.quantity,
            ))
        .toList();

    final result = await _remoteDataSource.submitOrderRequest(
      customer: customer,
      items: itemPayloads,
    );

    return OrderResultEntity(
      orderId: result['order_id'] as String,
      totalItems: (result['total_items'] as num).toInt(),
      totalQuantity: (result['total_quantity'] as num).toInt(),
      totalPrice: (result['total_price'] as num).toDouble(),
    );
  }

  String? _nullIfEmpty(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  CartItemEntity _toEntity(CartItemDto dto) {
    return CartItemEntity(
      id: dto.id,
      productId: dto.productId,
      title: dto.title,
      quantity: dto.quantity,
      brand: dto.brand,
      imageUrl: dto.imageUrl,
      price: dto.price,
      oldPrice: dto.oldPrice,
      edition: dto.edition,
      modification: dto.modification,
    );
  }

  CartItemDto _toDto(CartItemEntity entity) {
    return CartItemDto(
      id: entity.id,
      productId: entity.productId,
      title: entity.title,
      quantity: entity.quantity,
      brand: entity.brand,
      imageUrl: entity.imageUrl,
      price: entity.price,
      oldPrice: entity.oldPrice,
      edition: entity.edition,
      modification: entity.modification,
    );
  }
}
