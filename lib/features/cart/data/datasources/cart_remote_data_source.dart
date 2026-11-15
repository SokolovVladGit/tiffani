import '../dto/request_item_payload_dto.dart';
import '../dto/request_submission_payload_dto.dart';

abstract interface class CartRemoteDataSource {
  /// Calls `quote_order_v1` with the same `p_customer` shape used at submit
  /// time, plus the cart items. Returns the raw RPC response (a map). The
  /// caller is responsible for parsing into a domain entity.
  Future<Map<String, dynamic>> quoteOrder({
    required RequestSubmissionPayloadDto customer,
    required List<RequestItemPayloadDto> items,
  });

  /// Calls `submit_order_v4` when [requestId] is present, otherwise the
  /// legacy `submit_order_v2` path. The database trigger queues notification.
  /// The client does not invoke `order-notify`.
  Future<Map<String, dynamic>> submitOrderRequest({
    required Map<String, dynamic> customer,
    required List<Map<String, dynamic>> items,
    String? requestId,
  });
}
