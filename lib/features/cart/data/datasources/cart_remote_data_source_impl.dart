import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/logger_service.dart';
import '../dto/request_item_payload_dto.dart';
import '../dto/request_submission_payload_dto.dart';
import 'cart_remote_data_source.dart';

class CartRemoteDataSourceImpl implements CartRemoteDataSource {
  final SupabaseClient _client;
  final LoggerService _logger;

  const CartRemoteDataSourceImpl(this._client, this._logger);

  @override
  Future<void> submitOrderRequest({
    required RequestSubmissionPayloadDto request,
    required List<RequestItemPayloadDto> items,
  }) async {
    _logger.d('submitOrderRequest: ${items.length} items');
    if (items.isEmpty) {
      throw Exception('Cannot submit an empty order request');
    }
    try {
      await _submitViaRpc(request, items);
    } on PostgrestException catch (e) {
      _logger.w('RPC failed, using fallback: create_order_request_with_items — $e');
      await _submitViaFallback(request, items);
    }
  }

  Future<void> _submitViaRpc(
    RequestSubmissionPayloadDto request,
    List<RequestItemPayloadDto> items,
  ) async {
    final itemMaps = items.map((i) => {
      'variant_id': i.variantId,
      'product_id': i.productId,
      'title': i.title,
      'brand': i.brand,
      'image_url': i.imageUrl,
      'price': i.price,
      'quantity': i.quantity,
      'edition': i.edition,
      'modification': i.modification,
    }).toList();

    final response = await _client.rpc(
      'create_order_request_with_items',
      params: {
        'p_request': request.toMap(),
        'p_items': itemMaps,
      },
    );
    _logger.d('submitOrderRequest (RPC): created request $response');
  }

  Future<void> _submitViaFallback(
    RequestSubmissionPayloadDto request,
    List<RequestItemPayloadDto> items,
  ) async {
    try {
      final inserted = await _client
          .from('order_requests')
          .insert(request.toMap())
          .select('id')
          .single();
      final requestId = inserted['id'] as String;
      _logger.d('submitOrderRequest (fallback): created request $requestId');

      final itemRows = items
          .map((i) => RequestItemPayloadDto(
                requestId: requestId,
                variantId: i.variantId,
                productId: i.productId,
                title: i.title,
                brand: i.brand,
                imageUrl: i.imageUrl,
                price: i.price,
                quantity: i.quantity,
                edition: i.edition,
                modification: i.modification,
              ).toMap())
          .toList();

      await _client.from('order_request_items').insert(itemRows);
      _logger.d('submitOrderRequest (fallback): inserted ${itemRows.length} items');
    } catch (e) {
      _logger.e('submitOrderRequest fallback failed: $e');
      rethrow;
    }
  }
}
