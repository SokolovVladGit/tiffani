/// Parsed response from `catalog-yml-import-manual`.
class AdminYmlImportResultEntity {
  const AdminYmlImportResultEntity({
    this.runId,
    required this.mode,
    required this.status,
    required this.durationMs,
    required this.yml,
    required this.productsSeen,
    required this.productsUpserted,
    required this.variantsSeen,
    required this.variantsUpserted,
    required this.imagesSeen,
    required this.imagesUpserted,
    required this.errorCount,
    this.verdict,
    this.syncSeenAt,
    this.serverError,
  });

  final String? runId;
  final String mode;
  final String status;
  final int durationMs;
  final AdminYmlImportYmlMetrics yml;
  final int productsSeen;
  final int productsUpserted;
  final int variantsSeen;
  final int variantsUpserted;
  final int imagesSeen;
  final int imagesUpserted;
  final int errorCount;
  final String? verdict;
  final String? syncSeenAt;
  final String? serverError;

  factory AdminYmlImportResultEntity.fromJson(Map<String, dynamic> json) {
    final ymlRaw = json['yml'];
    return AdminYmlImportResultEntity(
      runId: json['run_id'] as String?,
      mode: json['mode'] as String? ?? 'unknown',
      status: json['status'] as String? ?? 'unknown',
      durationMs: _asInt(json['duration_ms']),
      yml: ymlRaw is Map<String, dynamic>
          ? AdminYmlImportYmlMetrics.fromJson(ymlRaw)
          : const AdminYmlImportYmlMetrics(),
      productsSeen: _asInt(json['products_seen']),
      productsUpserted: _asInt(json['products_upserted']),
      variantsSeen: _asInt(json['variants_seen']),
      variantsUpserted: _asInt(json['variants_upserted']),
      imagesSeen: _asInt(json['images_seen']),
      imagesUpserted: _asInt(json['images_upserted']),
      errorCount: _asInt(json['error_count']),
      verdict: json['verdict'] as String?,
      syncSeenAt: json['sync_seen_at'] as String?,
      serverError: json['error'] as String?,
    );
  }

  static int _asInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}

class AdminYmlImportYmlMetrics {
  const AdminYmlImportYmlMetrics({
    this.sizeBytes = 0,
    this.categoriesCount = 0,
    this.groupsCount = 0,
    this.offersCount = 0,
    this.offersWithPicture = 0,
    this.imagesInYml = 0,
  });

  final int sizeBytes;
  final int categoriesCount;
  final int groupsCount;
  final int offersCount;
  final int offersWithPicture;
  final int imagesInYml;

  factory AdminYmlImportYmlMetrics.fromJson(Map<String, dynamic> json) {
    return AdminYmlImportYmlMetrics(
      sizeBytes: AdminYmlImportResultEntity._asInt(json['size_bytes']),
      categoriesCount: AdminYmlImportResultEntity._asInt(
        json['categories_count'],
      ),
      groupsCount: AdminYmlImportResultEntity._asInt(json['groups_count']),
      offersCount: AdminYmlImportResultEntity._asInt(json['offers_count']),
      offersWithPicture: AdminYmlImportResultEntity._asInt(
        json['offers_with_picture'],
      ),
      imagesInYml: AdminYmlImportResultEntity._asInt(json['images_in_yml']),
    );
  }
}
