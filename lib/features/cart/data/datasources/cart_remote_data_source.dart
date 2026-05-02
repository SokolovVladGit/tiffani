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

  /// Calls the configured submit RPC (`submit_order_v3` when the discount
  /// pricing flag is on, `submit_order_v2` otherwise) and returns the
  /// parsed RPC response. After success, fires the `order-notify` Edge
  /// Function (non-blocking).
  Future<Map<String, dynamic>> submitOrderRequest({
    required RequestSubmissionPayloadDto customer,
    required List<RequestItemPayloadDto> items,
  });
}
