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
  Future<Map<String, dynamic>> submitOrderRequest({
    required RequestSubmissionPayloadDto customer,
    required List<RequestItemPayloadDto> items,
  }) async {
    _logger.d('submitOrderRequest: ${items.length} items');
    if (items.isEmpty) {
      throw Exception('Cannot submit an empty order request');
    }

    final response = await _client.rpc(
      'submit_order_v2',
      params: {
        'p_customer': customer.toMap(),
        'p_items': items.map((i) => i.toMap()).toList(),
      },
    );

    final result = response as Map<String, dynamic>;
    final orderId = result['order_id'] as String?;
    _logger.d('submitOrderRequest: created order $orderId');

    if (orderId != null) {
      _notifyOrder(orderId);
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
