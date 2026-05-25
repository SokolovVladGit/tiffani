import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/logger_service.dart';
import '../../domain/entities/admin_yml_import_result_entity.dart';
import '../../domain/repositories/admin_yml_import_repository.dart';

class AdminYmlImportException implements Exception {
  AdminYmlImportException(this.message);
  final String message;

  @override
  String toString() => message;
}

class AdminYmlImportRepositoryImpl implements AdminYmlImportRepository {
  final SupabaseClient _client;
  final LoggerService _logger;

  const AdminYmlImportRepositoryImpl(this._client, this._logger);

  @override
  Future<AdminYmlImportResultEntity> importYml({
    required String ymlText,
    required bool dryRun,
    String? filename,
  }) async {
    if (_client.auth.currentSession == null) {
      throw AdminYmlImportException('Требуется вход в аккаунт администратора');
    }

    try {
      final response = await _client.functions.invoke(
        'catalog-yml-import-manual',
        body: {
          'yml_text': ymlText,
          'dry_run': dryRun,
          'source': 'manual_admin_upload',
          if (filename != null && filename.isNotEmpty) 'filename': filename,
        },
      );

      final status = response.status;
      final data = response.data;

      if (data is Map<String, dynamic>) {
        if (status >= 400) {
          throw AdminYmlImportException(_errorMessageFromBody(data, status));
        }
        return AdminYmlImportResultEntity.fromJson(data);
      }

      if (status >= 400) {
        throw AdminYmlImportException(_statusMessage(status));
      }

      throw AdminYmlImportException('Неверный ответ сервера');
    } on AdminYmlImportException {
      rethrow;
    } on FunctionException catch (e) {
      _logger.w('catalog-yml-import-manual failed: $e');
      final details = e.details;
      if (details is Map<String, dynamic>) {
        throw AdminYmlImportException(
          _errorMessageFromBody(details, e.status),
        );
      }
      throw AdminYmlImportException(_statusMessage(e.status));
    } catch (e) {
      _logger.w('catalog-yml-import-manual error: $e');
      throw AdminYmlImportException('Сетевая ошибка. Проверьте подключение.');
    }
  }

  String _errorMessageFromBody(Map<String, dynamic> body, int status) {
    final err = body['error'];
    if (err is String && err.isNotEmpty) {
      if (status == 413) {
        final hint = body['hint'];
        if (hint is String && hint.isNotEmpty) {
          return '$err. $hint';
        }
        return '$err (лимит ${body['max_bytes'] ?? '—'} байт)';
      }
      if (status == 403) return 'Доступ запрещён. Нужны права администратора.';
      if (status == 401) return 'Сессия истекла. Войдите снова.';
      return err;
    }
    return _statusMessage(status);
  }

  String _statusMessage(int status) {
    switch (status) {
      case 401:
        return 'Сессия истекла. Войдите снова.';
      case 403:
        return 'Доступ запрещён. Нужны права администратора.';
      case 413:
        return 'Файл слишком большой для прямой загрузки. '
            'Попробуйте уменьшить экспорт или дождитесь импорта через Storage (v2).';
      case 400:
        return 'Некорректный файл или запрос.';
      case 502:
        return 'Не удалось разобрать YML. Проверьте, что это экспорт Tilda.';
      default:
        return 'Ошибка импорта (HTTP $status)';
    }
  }
}
