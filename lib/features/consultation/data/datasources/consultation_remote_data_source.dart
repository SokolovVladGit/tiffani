import '../dto/consultation_payload_dto.dart';

abstract interface class ConsultationRemoteDataSource {
  /// Calls `submit_consultation_v1` RPC and returns the parsed response map.
  /// After a successful response, fires `consultation-notify` edge function
  /// in a fire-and-forget manner (non-blocking, errors logged only).
  Future<Map<String, dynamic>> submit(ConsultationPayloadDto payload);
}
