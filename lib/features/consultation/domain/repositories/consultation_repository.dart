import '../entities/consultation_form_entity.dart';
import '../entities/consultation_result_entity.dart';

abstract interface class ConsultationRepository {
  /// Persists the consultation request via `submit_consultation_v1`
  /// and fires a fire-and-forget Telegram notification. Notification
  /// failures MUST NOT turn a persisted submission into an error.
  Future<ConsultationResultEntity> submit(ConsultationFormEntity form);
}
