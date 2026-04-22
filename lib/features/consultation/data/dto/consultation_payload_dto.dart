/// Maps the consultation form to the `p_payload` argument of
/// `submit_consultation_v1`.
///
/// Only fields recognised by the server RPC are serialized.
class ConsultationPayloadDto {
  final String name;
  final String phone;
  final String source;

  const ConsultationPayloadDto({
    required this.name,
    required this.phone,
    this.source = 'mobile_app',
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'source': source,
    };
  }
}
