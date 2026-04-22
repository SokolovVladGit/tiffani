import '../../domain/entities/consultation_form_entity.dart';
import '../../domain/entities/consultation_result_entity.dart';
import '../../domain/repositories/consultation_repository.dart';
import '../datasources/consultation_remote_data_source.dart';
import '../dto/consultation_payload_dto.dart';

class ConsultationRepositoryImpl implements ConsultationRepository {
  final ConsultationRemoteDataSource _remoteDataSource;

  const ConsultationRepositoryImpl(this._remoteDataSource);

  @override
  Future<ConsultationResultEntity> submit(
    ConsultationFormEntity form,
  ) async {
    // Single client-side source of truth for input shape is the Form
    // validator in the CTA widget. The server RPC is the authoritative
    // defense-in-depth layer. The repository intentionally does not
    // duplicate field validation here, because doing so creates fragile
    // overlapping error layers that the SnackBar / mapper cannot
    // reliably distinguish from real backend failures.
    final payload = ConsultationPayloadDto(
      name: form.name.trim(),
      phone: form.phone.trim(),
    );

    final result = await _remoteDataSource.submit(payload);

    final consultationId = result['consultation_id'] as String?;
    if (consultationId == null || consultationId.isEmpty) {
      throw Exception('submit_consultation_v1 did not return consultation_id');
    }

    return ConsultationResultEntity(
      consultationId: consultationId,
      createdAt: _parseCreatedAt(result['created_at']),
      status: (result['status'] as String?) ?? 'new',
    );
  }

  DateTime _parseCreatedAt(Object? raw) {
    if (raw is String && raw.isNotEmpty) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed;
    }
    return DateTime.now().toUtc();
  }
}
