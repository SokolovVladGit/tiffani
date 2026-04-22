import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/logger_service.dart';
import '../dto/consultation_payload_dto.dart';
import 'consultation_remote_data_source.dart';

/// Thin wrapper around `submit_consultation_v1` + `consultation-notify`.
/// Mirrors the reliability model of [CartRemoteDataSourceImpl]:
///   * RPC is awaited and must succeed for the submission to succeed.
///   * Telegram notification is fire-and-forget; errors are logged only.
class ConsultationRemoteDataSourceImpl implements ConsultationRemoteDataSource {
  final SupabaseClient _client;
  final LoggerService _logger;

  const ConsultationRemoteDataSourceImpl(this._client, this._logger);

  @override
  Future<Map<String, dynamic>> submit(ConsultationPayloadDto payload) async {
    const rpcName = 'submit_consultation_v1';
    final paramsMap = <String, dynamic>{'p_payload': payload.toMap()};

    final Map<String, dynamic> result;
    try {
      final response = await _client.rpc(rpcName, params: paramsMap);

      if (response is Map<String, dynamic>) {
        result = response;
      } else if (response is Map) {
        // PostgREST occasionally surfaces JSONB results as Map<dynamic, dynamic>;
        // copy into the expected shape rather than failing on a generic-type
        // mismatch.
        result = Map<String, dynamic>.from(response);
      } else {
        throw StateError(
          '$rpcName returned unexpected payload shape: '
          'runtimeType=${response.runtimeType}',
        );
      }
    } on PostgrestException catch (e) {
      // Single line carries every PostgREST diagnostic field needed to
      // attribute the failure (code/message/details/hint). Payload is
      // intentionally not logged — it contains user PII (name, phone).
      _logger.e(
        'submitConsultation $rpcName failed: '
        'code=${e.code} message=${e.message} '
        'details=${e.details} hint=${e.hint}',
      );
      rethrow;
    } catch (e) {
      _logger.e(
        'submitConsultation $rpcName failed (non-Postgrest): '
        '${e.runtimeType} — $e',
      );
      rethrow;
    }

    final consultationId = result['consultation_id'] as String?;
    if (consultationId != null) {
      _notifyConsultation(consultationId);
    }

    return result;
  }

  /// Fire-and-forget: sends Telegram notification via Edge Function.
  /// Failures are logged but never block the user flow.
  void _notifyConsultation(String consultationId) {
    _client.functions
        .invoke(
          'consultation-notify',
          body: {'consultation_id': consultationId},
        )
        .then((_) => _logger.d(
              'consultation-notify sent for $consultationId',
            ))
        .catchError((Object e) {
      _logger.w('consultation-notify failed (non-blocking): $e');
    });
  }
}
