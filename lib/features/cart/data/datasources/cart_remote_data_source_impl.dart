import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/logger_service.dart';
import '../../config/discount_pricing_config.dart';
import '../dto/request_item_payload_dto.dart';
import '../dto/request_submission_payload_dto.dart';
import 'cart_remote_data_source.dart';

class CartRemoteDataSourceImpl implements CartRemoteDataSource {
  final SupabaseClient _client;
  final LoggerService _logger;

  const CartRemoteDataSourceImpl(this._client, this._logger);

  @override
  Future<Map<String, dynamic>> quoteOrder({
    required RequestSubmissionPayloadDto customer,
    required List<RequestItemPayloadDto> items,
  }) async {
    _logger.d(
      'quoteOrder: ${items.length} items via ${DiscountPricingConfig.quoteOrderRpcName}',
    );

    final response = await _client.rpc(
      DiscountPricingConfig.quoteOrderRpcName,
      params: {
        'p_customer': customer.toMap(),
        'p_items': items.map((i) => i.toMap()).toList(),
      },
    );

    if (response is! Map) {
      throw FormatException(
        'quoteOrder returned non-map response: $response',
      );
    }
    return response.cast<String, dynamic>();
  }

  @override
  Future<Map<String, dynamic>> submitOrderRequest({
    required RequestSubmissionPayloadDto customer,
    required List<RequestItemPayloadDto> items,
  }) async {
    final rpc = DiscountPricingConfig.submitOrderRpcName;
    _logger.d('submitOrderRequest: ${items.length} items via $rpc');

    if (items.isEmpty) {
      throw Exception('Cannot submit an empty order request');
    }

    final response = await _client.rpc(
      rpc,
      params: {
        'p_customer': customer.toMap(),
        'p_items': items.map((i) => i.toMap()).toList(),
      },
    );

    if (response is! Map) {
      throw FormatException(
        '$rpc returned non-map response: $response',
      );
    }
    final result = response.cast<String, dynamic>();

    final orderId = result['order_id'] as String?;
    if (orderId != null) {
      _logger.d('submitOrderRequest: created order $orderId');
      _notifyOrder(orderId);
    } else {
      _logger.d('submitOrderRequest: no order_id (likely ok=false response)');
    }

    return result;
  }

  /// Fire-and-forget: sends Telegram notification via Edge Function.
  /// Failures are logged but never block the user flow.
  void _notifyOrder(String orderId) {
    _client.functions
        .invoke('order-notify', body: {'order_id': orderId})
        .then((_) => _logger.d('order-notify sent for $orderId'))
        .catchError((Object e) {
      _logger.w('order-notify failed (non-blocking): $e');
    });
  }
}
