enum ConsultationStatus { idle, submitting, success, failure }

class ConsultationState {
  final ConsultationStatus status;
  final String? errorMessage;
  final String? lastConsultationId;

  const ConsultationState({
    this.status = ConsultationStatus.idle,
    this.errorMessage,
    this.lastConsultationId,
  });

  bool get isSubmitting => status == ConsultationStatus.submitting;
  bool get isSuccess => status == ConsultationStatus.success;
  bool get isFailure => status == ConsultationStatus.failure;

  ConsultationState copyWith({
    ConsultationStatus? status,
    String? errorMessage,
    String? lastConsultationId,
    bool clearError = false,
    bool clearLastId = false,
  }) {
    return ConsultationState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      lastConsultationId: clearLastId
          ? null
          : (lastConsultationId ?? this.lastConsultationId),
    );
  }
}
