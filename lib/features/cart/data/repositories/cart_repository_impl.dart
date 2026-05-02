import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/discount_pricing_config.dart';
import '../../domain/entities/cart_item_entity.dart';
import '../../domain/entities/cart_summary_entity.dart';
import '../../domain/entities/order_quote_entity.dart';
import '../../domain/entities/order_result_entity.dart';
import '../../domain/entities/request_form_entity.dart';
import '../../domain/exceptions/order_submission_exception.dart';
import '../../domain/repositories/cart_repository.dart';
import '../datasources/cart_local_data_source.dart';
import '../datasources/cart_remote_data_source.dart';
import '../dto/cart_item_dto.dart';
import '../dto/order_quote_dto.dart';
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
  Future<OrderQuoteEntity> quoteOrder({
    required RequestFormEntity form,
    required List<CartItemEntity> items,
  }) async {
    if (items.isEmpty) {
      return const OrderQuoteEntity(
        ok: false,
        errors: [
          OrderQuoteErrorEntity(
            code: 'empty_items',
            message: 'Корзина пуста',
          ),
        ],
      );
    }

    final customer = _buildCustomerPayload(form, requireFulfillmentValid: false);
    final itemPayloads = items
        .map((i) => RequestItemPayloadDto(variantId: i.id, quantity: i.quantity))
        .toList();

    final raw = await _remoteDataSource.quoteOrder(
      customer: customer,
      items: itemPayloads,
    );
    return OrderQuoteDto.parseQuote(raw);
  }

  @override
  Future<OrderResultEntity> submitOrderRequest({
    required RequestFormEntity form,
    required List<CartItemEntity> items,
  }) async {
    if (form.name.trim().isEmpty) {
      throw const OrderSubmissionException(
        code: 'missing_name',
        message: 'Укажите имя',
      );
    }
    if (form.phone.trim().isEmpty) {
      throw const OrderSubmissionException(
        code: 'missing_phone',
        message: 'Укажите телефон',
      );
    }
    if (items.isEmpty) {
      throw const OrderSubmissionException(
        code: 'empty_items',
        message: 'Корзина пуста',
      );
    }

    final customer = _buildCustomerPayload(form, requireFulfillmentValid: true);
    final itemPayloads = items
        .map((i) => RequestItemPayloadDto(variantId: i.id, quantity: i.quantity))
        .toList();

    final raw = await _remoteDataSource.submitOrderRequest(
      customer: customer,
      items: itemPayloads,
    );

    // submit_order_v3 returns ok=false on user-correctable failures; map to
    // an OrderSubmissionException with a Russian message. submit_order_v2
    // does not include `ok`, so missing key === assume v2 success.
    final okField = raw['ok'];
    if (okField is bool && !okField) {
      throw _mapErrorResponse(raw);
    }

    return OrderQuoteDto.parseOrderResult(raw);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  RequestSubmissionPayloadDto _buildCustomerPayload(
    RequestFormEntity form, {
    required bool requireFulfillmentValid,
  }) {
    final f = form.fulfillment;
    final legacyAddress =
        f.isPickup ? null : _nullIfEmpty(form.deliveryAddress);

    return RequestSubmissionPayloadDto(
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
  }

  OrderSubmissionException _mapErrorResponse(Map<String, dynamic> raw) {
    final errors = OrderQuoteDto.parseErrors(raw['errors']);
    if (errors.isEmpty) {
      return const OrderSubmissionException(
        code: 'unknown_error',
        message: 'Не удалось оформить заказ. Попробуйте ещё раз.',
      );
    }
    final first = errors.first;
    final mapped = OrderQuoteDto.localizeErrorCode(
      first.code,
      backendMessage: first.message,
    );
    final requote = first.code == 'quote_changed_or_discount_unavailable';
    String? campaignId;
    if (raw['errors'] is List && (raw['errors'] as List).isNotEmpty) {
      final firstRaw = (raw['errors'] as List).first;
      if (firstRaw is Map && firstRaw['campaign_id'] is String) {
        campaignId = firstRaw['campaign_id'] as String;
      }
    }
    // _; reserved for future use of pricing version in error metadata.
    final _ = DiscountPricingConfig.useDiscountPricingV1;
    return OrderSubmissionException(
      code: first.code,
      message: mapped,
      requiresRequote: requote,
      campaignId: campaignId,
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
