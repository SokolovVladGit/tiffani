/// Parsed response returned by `submit_consultation_v1`.
class ConsultationResultEntity {
  final String consultationId;
  final DateTime createdAt;
  final String status;

  const ConsultationResultEntity({
    required this.consultationId,
    required this.createdAt,
    required this.status,
  });
}
