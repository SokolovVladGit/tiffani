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
      final inserted = await _client
          .from('order_requests')
          .insert(request.toMap())
          .select('id')
          .single();
      final requestId = inserted['id'] as String;
      _logger.d('submitOrderRequest: created request $requestId');

      final itemRows = items
          .map(
            (i) => RequestItemPayloadDto(
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
            ).toMap(),
          )
          .toList();

      await _client.from('order_request_items').insert(itemRows);
      _logger.d('submitOrderRequest: inserted ${itemRows.length} items');
    } catch (e) {
      _logger.e('submitOrderRequest failed: $e');
      rethrow;
    }
  }
}
