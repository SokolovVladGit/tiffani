import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/admin_yml_import_repository_impl.dart';
import '../../domain/constants/admin_yml_import_limits.dart';
import '../../domain/repositories/admin_yml_import_repository.dart';
import 'admin_yml_import_state.dart';

class AdminYmlImportCubit extends Cubit<AdminYmlImportState> {
  AdminYmlImportCubit(this._repository) : super(const AdminYmlImportState());

  final AdminYmlImportRepository _repository;

  void setPickedFile({
    required String fileName,
    required int fileSizeBytes,
    required String ymlText,
  }) {
    if (fileSizeBytes > AdminYmlImportLimits.maxUploadBytes) {
      emit(
        state.copyWith(
          phase: AdminYmlImportPhase.error,
          fileName: fileName,
          fileSizeBytes: fileSizeBytes,
          clearResults: true,
          errorMessage:
              'Файл слишком большой (${_formatBytes(fileSizeBytes)}). '
              'Лимит — ${_formatBytes(AdminYmlImportLimits.maxUploadBytes)}. '
              'Импорт через Storage может быть добавлен позже.',
        ),
      );
      return;
    }

    if (ymlText.trim().isEmpty) {
      emit(
        state.copyWith(
          phase: AdminYmlImportPhase.error,
          fileName: fileName,
          fileSizeBytes: fileSizeBytes,
          clearResults: true,
          errorMessage: 'Файл пустой',
        ),
      );
      return;
    }

    emit(
      AdminYmlImportState(
        fileName: fileName,
        fileSizeBytes: fileSizeBytes,
        ymlText: ymlText,
        phase: AdminYmlImportPhase.idle,
      ),
    );
  }

  void clearFile() {
    emit(const AdminYmlImportState());
  }

  Future<void> runDryRun() async {
    final text = state.ymlText;
    final name = state.fileName;
    if (text == null || text.trim().isEmpty) {
      emit(
        state.copyWith(
          phase: AdminYmlImportPhase.error,
          errorMessage: 'Сначала выберите файл',
        ),
      );
      return;
    }
    if (state.isBusy) return;

    emit(
      state.copyWith(
        phase: AdminYmlImportPhase.dryRunLoading,
        clearError: true,
        clearResults: true,
      ),
    );

    try {
      final result = await _repository.importYml(
        ymlText: text,
        dryRun: true,
        filename: name,
      );
      if (result.status == 'failed' || result.serverError != null) {
        emit(
          state.copyWith(
            phase: AdminYmlImportPhase.error,
            dryRunResult: result,
            errorMessage: result.serverError ?? 'Проверка не удалась',
          ),
        );
        return;
      }
      emit(
        state.copyWith(
          phase: AdminYmlImportPhase.dryRunReady,
          dryRunResult: result,
          clearError: true,
        ),
      );
    } on AdminYmlImportException catch (e) {
      emit(
        state.copyWith(
          phase: AdminYmlImportPhase.error,
          errorMessage: e.message,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          phase: AdminYmlImportPhase.error,
          errorMessage: 'Не удалось выполнить проверку',
        ),
      );
    }
  }

  Future<void> runLiveImport() async {
    final text = state.ymlText;
    final name = state.fileName;
    if (text == null || state.phase != AdminYmlImportPhase.dryRunReady) return;
    if (state.isBusy) return;

    emit(
      state.copyWith(
        phase: AdminYmlImportPhase.liveLoading,
        clearError: true,
      ),
    );

    try {
      final result = await _repository.importYml(
        ymlText: text,
        dryRun: false,
        filename: name,
      );
      if (result.status == 'failed' || result.serverError != null) {
        emit(
          state.copyWith(
            phase: AdminYmlImportPhase.error,
            liveResult: result,
            errorMessage: result.serverError ?? 'Импорт не удался',
          ),
        );
        return;
      }
      emit(
        state.copyWith(
          phase: AdminYmlImportPhase.liveDone,
          liveResult: result,
          clearError: true,
        ),
      );
    } on AdminYmlImportException catch (e) {
      emit(
        state.copyWith(
          phase: AdminYmlImportPhase.error,
          errorMessage: e.message,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          phase: AdminYmlImportPhase.error,
          errorMessage: 'Не удалось применить импорт',
        ),
      );
    }
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
