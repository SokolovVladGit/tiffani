import 'package:equatable/equatable.dart';

import '../../domain/entities/admin_yml_import_result_entity.dart';

enum AdminYmlImportPhase {
  idle,
  dryRunLoading,
  dryRunReady,
  liveLoading,
  liveDone,
  error,
}

class AdminYmlImportState extends Equatable {
  const AdminYmlImportState({
    this.phase = AdminYmlImportPhase.idle,
    this.fileName,
    this.fileSizeBytes,
    this.ymlText,
    this.dryRunResult,
    this.liveResult,
    this.errorMessage,
  });

  final AdminYmlImportPhase phase;
  final String? fileName;
  final int? fileSizeBytes;
  final String? ymlText;
  final AdminYmlImportResultEntity? dryRunResult;
  final AdminYmlImportResultEntity? liveResult;
  final String? errorMessage;

  bool get isBusy =>
      phase == AdminYmlImportPhase.dryRunLoading ||
      phase == AdminYmlImportPhase.liveLoading;

  bool get canValidate =>
      !isBusy && ymlText != null && ymlText!.trim().isNotEmpty;

  bool get canApply =>
      phase == AdminYmlImportPhase.dryRunReady &&
      !isBusy &&
      dryRunResult != null &&
      (dryRunResult!.errorCount == 0);

  AdminYmlImportState copyWith({
    AdminYmlImportPhase? phase,
    String? fileName,
    int? fileSizeBytes,
    String? ymlText,
    AdminYmlImportResultEntity? dryRunResult,
    AdminYmlImportResultEntity? liveResult,
    String? errorMessage,
    bool clearFile = false,
    bool clearResults = false,
    bool clearError = false,
  }) {
    return AdminYmlImportState(
      phase: phase ?? this.phase,
      fileName: clearFile ? null : (fileName ?? this.fileName),
      fileSizeBytes: clearFile ? null : (fileSizeBytes ?? this.fileSizeBytes),
      ymlText: clearFile ? null : (ymlText ?? this.ymlText),
      dryRunResult: clearResults ? null : (dryRunResult ?? this.dryRunResult),
      liveResult: clearResults ? null : (liveResult ?? this.liveResult),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    phase,
    fileName,
    fileSizeBytes,
    ymlText,
    dryRunResult,
    liveResult,
    errorMessage,
  ];
}
