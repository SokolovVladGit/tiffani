import '../entities/consultation_form_entity.dart';
import '../entities/consultation_result_entity.dart';
import '../repositories/consultation_repository.dart';

class SubmitConsultationUseCase {
  final ConsultationRepository _repository;

  const SubmitConsultationUseCase(this._repository);

  Future<ConsultationResultEntity> call(ConsultationFormEntity form) =>
      _repository.submit(form);
}
