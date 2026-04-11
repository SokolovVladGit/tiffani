import '../dto/request_item_payload_dto.dart';
import '../dto/request_submission_payload_dto.dart';

abstract interface class CartRemoteDataSource {
  /// Calls `submit_order_v2` RPC and returns the parsed response.
  /// After success, fires `order-notify` edge function (non-blocking).
  Future<Map<String, dynamic>> submitOrderRequest({
    required RequestSubmissionPayloadDto customer,
    required List<RequestItemPayloadDto> items,
  });
}
