/// Input values captured by the Info CTA block before submission.
///
/// Kept intentionally small: the server-side RPC owns all validation
/// and persistence. Additional workflow fields (e.g. channel, topic)
/// should be added only when the backend supports them.
class ConsultationFormEntity {
  final String name;
  final String phone;

  const ConsultationFormEntity({
    required this.name,
    required this.phone,
  });
}
