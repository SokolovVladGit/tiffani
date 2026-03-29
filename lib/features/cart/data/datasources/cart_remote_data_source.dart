import '../dto/request_item_payload_dto.dart';
import '../dto/request_submission_payload_dto.dart';

abstract interface class CartRemoteDataSource {
  Future<void> submitOrderRequest({
    required RequestSubmissionPayloadDto request,
    required List<RequestItemPayloadDto> items,
  });
}
