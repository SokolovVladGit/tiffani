import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/logger_service.dart';
import '../../domain/entities/consultation_form_entity.dart';
import '../../domain/usecases/submit_consultation_use_case.dart';
import 'consultation_state.dart';

class ConsultationCubit extends Cubit<ConsultationState> {
  final SubmitConsultationUseCase _submit;
  final LoggerService _logger;

  ConsultationCubit(this._submit, this._logger)
      : super(const ConsultationState());

  /// Submits the consultation request. Guarded against duplicate submissions
  /// while a previous call is in flight.
  Future<void> submit({
    required String name,
    required String phone,
  }) async {
    if (state.isSubmitting) return;

    emit(
      state.copyWith(
        status: ConsultationStatus.submitting,
        clearError: true,
      ),
    );

    try {
      final result = await _submit(
        ConsultationFormEntity(name: name, phone: phone),
      );
      emit(
        ConsultationState(
          status: ConsultationStatus.success,
          lastConsultationId: result.consultationId,
        ),
      );
    } catch (e) {
      // The data source layer already logs the full PostgREST diagnostic
      // (code / message / details / hint). Here we keep a single attribution
      // line so the failure is also visible at the cubit boundary without
      // duplicating the same multi-line dump.
      _logger.e('consultation submit failed: ${e.runtimeType} — $e');
      emit(
        ConsultationState(
          status: ConsultationStatus.failure,
          errorMessage: _humanize(e),
        ),
      );
    }
  }

  /// Returns the cubit to an idle state. Called after the UI has consumed
  /// a transient success/failure (e.g. after clearing the fields or
  /// dismissing a SnackBar).
  void reset() {
    emit(const ConsultationState());
  }

  String _humanize(Object error) {
    final raw = error.toString();
    const prefix = 'Exception: ';
    if (raw.startsWith(prefix)) return raw.substring(prefix.length);
    return raw;
  }
}
