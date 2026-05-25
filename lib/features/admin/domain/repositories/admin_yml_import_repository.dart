import '../entities/admin_yml_import_result_entity.dart';

/// Admin-only manual Tilda YML import via Edge Function.
abstract interface class AdminYmlImportRepository {
  /// Invokes `catalog-yml-import-manual` with the authenticated session JWT.
  Future<AdminYmlImportResultEntity> importYml({
    required String ymlText,
    required bool dryRun,
    String? filename,
  });
}
